
# TimeSolution Security

TimeSolution uses a layered security model.

The first layer is the database platform’s own security. Users still connect through SQL Server identities, and administrators, ETL services, and other privileged actors can be controlled through native database permissions.

The second layer is analytical security inside TimeSolution itself. This matters because Time Molecules is designed to integrate events, cases, properties, and models across many sources. Once those rows are brought together into one event ensemble, ordinary table-level permissions are often too coarse. A user may be allowed to use the system, but only see certain rows, certain properties, or certain models.

## Core idea

The system uses a bitmap-based authorization model for analytical access.

Each user has a row in `dbo.Users`, including an `AccessBitmap` column. That bitmap is the user’s effective set of granted access roles at query time.

The normalized bridge table `dbo.UserAccessRole` stores one row per user and access role. This makes grants easier to manage and audit, while `Users.AccessBitmap` acts as the fast representation used during read-time filtering.

The lookup table `dbo.Access` supplies the access-role identifiers, and each `AccessID` corresponds to a bit position in the bitmap. A row is visible when at least one bit in the user’s bitmap overlaps at least one bit in the row’s bitmap.

```sql
(UserAccessBitmap & RowAccessBitmap) <> 0
````

That does not mean all bits must match. It means at least one permitted bit overlaps.

## Why this exists

Traditional BI systems often secure schemas by database, table, or view. TimeSolution needs finer control because the event ensemble is intentionally broad.

A single event store may include processes from many sources. Event-level and case-level properties may contain sensitive attributes even when the events themselves are analytically useful. Markov models may be less sensitive than raw events, but drill-through can still expose underlying data.

So the design separates these concerns.

Native database security controls who can connect, who can run ETL, and who can administer the system.

TimeSolution bitmap security controls what analytical rows a user can actually see once they are in the system.

## Why some of this is intentionally denormalized

Some parts of the TimeSolution security design are intentionally shaped by read performance.

TimeSolution is expected to support very large analytical reads across the event ensemble, including drill-through from Markov models into underlying events and properties. In that setting, a perfectly normalized security model can become too expensive if every query must repeatedly join back to user-role tables, source metadata, or other security tables just to decide whether each row is visible.

That is why the design keeps both a normalized and a denormalized form of access control. `UserAccessRole` is easier to administer and audit, while `Users.AccessBitmap` is the fast query-time representation of a user’s effective access. Likewise, row-bearing structures such as staged events, parsed properties, and other event-ensemble objects may carry their own `AccessBitmap` so that visibility checks can often be performed directly on the row being read instead of through extra joins.

This is not just a convenience. It is a practical response to the fact that TimeSolution is meant for massive reads, broad analytical scans, and drill-through across a large integrated event store.

## The user side of the model

The current security model starts with `dbo.Users`.

A user row contains values such as:

* `UserID`
* `SUSER_NAME`
* `SQLLoginName`
* `AccessBitmap`
* `IsActive`

This allows TimeSolution to resolve the current SQL Server identity to an internal user row and then use that row’s bitmap for analytical filtering.

The companion table `dbo.UserAccessRole` stores the normalized grants:

* `UserID`
* `AccessID`
* `Granted`
* `CreateDate`
* `LastUpdate`

This arrangement gives the system two useful properties at once. It remains easy to manage individual user-to-role relationships in a conventional table, and it remains fast to evaluate access during analytic queries because the current user can be reduced to a single `BIGINT` bitmap.

## The row side of the model

The same general access idea is pushed into data-bearing tables.

At a minimum, the design allows access control to travel with the data as it becomes more specific:

* source-level defaults can establish a broad access boundary
* source-column-level bitmaps can tighten access for sensitive columns
* event and case property rows can carry their own bitmaps so filtering does not require repeated joins during every query
* staged imports can bring an access bitmap in with the imported event stream

This is why the access model is not just about users. It is also about pushing row-level sensitivity into the event ensemble itself.

## The staging boundary

Security in TimeSolution does not begin only at reporting time. It begins when staged events are admitted into the core event ensemble.

Stage imports can carry an `AccessBitmap`, and the import path can use the current user’s access bitmap and default access behavior during processing. This allows security to follow the data from the moment it enters the system rather than being added only later through reporting views.

## Securing property exposure

A good example of the design is a secured property view such as `vwCasePropertiesParsed`.

The view resolves the current user’s bitmap once and then filters property rows using the property row’s own `AccessBitmap`.

```sql
WITH ua AS (SELECT CAST(dbo.UserAccessBitmap() AS BIGINT) AS UserAccessBitmap)
...
WHERE (ua.UserAccessBitmap & ISNULL(cp.AccessBitmap, 0) <> 0)
```

The important point is that the visibility check is applied to the property row itself, not only to the broader source. That gives much finer control over sensitive properties.

In practice, the intended semantics should be chosen carefully. In many cases, a design may treat `NULL` or `0` as unrestricted, while in other cases they may mean deny-by-default. The important thing is that the system applies the same meaning consistently.

## What the overlap test means

If a user bitmap is:

```text
...00010100
```

and a row bitmap is:

```text
...00000100
```

then the bitwise `AND` is nonzero, so the row is visible.

If the row bitmap shares no bits with the user bitmap, the `AND` result is zero, and the row is hidden.

This makes the model naturally good for cases like:

* one user belonging to multiple roles
* one row being visible to multiple roles
* very fast read-time tests once the current user bitmap is known

It is not a hierarchical role model by itself. It is a compact overlap test.

## Why keep both `UserAccessRole` and `Users.AccessBitmap`

Because they do different jobs.

`UserAccessRole` is the normalized administrative structure. It is the easier place to insert, delete, audit, and reason about user-role assignments.

`Users.AccessBitmap` is the query-time cache.

This is a useful compromise in an analytical system. A normalized design is easier to maintain, but a materialized compact representation is faster to query repeatedly. TimeSolution keeps both.

## Query pattern

For convenience surfaces such as views, a common pattern is to compute the current user bitmap once and then apply a bitmap overlap filter.

For high-performance stored procedures, the better pattern is usually:

1. resolve the current user once
2. resolve the current user bitmap once
3. use inline predicates in the main query
4. avoid per-row scalar function calls where possible

That matters because TimeSolution is performance-sensitive. A clean abstraction is helpful, but in hot paths the optimizer usually prefers inline predicates over row-by-row scalar function execution.

## What this supports

This security model is not the main point of Time Molecules, but it supports the main point.

Time Molecules is about analyzing processes through events, cases, properties, and Markov models. The security model exists so that a wide, integrated event ensemble can still be queried safely, with drill-through and property analysis restricted to what each user is allowed to see.

That allows the system to remain broad and integrated without requiring every source or process to live in a separate silo.

## Summary

The TimeSolution security model is best understood as a layered approach:

* SQL Server identity establishes who the caller is
* `dbo.Users` and `dbo.UserAccessRole` determine what access roles the caller has
* `Users.AccessBitmap` gives a fast materialized representation of that access
* source, source-column, staged-event, and property rows can carry their own `AccessBitmap`
* views and procedures apply a bitmap overlap test to decide which rows are visible

This gives TimeSolution a security model that is much more granular than table-level permissions, while still being shaped for the large reads, broad scans, and drill-through queries that the event ensemble is expected to support.

