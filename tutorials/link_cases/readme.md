# How to Check if Case Types Link.

There are actually two subjects in this directory:

1. Analyzing how different processes (case types) might link. For example, a case type for checking in at an emergency room, and another process for the hospital labs are related.
2. Discover how cases might intersect. For example, if there is Person1 and Person2, each involved in one or more separate cases, do the cases of Person1 and Person2 ever intersect?

Requires the SQL Server sample, TimeSolution. See [Install Time Molecules](https://github.com/MapRock/TimeMolecules/blob/main/docs/install_timemolecules_dev_env.pdf)

## Helpful Hints

- **EXEC dbo.sp_CasePropertyProfiling** View a list of case-level properties, metadata about them, and counts.
- If similar pairs are either being missed or incorrectly added, adjust the text of dbo.SourceColumns.[Description]. It might be too specific. We're looking for plausibly similar, not exactly the same thing.
