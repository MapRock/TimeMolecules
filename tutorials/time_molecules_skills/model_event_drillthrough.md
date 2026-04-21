
# How to use `sp_ModelDrillThrough` to inspect transition branches and underlying events in TimeSolution

This tutorial is based on the attached full `TimeSolution` database script  and on the existing Time Molecules skills pages in the repository, especially the structure used for the Markov-model comparison and adjacency-matrix tutorials. In the script, the legacy table-valued function `dbo.ModelDrillThrough` is explicitly marked deprecated in favor of the stored procedure `dbo.sp_ModelDrillThrough`, so AI agents should prefer the stored-procedure path for new workflows. ([GitHub][1])

`sp_ModelDrillThrough` is one of the most useful skills in TimeSolution because it bridges the gap between a stored Markov-model segment and the actual event instances that produced that segment. A model row such as `arrive -> greeted` in `dbo.ModelEvents` tells you that the transition exists and how often it occurs. `sp_ModelDrillThrough` tells you which underlying cases actually produced that transition, when the two events occurred, how many minutes elapsed between them, the event IDs of both sides, and the source-column metadata that can link the events back into a semantic layer or knowledge graph. That makes it the right tool when an agent needs to answer questions such as: “What really happened before guests were seated?”, “Did some guests go directly from arrival to table while others were greeted first?”, or “How does the same `EventA -> EventB` transition differ across two models built on different date ranges?” ([GitHub][1])

