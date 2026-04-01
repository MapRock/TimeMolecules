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

If we have a huge database of events that include ER visits and MRI requests, and we didn't know anything about how the case types are related, we could try matching property values. 

### Find Plausibly Similar Event Property Names

We could match the property names, but it's more likely there will be a match on values than on the property names (VisitID vs. RequestorCaseID). However, we cannot completely disregard the property names. For example, "F" could be the stock ticker symbol for Ford Motor Co. and could be a code for "Female":

| Case Type| ID | Property | Value |
|----------|----------|----------|----------|
| Stock Quote | SQ-F | TickerSym | F |
| Patient Visit | ER111-2026 | PatientGender | F |

Those two cases are obviously not related. We know that because "TickerSym" and "PatientGender" are not semantically related. But "VisitID" and "RequestorCaseID" are plausibly semantically related.

1. [llm_prompt_similarity_score_event_properties.txt](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/link_cases/llm_prompt_similarity_score_event_properties.txt)
2. [source_column_semantic_similarity.py](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/link_cases/source_column_semantic_similarity.py): Produces the CSV file, [similar_column_pairs.csv](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/link_cases/similar_column_pairs.csv).
3. [import_similar_column_pairs_csv.sql](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/link_cases/import_similar_column_pairs_csv.sql): Imports the contents of similar_column_pairs.csv into the table, [TimeSolution].[dbo].[SimilarSourceColumnPairs].
4. [find_related_case_types.sql](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/link_cases/find_related_case_types.sql)
### Find Related Cases

## Helpful Hints

- **EXEC dbo.sp_CasePropertyProfiling** View a list of case-level properties, metadata about them, and counts.
- If similar pairs are either being missed or incorrectly added, adjust the text of dbo.SourceColumns.[Description]. It might be too specific. We're looking for plausibly similar, not exactly the same thing.
