# How to Check if Case Types Link.

For example, a case type for checking in at an emergency room, and another process for the hospital labs are related.

Requires the SQL Server sample, TimeSolution.

## Helpful Hints

- **EXEC dbo.sp_CasePropertyProfiling** View a list of case-level properties, metadata about them, and counts.
- If similar pairs are either being missed or incorrectly added, adjust the text of dbo.SourceColumns.[Description]. It might be too specific. We're looking for plausibly similar, not exactly the same thing.
