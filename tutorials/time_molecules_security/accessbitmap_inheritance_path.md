
# AccessBitmap Inheritance Paths (Grant + Deny Model)

This supplement explains where the `AccessBitmap` values in TimeSolution come from and how they move through the system under the new **Grant + Deny** security model.

The main security tutorial (`readme.md`) explains the purpose of the two-bitmap design. This document is narrower — it is about **lineage**.

## Why this matters

TimeSolution is designed for very large reads across an integrated event ensemble. Access control is therefore carried directly on the rows being queried (instead of expensive joins back to security tables on every read).

Each protected row now carries an `AccessBitmap` column that represents the **required roles** for visibility.  
Each user has **two** bitmasks:

- `Users.AccessBitmap` → **GrantBitmap** (roles the user *has*)
- `Users.DenyBitmap` → **explicit Deny roles**

**Visibility rule applied everywhere:**

```sql
(dbo.UserAccessBitmap() & Row.AccessBitmap) <> 0      -- at least one required role is granted
AND
(dbo.UserDenyBitmap()   & Row.AccessBitmap) = 0       -- NO denied role overlaps any required role
```

## 1. User access: normalized roles → two materialized bitmaps

### Administrative form
`dbo.UserAccessRole` stores one row per user/role with a `Granted` flag (1 = grant, 0 = deny).

### Query-time form
`dbo.RefreshUserAccessBitmaps` flattens the roles into the two user columns.

Inheritance path:

```text
Access definitions (dbo.Access)
→ UserAccessRole (Granted column)
→ Users.AccessBitmap (GrantBitmap) + Users.DenyBitmap
→ dbo.UserAccessBitmap() + dbo.UserDenyBitmap()
→ read-time filters in views and procedures
```

## 2. Source-level default

`dbo.Sources.AccessBitmap` remains the broad default access boundary for everything associated with that source.

## 3. Source-column-level refinement

`dbo.SourceColumns.AccessBitmap` can be more restrictive than the source level.

## 4. Stage import → case-level access

```text
STAGE.ImportEvents.AccessBitmap
→ @CaseMap.AccessBitmap
→ Cases.AccessBitmap
```

## 5. Cases → EventsFact

```text
Cases.AccessBitmap
→ EventsFact.AccessBitmap
```

## 6. Cases → CasePropertiesParsed

```text
Cases.AccessBitmap
(plus optional SourceColumns.AccessBitmap)
→ CasePropertiesParsed.AccessBitmap
```

## 7. EventsFact → EventPropertiesParsed

```text
EventsFact.AccessBitmap
→ EventPropertiesParsed.AccessBitmap
```

## 8. Models: two different access concepts

- `Models.CreatedBy_AccessBitmap` — the access context under which the model was built (creation-time filter).
- `Models.AccessBitmap` — who is allowed to *see* the model object itself.

Default behavior: `Models.AccessBitmap` starts as `CreatedBy_AccessBitmap` but can be set independently.

## 9. Views and read surfaces

All secured views, TVFs, and procedures now use the two-condition rule shown above.

Example from `vwEventsFact`:

```sql
WHERE 
    (dbo.UserAccessBitmap() & e.AccessBitmap) <> 0
    AND (dbo.UserDenyBitmap() & e.AccessBitmap) = 0
```

## 10. Summary table (updated for Grant + Deny)

| Object / Layer                  | AccessBitmap source                              | Notes |
|--------------------------------|--------------------------------------------------|-------|
| `Users.AccessBitmap`           | materialized GrantBitmap from `UserAccessRole`   | Fast grant lookup |
| `Users.DenyBitmap`             | materialized DenyBitmap from `UserAccessRole`    | Explicit denies |
| `Sources.AccessBitmap`         | directly assigned                                | Broad default |
| `SourceColumns.AccessBitmap`   | typically defaults from Sources                  | Column-level tightening |
| `STAGE.ImportEvents.AccessBitmap` | supplied at ingest                            | Entry point for events |
| `Cases.AccessBitmap`           | inherited from staged events                     | Case-level security |
| `EventsFact.AccessBitmap`      | inherited from Cases                             | Core high-read table |
| `EventPropertiesParsed.AccessBitmap` | inherited from EventsFact                   | Property-level security |
| `Models.AccessBitmap`          | set at model creation                            | Model visibility |

