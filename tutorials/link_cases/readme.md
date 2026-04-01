# How to Check if Case Types Link.

There are actually two subjects in this directory:

1. Analyzing how different processes (case types) might link. For example, a case type for checking in at an emergency room, and another process for the hospital labs are related.
2. Discover how cases might intersect. For example, if there is Person1 and Person2, each involved in one or more separate cases, do the cases of Person1 and Person2 ever intersect?

Requires the SQL Server sample, TimeSolution. See [Install Time Molecules](https://github.com/MapRock/TimeMolecules/blob/main/docs/install_timemolecules_dev_env.pdf)

## Analyzing How Different Processes (case types) Might Link

The primary idea is that different case types could be related if the case types involve common property <i>values</i>. For example, a patient checks into an emergency room. A visit is started and an MRI is ordered at a facility separate from the ER. So the MRI facility opens its own case to manage, however, it references the ID of the requesting process.


| Case Type| ID | Property | Value |
|----------|----------|----------|----------|
| ER Checkin | ER111-2026 | VisitID | ER111-2026 |
| MRI | MRI123 | RequestorCaseID | ER111-2026 |

If we have a huge database of events that include ER visits and MRI requests, and we didn't know anything about how the case types are related, we could try matching property values. We could match the property names, but it's more likely there will be a match on values than on the property names (VisitID vs. RequestorCaseID).

### Find Plausibly Similary Event Property Name



## Helpful Hints

- **EXEC dbo.sp_CasePropertyProfiling** View a list of case-level properties, metadata about them, and counts.
- If similar pairs are either being missed or incorrectly added, adjust the text of dbo.SourceColumns.[Description]. It might be too specific. We're looking for plausibly similar, not exactly the same thing.