Discussed on Page 182 of [Time Molecules](https://technicspub.com/time-molecules/).
---

## What this procedure is for

Use `dbo.sp_ModelDrillThrough` when an AI agent needs to drill from a stored model down to the actual adjacent event pairs that generated a transition. In practice, that means it is useful for:

* branch discovery
* event-level validation of a model segment
* root-cause or path-shape investigation
* comparing the same transition across different models
* linking event transitions back to source metadata

A good mental model is this:

* `dbo.ModelEvents` tells you that a transition exists in aggregate.
* `dbo.sp_ModelDrillThrough` shows you the actual event-pair rows behind that aggregate.
* `dbo.sp_SelectedEvents` is the lower-level event-retrieval engine that `sp_ModelDrillThrough` uses internally. 

---

## Preferred object

For new agent workflows, prefer:

### `dbo.sp_ModelDrillThrough`

The older object:

### `dbo.ModelDrillThrough`

is the legacy TVF version and is deprecated in the script. That matches the newer TimeSolution pattern of preferring stored procedures over TVFs where portability and work-table pipelines matter.  ([GitHub][2])

---

## Prerequisites

Before calling `sp_ModelDrillThrough`, an AI agent should assume these prerequisites:

1. The `TimeSolution` database and its dependent objects were created from the script. 
2. The target model already exists in `dbo.Models`.
3. The target model has meaningful segment rows in `dbo.ModelEvents`.
4. The caller has access to the model under the row-level access bitmap logic.
5. The model’s referenced metadata is intact enough to resolve:

   * `EventSetKey -> EventSets`
   * `MetricID -> Metrics`
   * `transformskey -> Transforms` when present. 
6. The agent understands that this procedure is a drill-through over **adjacent events** in the selected event stream. It is not a full case replay and it is not a higher-order path enumerator by itself.

A practical prerequisite check is:

```sql
SELECT
    m.ModelID,
    m.ModelType,
    m.StartDateTime,
    m.EndDateTime,
    m.[Order],
    m.enumerate_multiple_events,
    m.CaseFilterProperties,
    m.EventFilterProperties,
    m.Description
FROM dbo.Models m
WHERE m.ModelID = @ModelID;

SELECT *
FROM dbo.ModelEvents
WHERE ModelID = @ModelID
ORDER BY EventA, EventB;
```

This confirms that the model exists and shows which `EventA -> EventB` segments are available to drill into. `dbo.ModelEvents` is the aggregate transition store for stored models, while `dbo.Models` holds the time range, event set, filters, order, and other model parameters that the drill-through reconstructs. 

---

## Procedure signature

```sql
EXEC dbo.sp_ModelDrillThrough
     @ModelID = ?,
     @EventA  = ?,
     @EventB  = ?;
```

### Parameters

* `@ModelID INT`
  Required. The stored model to drill into.

* `@EventA NVARCHAR(50) = NULL`
  Optional. If supplied, only rows whose left-side event matches `@EventA` are returned.

* `@EventB NVARCHAR(50) = NULL`
  Optional. If supplied, only rows whose right-side event matches `@EventB` are returned.

### Minimal call forms

Return all adjacent transition rows for a model:

```sql
EXEC dbo.sp_ModelDrillThrough
     @ModelID = 1;
```

Return only one segment:

```sql
EXEC dbo.sp_ModelDrillThrough
     @ModelID = 1,
     @EventA = N'arrive',
     @EventB = N'greeted';
```

The script includes sample usage in that pattern, including `EXEC dbo.sp_ModelDrillThrough @ModelID,'arrive','greeted';` and `EXEC dbo.sp_ModelDrillThrough 1`. 

---

## What the procedure actually does

`sp_ModelDrillThrough` rebuilds the event-selection context from the stored model, then rehydrates the underlying adjacent event pairs. In plain terms:

### 1. Reads the stored model metadata

It looks up the model in `dbo.Models` and resolves supporting metadata from `dbo.Metrics`, `dbo.Transforms`, and `dbo.EventSets`. From there it reconstructs the event-selection context, including:

* event set
* duplicate-event enumeration mode
* start and end datetime
* transforms
* metric
* case filter properties
* event filter properties. 

### 2. Calls `dbo.sp_SelectedEvents`

It generates a new `SessionID` and calls `dbo.sp_SelectedEvents` with the model’s own saved parameters. That procedure materializes the filtered event stream into `WORK.SelectedEvents` for the session. The script describes `sp_SelectedEvents` as the procedural materialization of selected events for work-table pipelines. 

### 3. Reconstructs adjacent transitions

It joins `WORK.SelectedEvents` to itself on:

* same `CaseID`
* `e1.[Rank] = e.[Rank] + 1`

That is the key point: `sp_ModelDrillThrough` returns **actual adjacent event pairs** in the filtered event stream, not just any two events that happen somewhere in the same case. 

### 4. Returns event-level details

For each matching adjacent pair it returns:

* `CaseID`
* `EventA`
* `EventB`
* `EventDate_A`
* `EventDate_B`
* `Minutes`
* `Rank`
* `EventOccurence`
* `EventA_ID`
* `EventB_ID`
* `EventA_SourceColumnID`
* `EventB_SourceColumnID` 

### 5. Cleans up the work rows

After returning the result, it deletes the session rows from `WORK.SelectedEvents`. 

---

## Output shape

The most important output columns are:

* `CaseID`
  The case in which the adjacent transition occurred.

* `EventA`, `EventB`
  The actual event names for the transition.

* `EventDate_A`, `EventDate_B`
  Timestamps for both sides of the handoff.

* `Minutes`
  Computed as the time difference in seconds divided by 60.0.

* `Rank`
  The rank of `EventB` within the case event stream.

* `EventOccurence`
  The occurrence count of `EventB` in that case.

* `EventA_ID`, `EventB_ID`
  The individual event-instance IDs.

* `EventA_SourceColumnID`, `EventB_SourceColumnID`
  Source-column lineage fields suitable for mapping into a semantic layer or knowledge graph. These come from `Cases.Event_SourceColumnID`, which in turn links to `dbo.SourceColumns`. `dbo.SourceColumns` stores column metadata including `SourceID`, `TableName`, `ColumnName`, `Description`, and `IRI`. 

That last point matters for AI agents: the drill-through is not just operational debugging. It is also a bridge back to metadata and semantics.

---

## Why this is a key skill for branch analysis

Suppose a restaurant model shows at least these aggregate segments in `dbo.ModelEvents`:

* `arrive -> greeted`
* `arrive -> seated`
* `greeted -> seated`

From the model alone, you know there are multiple paths, but not how the real cases split. `sp_ModelDrillThrough` lets you inspect the underlying rows and answer questions like:

* Which cases went directly from arrival to table?
* Which cases were greeted first?
* How long did each branch take?
* Are the direct-seat cases concentrated in a particular date range, source, or location?
* Do the two branches map back to different source columns or semantic entities?

That is the difference between aggregate transition knowledge and event-level explanation.

---

## Example A: inspect all transition rows for a model

Use this when the goal is: “Show me the actual adjacent transitions that support model 1.”

```sql
EXEC dbo.sp_ModelDrillThrough
     @ModelID = 1;
```

This is the broadest drill-through. It is often the best first step when the agent has identified an interesting model but does not yet know which segment to focus on.

---

## Example B: inspect one restaurant branch

Use this when the goal is: “Show me the real `arrive -> greeted` event rows.”

```sql
EXEC dbo.sp_ModelDrillThrough
     @ModelID = 1,
     @EventA = N'arrive',
     @EventB = N'greeted';
```

This returns the cases, timestamps, elapsed minutes, event IDs, and source-column IDs behind that segment. If the companion branch `arrive -> seated` also exists, run the paired drill-through:

```sql
EXEC dbo.sp_ModelDrillThrough
     @ModelID = 1,
     @EventA = N'arrive',
     @EventB = N'seated';
```

From there, an agent can compare:

* case counts
* timing differences
* source-column lineage
* downstream branch behavior after each handoff

---

## Example C: compare two alternative branches inside one model

A practical pattern is to capture both drill-throughs into temp tables, then compare them.

```sql
DROP TABLE IF EXISTS #arrive_greeted;
CREATE TABLE #arrive_greeted
(
    CaseID INT,
    EventA NVARCHAR(50),
    EventB NVARCHAR(50),
    EventDate_A DATETIME,
    EventDate_B DATETIME,
    Minutes FLOAT,
    [Rank] INT,
    EventOccurence INT,
    EventA_ID INT,
    EventB_ID INT,
    EventA_SourceColumnID INT,
    EventB_SourceColumnID INT
);

INSERT INTO #arrive_greeted
EXEC dbo.sp_ModelDrillThrough
     @ModelID = 1,
     @EventA = N'arrive',
     @EventB = N'greeted';

DROP TABLE IF EXISTS #arrive_seated;
CREATE TABLE #arrive_seated
(
    CaseID INT,
    EventA NVARCHAR(50),
    EventB NVARCHAR(50),
    EventDate_A DATETIME,
    EventDate_B DATETIME,
    Minutes FLOAT,
    [Rank] INT,
    EventOccurence INT,
    EventA_ID INT,
    EventB_ID INT,
    EventA_SourceColumnID INT,
    EventB_SourceColumnID INT
);

INSERT INTO #arrive_seated
EXEC dbo.sp_ModelDrillThrough
     @ModelID = 1,
     @EventA = N'arrive',
     @EventB = N'seated';

SELECT
    N'arrive->greeted' AS Branch,
    COUNT(*) AS TransitionRows,
    COUNT(DISTINCT CaseID) AS DistinctCases,
    AVG(Minutes) AS AvgMinutes,
    MIN(Minutes) AS MinMinutes,
    MAX(Minutes) AS MaxMinutes
FROM #arrive_greeted

UNION ALL

SELECT
    N'arrive->seated' AS Branch,
    COUNT(*) AS TransitionRows,
    COUNT(DISTINCT CaseID) AS DistinctCases,
    AVG(Minutes) AS AvgMinutes,
    MIN(Minutes) AS MinMinutes,
    MAX(Minutes) AS MaxMinutes
FROM #arrive_seated;
```

That gives an immediate branch comparison over actual event instances.

---

## Example D: compare the same segment across two different models

One of the strongest uses of `sp_ModelDrillThrough` is to compare the same transition across models built on different date ranges or filter contexts.

For example, suppose:

* `ModelID = 12` covers January
* `ModelID = 18` covers February

and both contain `arrive -> greeted`.

First, confirm the segment exists in both models:

```sql
SELECT
    ModelID,
    EventA,
    EventB,
    [Rows],
    Prob,
    Avg,
    StDev
FROM dbo.ModelEvents
WHERE ModelID IN (12, 18)
  AND EventA = N'arrive'
  AND EventB = N'greeted';
```

Then drill each one:

```sql
DROP TABLE IF EXISTS #m12;
CREATE TABLE #m12
(
    CaseID INT,
    EventA NVARCHAR(50),
    EventB NVARCHAR(50),
    EventDate_A DATETIME,
    EventDate_B DATETIME,
    Minutes FLOAT,
    [Rank] INT,
    EventOccurence INT,
    EventA_ID INT,
    EventB_ID INT,
    EventA_SourceColumnID INT,
    EventB_SourceColumnID INT
);

INSERT INTO #m12
EXEC dbo.sp_ModelDrillThrough
     @ModelID = 12,
     @EventA = N'arrive',
     @EventB = N'greeted';

DROP TABLE IF EXISTS #m18;
CREATE TABLE #m18
(
    CaseID INT,
    EventA NVARCHAR(50),
    EventB NVARCHAR(50),
    EventDate_A DATETIME,
    EventDate_B DATETIME,
    Minutes FLOAT,
    [Rank] INT,
    EventOccurence INT,
    EventA_ID INT,
    EventB_ID INT,
    EventA_SourceColumnID INT,
    EventB_SourceColumnID INT
);

INSERT INTO #m18
EXEC dbo.sp_ModelDrillThrough
     @ModelID = 18,
     @EventA = N'arrive',
     @EventB = N'greeted';

SELECT
    N'Model 12' AS ModelLabel,
    COUNT(*) AS TransitionRows,
    COUNT(DISTINCT CaseID) AS DistinctCases,
    AVG(Minutes) AS AvgMinutes,
    STDEV(Minutes) AS StDevMinutes
FROM #m12

UNION ALL

SELECT
    N'Model 18' AS ModelLabel,
    COUNT(*) AS TransitionRows,
    COUNT(DISTINCT CaseID) AS DistinctCases,
    AVG(Minutes) AS AvgMinutes,
    STDEV(Minutes) AS StDevMinutes
FROM #m18;
```

This is the direct event-level companion to model-level comparison. For structural similarity between stored models, the repository’s comparison tutorial uses `dbo.InsertModelSimilarities`, which writes overlap and similarity metrics into `dbo.ModelSimilarity`. `sp_ModelDrillThrough` answers the next question: what actual events were behind the shared or differing segments? ([GitHub][1])

---

## Example E: link the drill-through result to semantic metadata

Because `sp_ModelDrillThrough` returns `EventA_SourceColumnID` and `EventB_SourceColumnID`, an agent can immediately enrich the drill-through rows with source-column descriptions and IRIs.

```sql
DROP TABLE IF EXISTS #drill;
CREATE TABLE #drill
(
    CaseID INT,
    EventA NVARCHAR(50),
    EventB NVARCHAR(50),
    EventDate_A DATETIME,
    EventDate_B DATETIME,
    Minutes FLOAT,
    [Rank] INT,
    EventOccurence INT,
    EventA_ID INT,
    EventB_ID INT,
    EventA_SourceColumnID INT,
    EventB_SourceColumnID INT
);

INSERT INTO #drill
EXEC dbo.sp_ModelDrillThrough
     @ModelID = 1,
     @EventA = N'arrive',
     @EventB = N'greeted';

SELECT
    d.*,
    scA.SourceID AS EventA_SourceID,
    scA.TableName AS EventA_TableName,
    scA.ColumnName AS EventA_ColumnName,
    scA.Description AS EventA_ColumnDescription,
    scA.IRI AS EventA_ColumnIRI,
    scB.SourceID AS EventB_SourceID,
    scB.TableName AS EventB_TableName,
    scB.ColumnName AS EventB_ColumnName,
    scB.Description AS EventB_ColumnDescription,
    scB.IRI AS EventB_ColumnIRI
FROM #drill d
LEFT JOIN dbo.SourceColumns scA
    ON scA.SourceColumnID = d.EventA_SourceColumnID
LEFT JOIN dbo.SourceColumns scB
    ON scB.SourceColumnID = d.EventB_SourceColumnID;
```

This is especially useful when an agent needs to route from Time Molecules into a semantic layer, RDF/OWL mapping, or source-aware explanation pipeline. `dbo.SourceColumns` explicitly stores descriptive and IRI metadata for source columns. 

---

## Internal dependency chain

An AI agent should understand this dependency chain for troubleshooting and workflow design:

* `dbo.Models` stores the model parameters.
* `dbo.ModelEvents` stores the aggregate transition rows for the stored model.
* `dbo.sp_ModelDrillThrough` reads the model definition.
* `dbo.sp_SelectedEvents` materializes the filtered event stream into `WORK.SelectedEvents`.
* `WORK.SelectedEvents` holds the session-scoped event rows.
* `dbo.Cases` contributes `Event_SourceColumnID`.
* `dbo.SourceColumns` resolves source-column metadata. 

That means a failure or empty result can come from several places:

* model does not exist
* model exists but has filters that exclude everything
* access bitmap blocks rows
* chosen `EventA -> EventB` pair is not present in the filtered event stream
* transforms or event-set resolution changed the effective event names

---

## Practical decision rules for AI agents

Use `sp_ModelDrillThrough` when:

* you already have a stored `ModelID`
* you want the underlying event pairs behind one segment or all segments
* you need case IDs, event IDs, timestamps, or source-column lineage
* you want to compare the same segment across models

Use `dbo.ModelEvents` alone when:

* you only need aggregate probabilities, counts, or average timing

Use `dbo.InsertModelSimilarities` when:

* you want model-to-model similarity metrics stored in `dbo.ModelSimilarity`

Use `dbo.sp_SelectedEvents` directly when:

* you need the raw selected event stream rather than adjacent-pair drill-through. ([GitHub][1])

---

## Safety and behavior guidance for AI agents

A few constraints matter:

* Do not concatenate untrusted user text into dynamic SQL. The script repeatedly notes the code is teaching-oriented and not production-hardened. 
* Do not assume the returned rows represent non-adjacent sequence logic. This procedure is specifically joining rank `n` to rank `n+1`.
* Do not assume identical event names across models are semantically identical unless transforms and metadata are understood.
* Do not leave large intermediate results in shared work tables longer than needed. `sp_ModelDrillThrough` already cleans up its `WORK.SelectedEvents` session rows.
* Do not confuse source-column lineage with event-property lineage. `EventA_SourceColumnID` and `EventB_SourceColumnID` come from the case metadata path, not from arbitrary event-property columns.

---

## Minimal summary

For an AI agent, the simplest rule is:

* Need the actual event rows behind a stored model transition? Use `dbo.sp_ModelDrillThrough`.
* Need only aggregate segment metrics? Read `dbo.ModelEvents`.
* Need to compare models structurally? Use `dbo.InsertModelSimilarities`.
* Need to enrich the transition with semantic metadata? Join the drill-through output to `dbo.SourceColumns`.


[1]: https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/compare_two_markov_models.md "TimeMolecules/tutorials/time_molecules_skills/compare_two_markov_models.md at main · MapRock/TimeMolecules · GitHub"
[2]: https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/how_to_add_an_adjacency_matrix.md "TimeMolecules/tutorials/time_molecules_skills/how_to_add_an_adjacency_matrix.md at main · MapRock/TimeMolecules · GitHub"
