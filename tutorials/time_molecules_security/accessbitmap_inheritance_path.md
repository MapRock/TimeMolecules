
# AccessBitmap Inheritance Paths

This supplement explains where the `AccessBitmap` values in TimeSolution come from and how they move through the system.

The main security tutorial explains the purpose of the bitmap model. This document is narrower. It is about lineage. When a row in TimeSolution has an `AccessBitmap`, where did that value come from?

## Why this matters

TimeSolution is designed for very large reads across an integrated event ensemble. Because of that, some access control is carried directly on the rows being queried instead of requiring repeated joins back to security tables on every read.

That means `AccessBitmap` is often both:

- a security value
- a cached inheritance of some earlier security decision

This document shows those inheritance paths.

## 1. User access: normalized grants and materialized bitmap

The user side of the model has two forms.

### Administrative form

`dbo.UserAccessRole` stores one row per user and access role. This is the normalized table that is easier to manage and audit.

### Query-time form

`dbo.Users.AccessBitmap` is the materialized bitmap used for fast filtering at read time.

So the user-side inheritance path is:

```text
Access definitions
→ UserAccessRole rows
→ Users.AccessBitmap
→ dbo.UserAccessBitmap()
→ read-time filters in views and procedures
````

This is the first important inheritance path in the system. It is not row-level data yet. It is the caller’s effective access context.

## 2. Source-level default

At the broadest data level, a source can have an `AccessBitmap`.

That makes `dbo.Sources.AccessBitmap` the default access boundary for everything associated with that source unless something more specific overrides it.

So the source-side path is:

```text
Sources.AccessBitmap
→ default for SourceColumns
→ may influence derived metadata and downstream row-level access
```

Conceptually, this is the starting point for source-based security.

## 3. Source-column-level refinement

`dbo.SourceColumns` is where access can become more specific than the whole source.

The intended idea is that a source can set a broad default, but an individual source column can be tighter. That matters because sensitive data often lives at the property/column level rather than at the entire source level.

So the intended path is:

```text
Sources.AccessBitmap
→ default for SourceColumns.AccessBitmap
→ inherited by property rows when appropriate
```

This is the first major refinement point.

One small nuance from the current codebase: at least one metadata-building path still appears to project source-column metadata using `s.AccessBitmap` from `dbo.Sources` rather than `sc.AccessBitmap` from `dbo.SourceColumns`. That does not necessarily mean the design is wrong, but it does mean some read surfaces may still be using the broader source-level value rather than the more specific source-column value. In other words, the conceptual inheritance path is clear, but not every supporting object is fully tightened yet.

## 4. Stage import: case-level access enters with the staged events

The main ingest point is `STAGE.ImportEvents`.

This is where access can first arrive with the incoming staged rows themselves.

In the import process, staged rows are grouped into cases in an internal `@CaseMap`, and the `AccessBitmap` for the case is taken from the staged rows. That case-level bitmap is then inserted into `dbo.Cases.AccessBitmap`.

So the beginning of the event-ensemble inheritance path is:

```text
STAGE.ImportEvents.AccessBitmap
→ @CaseMap.AccessBitmap
→ Cases.AccessBitmap
```

This is the main path you asked to start with.

The important point is that access is already present at case creation time, not added only later through reporting views.

## 5. Cases to EventsFact

After cases are created, events are inserted into `dbo.EventsFact`.

The intended inheritance path is:

```text
Cases.AccessBitmap
→ EventsFact.AccessBitmap
```

The import logic explicitly inserts an `AccessBitmap` into `EventsFact`, and the later property-parsing code assumes that `EventsFact` has already inherited its access from `Cases`.

So for the core event ensemble, the row-level inheritance path is:

```text
STAGE.ImportEvents.AccessBitmap
→ Cases.AccessBitmap
→ EventsFact.AccessBitmap
```

This is one of the most important cached security paths in the system, because `EventsFact` is one of the central high-read tables.

## 6. Cases to CasePropertiesParsed

Case properties are logically case-level information, so their access follows the case.

The intended path is:

```text
Cases.AccessBitmap
→ CasePropertiesParsed.AccessBitmap
```

In addition, because a case property may also be tied to a `SourceColumnID`, the more specific source-column access can also matter conceptually. So the practical interpretation is:

```text
SourceColumns.AccessBitmap
or Cases.AccessBitmap
→ CasePropertiesParsed.AccessBitmap
```

The main design idea is that the parsed case-property row should carry the access decision directly, so secured reads can filter on `cp.AccessBitmap` rather than repeatedly recomputing security from joins.

That is also why a secured view such as `vwCasePropertiesParsed` is most correct when it filters on `cp.AccessBitmap` rather than only on source-level access.

## 7. EventsFact to EventPropertiesParsed

Event properties are event-level information, so their access follows the event row.

The `InsertEventProperties` procedure inserts parsed event properties into `dbo.EventPropertiesParsed` and explicitly writes `e.AccessBitmap`, where `e` is the event row coming from `EventsFact`.

So the path here is very clear:

```text
Cases.AccessBitmap
→ EventsFact.AccessBitmap
→ EventPropertiesParsed.AccessBitmap
```

This is one of the clearest inheritance chains in the current code.

It also shows why TimeSolution carries access directly on parsed event-property rows. Query-time joins back to `Cases` or `EventsFact` are expensive when reads are large. By persisting the inherited bitmap onto the property row itself, the system can often apply security directly where the data is being read.

## 8. Models: two different access concepts

Models have two separate access-related columns that should not be confused.

### `Models.CreatedBy_AccessBitmap`

This represents the access context under which the model was created. It is not merely who owns the model. It is effectively a creation-time parameter because it controls what events were eligible when the model was built.

The path is:

```text
creator's effective access context
→ @CreatedBy_AccessBitmap
→ Models.CreatedBy_AccessBitmap
```

### `Models.AccessBitmap`

This controls who is allowed to see the model as an object.

The model-creation logic defaults `@AccessBitmap` to `@CreatedBy_AccessBitmap` unless something broader is explicitly supplied.

So the visibility path is:

```text
@CreatedBy_AccessBitmap
→ default for @AccessBitmap
→ Models.AccessBitmap
```

That means the default model visibility path is:

```text
creator's effective access
→ Models.CreatedBy_AccessBitmap
→ Models.AccessBitmap
```

But the design intentionally allows `Models.AccessBitmap` to be different if model visibility is meant to be broader or narrower than the creator’s context.

This is one of the more subtle parts of the security design.

## 9. Views and read surfaces

At read time, secured views and procedures compare the current user’s effective bitmap with the row’s bitmap.

For example, `vwCasePropertiesParsed` uses the current user bitmap and compares it to the property row’s `AccessBitmap`.

So the read-time path is:

```text
Users.AccessBitmap
→ dbo.UserAccessBitmap()
→ current user bitmap at runtime
→ overlap test with row AccessBitmap
→ row visible or not visible
```

This is not an inheritance path in the data-loading sense, but it is the last step in the lineage story. The user bitmap and the row bitmap finally meet in the read predicate.

## 10. Summary table

| Object or layer                      | AccessBitmap source                                                      | Notes                                         |
| ------------------------------------ | ------------------------------------------------------------------------ | --------------------------------------------- |
| `Users.AccessBitmap`                 | materialized from `UserAccessRole`                                       | Fast query-time representation of user grants |
| `Sources.AccessBitmap`               | directly assigned at source level                                        | Broad default access boundary                 |
| `SourceColumns.AccessBitmap`         | typically defaults from `Sources.AccessBitmap` unless made more specific | Refines access at column/property level       |
| `STAGE.ImportEvents.AccessBitmap`    | supplied with staged import rows                                         | Starting point for staged case/event lineage  |
| `Cases.AccessBitmap`                 | inherited from staged import case grouping                               | Main case-level security value                |
| `EventsFact.AccessBitmap`            | inherited from `Cases.AccessBitmap`                                      | Cached onto events for fast reads             |
| `CasePropertiesParsed.AccessBitmap`  | intended to follow case and/or source-column sensitivity                 | Cached onto parsed case-property rows         |
| `EventPropertiesParsed.AccessBitmap` | inherited from `EventsFact.AccessBitmap`                                 | Explicit in `InsertEventProperties`           |
| `Models.CreatedBy_AccessBitmap`      | creator’s effective access at model build time                           | Governs what source events could be included  |
| `Models.AccessBitmap`                | defaults from `CreatedBy_AccessBitmap` unless explicitly set             | Governs who may see the model                 |

## 11. Practical way to think about it

A useful way to remember the design is this:

```text
User grants
→ Users.AccessBitmap

Source defaults
→ SourceColumns

Staged case access
→ Cases
→ EventsFact
→ EventPropertiesParsed

Case sensitivity
→ CasePropertiesParsed

Model creation context
→ Models.CreatedBy_AccessBitmap
→ Models.AccessBitmap
```

So there are really three overlapping inheritance stories:

1. **user access inheritance** for the caller
2. **event-ensemble row inheritance** from stage to case to event to property
3. **model access inheritance** from creator context to model visibility

## 12. Final note

This document describes the intended inheritance path based on the current DDL and the objects already in place. In a few support objects, the broader source-level bitmap still appears where the more specific row-level bitmap would be more consistent. That is normal in a system still being tightened. The important thing is that the main inheritance direction is already visible:

* access enters with the staged rows or source defaults
* it is carried forward into the high-read analytical tables
* and it is finally compared with the current user’s materialized access bitmap at read time


