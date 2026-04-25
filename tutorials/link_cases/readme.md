# How to Check if Case Types Link.

There are actually two subjects in this directory:

1. Analyzing how different **processes** (case types) might link. For example, a case type for checking in at an emergency room, and another process for the hospital labs are related. Its possible that an ER and a lab or MRI facility are independent entities running different software systems. It we obtained events from those those entities, we may not know that the cases from each entity are actually related, part of the same process.
2. Discover how **cases** might intersect. For example, if there is Person1 and Person2, each involved in one or more separate cases, do the cases of Person1 and Person2 ever intersect?

Requires the SQL Server sample of the Time Molecules imprementation, TimeSolution. See [Install Time Molecules](https://github.com/MapRock/TimeMolecules/blob/main/docs/install_timemolecules_dev_env.pdf)

## Analyzing How Different Processes (case types) Might Link

The primary idea is that different case types could be related if the case types involve common property <i>values</i>. As mentioned above, a patient checks into an emergency room. A visit is started and an MRI is ordered at a facility separate from the ER. So the MRI facility opens its own case to manage, however, it references the ID of the requesting process.


| Case Type| ID | Property | Value |
|----------|----------|----------|----------|
| ER Checkin | ER111-2026 | VisitID | ER111-2026 |
| MRI | MRI123 | RequestorCaseID | ER111-2026 |

*Table 1. Case IDs from two different, but related, processes.*

If we have a huge database of events that include ER visits and MRI requests, along with events from perhaps thousands of different sources, and we didn't know anything about how the case types are related, we could try matching property values. 

### Ideal Situation

A strong best practice in event design is to pass forward enough business metadata when one process calls or triggers another so that someone downstream can later analyze how work moved across many different systems and process cycles. That means a called process should ideally carry the natural key of the calling process, or some other durable business identifier, as part of its metadata rather than treating each process in isolation. With that discipline in place, event data from a vast array of sources becomes much easier to connect analytically, because related cases can be linked through shared business identifiers instead of relying on fragile inference after the fact.

A familiar example is how a purchase order can remain associated with the invoice, shipment, receipt, or payment records that arise from related but distinct process cycles. Under that assumption, this code looks for cases whose natural key appears as a property value in other cases, then uses metadata about compatible source columns to identify which case types are most often linked in this way.

[find_related_case_types.sql](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/link_cases/find_related_case_types.sql) is based on the idea that well-designed event systems often preserve the natural key of the calling process when a related process is launched. In other words, when one process hands work to another, the downstream case is ideally tagged with metadata that carries the caller’s business key or a closely related identifier. That is a best practice when events are intended to support later analysis, because it makes cross-process relationships discoverable without requiring guesswork.

Table 2 shows how the MRI and Lab workflows are linked by the root ER case management passing along the patient's visit ID to those sub-processes.

| Primary Case Type | Total Cases |  Linked Case Type | Linked Count | Linked % of Primary Case Type | Overlap Count | Non-Overlap Count | Overlap % Within Linked Type |
|---:|---|---:|---:|---|---:|---:|---:|
| Emergency Room Case Management | 6 | Emergency Room Laboratory workflow | 5 | 83.3 | 6 | 0 | 1.2 |
| Emergency Room Case Management | 6 |  Emergency Room MRI / Radiology workflow | 4 | 66.7 | 4 | 1 | 1 |

*Table 2. Two case types related to Emergency Room Case Management.*

### Find Plausibly Similar Event Property Names

In the real world, countless processes relate in unexpected, unintended ways. To see how things relate, we need to match characteristics in abstracted, fuzzy ways.

We could match the property names, but it's more likely there will be a match on values than on the property names (VisitID vs. RequestorCaseID). However, we cannot completely disregard the property names. For example, "F" could be the stock ticker symbol for Ford Motor Co. and could be a code for "Female":

| Case Type| ID | Property | Value |
|----------|----------|----------|----------|
| Stock Quote | SQ-F | TickerSym | F |
| Patient Visit | ER111-2026 | PatientGender | F |

*Table 3. Two property values that are the same, but not semantically related.*

Those two cases of Table 2 are obviously not related. We know that because "TickerSym" and "PatientGender" are not in any way semantically related. But "VisitID" and "RequestorCaseID" of Table 1 are plausibly semantically related.

Setting up this mechanism involves these four items:

1. [llm_prompt_similarity_score_event_properties.txt](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/link_cases/llm_prompt_similarity_score_event_properties.txt): This is a prompt template used by python of #2.
2. [source_column_semantic_similarity.py](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/link_cases/source_column_semantic_similarity.py): Produces the CSV file, [similar_column_pairs.csv](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/link_cases/similar_column_pairs.csv).
3. [import_similar_column_pairs_csv.sql](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/link_cases/import_similar_column_pairs_csv.sql): Imports the contents of [similar_column_pairs.csv](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/link_cases/similar_column_pairs.csv) into the table, [TimeSolution].[dbo].[SimilarSourceColumnPairs].
4. [dbo].[sp_CompareEventProximities] stored procedure:

## Find Event Proximities

This example, utilizing the sp_CompareEventProximities stored procedure, find common event properties two sets of cases:

1. Cases where LocationID=1 AND EmployeeID=1.
2. Cases LocationID=1 AND EmployeeID=4.

```sql
EXEC [dbo].[sp_CompareEventProximities]
    @CaseFilterProperties1 = '{"LocationID":1,"EmployeeID":1}',
    @CaseFilterProperties2 = '{"LocationID":1,"EmployeeID":4}',
    @StartDateTime = NULL,
    @EndDateTime = NULL;
```

The results include two rows, one from each Case Set, that have the same GPS coordinate as a property ({"lat":-116.2023, "lon":43.6150}). This means the event took place at the exact same place, which implies either EmployeeID 1's home is walmart2.

| CaseSet | CaseID | EventID | Event      | PropertyName | EventDate                | PropertyValueAlpha              |
|--------:|-------:|--------:|------------|--------------|--------------------------|---------------------------------|
| 2       | 28     | 140     | walmart2   | point        | 2023-03-10 08:46:00.000  | {"lat":-116.2023, "lon":43.6150} |
| 1       | 11     | 86      | leavehome  | point        | 2022-10-01 07:20:00.000  | {"lat":-116.2023, "lon":43.6150} |

*Table 3. Two close GPS coordinates.*

Of course, GPS coordinates (or most other non-whole numbers) are usually not exact. In this case, a test for "distance" could be applied. But that's the subject of another story.

## Helpful Hints

- **EXEC dbo.sp_CasePropertyProfiling** View a list of case-level properties, metadata about them, and counts.
- If similar pairs are either being missed or incorrectly added, adjust the text of dbo.SourceColumns.[Description]. It might be too specific. We're looking for plausibly similar, not exactly the same thing.
- See [Linking Subprocesses with Case Properties](https://github.com/MapRock/TimeMolecules/blob/main/docs/subprocess_case_linking.md).
