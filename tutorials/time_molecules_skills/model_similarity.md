
# How to compare similarity between two Markov models in TimeSolution

`ModelID` values are one of the most important keys in TimeSolution. Comparing two models is useful when you want to see how a process changes across time ranges, locations, employees, or any other case or event property slice. TimeSolution already includes `dbo.InsertModelSimilarities`, which compares two existing models using segment overlap, cosine similarity of transition probabilities, and a t-test-like measure on average transition times, then stores the result in `dbo.ModelSimilarity`. 

## What this skill does

This skill explains how to:

1. make sure the two models already exist
2. get the two `ModelID` values
3. compare them with `dbo.InsertModelSimilarities`
4. review the stored summary in `dbo.ModelSimilarity`
5. optionally use a new segment-by-segment comparison object to see exactly where the models differ

## Important prerequisite: the two models must already exist

`dbo.InsertModelSimilarities` does **not** create models. It expects two valid `ModelID` values, and its own metadata says each input model must already exist in `dbo.ModelEvents`. :contentReference[oaicite:1]{index=1}

That means the normal agent workflow is:

- find an existing model with `dbo.ModelID`
- or browse candidates with `dbo.ModelsByParameters`
- or create the model first with the normal model-building path
- then compare the resulting `ModelID` values

`dbo.ModelID` looks up an existing model by full definition: event set, date range, enumeration behavior, transforms, grouping, metric, filters, and model type. 

## Objects involved

### `dbo.ModelID`
Use this when you already know the model definition and want the exact `ModelID`. It returns the first matching `ModelID` or `NULL` if none exists. :contentReference[oaicite:3]{index=3}

### `dbo.ModelsByParameters`
Use this when you want candidate models that match an event set, date range, metric, or filter combination. `dbo.ModelEventsByProperty` uses it internally to retrieve matching models and then joins to `dbo.ModelEvents`, which makes it a good discovery object when the exact `ModelID` is not yet known. 

### `dbo.InsertModelSimilarities`
This is the working comparison procedure. It:

- loads the two models’ segments from `dbo.ModelEvents`
- counts shared and combined unique segments
- computes a Jaccard-like `PercentSameSegments`
- computes cosine similarity from matching segment probabilities
- computes an average t-test style value from matching segment averages and variances
- stores or updates the result in `dbo.ModelSimilarity`
- optionally displays segment-level comparison output when `@DisplaySegments = 1` 

### `dbo.ModelMatrix`
Use this if you want to inspect the transition matrix for a single model before or after comparison. It returns `EventA`, `EventB`, and `Prob` for a `ModelID`. :contentReference[oaicite:6]{index=6}

## Best comparison examples

The most useful comparisons are not random pairs of models. They are two models built from the same process but sliced differently.

### Example 1: compare two date ranges
This is useful for pre/post comparisons such as:

- before vs after a policy change
- this month vs last month
- Q1 vs Q2

The idea is to build or locate two models with the same event set and same other parameters, but different `StartDateTime` and `EndDateTime`.

### Example 2: compare two property slices
This is especially good for operational analysis.

Examples:

- `EmployeeID = 1` vs `EmployeeID = 2`
- `LocationID = 10` vs `LocationID = 12`
- `CustomerType = 'VIP'` vs `CustomerType = 'Standard'`

This lets you compare process shape rather than just raw counts.

## Step 1: find or create the first model

If the model may already exist, try `dbo.ModelID` first.

```sql
DECLARE @ModelID1 INT;

SELECT @ModelID1 = dbo.ModelID
(
    'restaurantguest',              -- @EventSet
    0,                              -- @enumerate_multiple_events
    '2026-01-01',                   -- @StartDateTime
    '2026-01-31',                   -- @EndDateTime
    NULL,                           -- @transforms
    1,                              -- @ByCase
    'Time Between',                 -- @Metric
    '{"EmployeeID":1}',             -- @CaseFilterProperties
    NULL,                           -- @EventFilterProperties
    'MarkovChain'                   -- @ModelType
);

SELECT @ModelID1 AS ModelID1;
````

`dbo.ModelID` accepts the event set, date range, transforms, grouping mode, metric, case filter properties, event filter properties, and model type.

If the result is `NULL`, the model does not already exist and should be created through your normal model-building path before you continue.

## Step 2: find or create the second model

For an employee comparison:

```sql
DECLARE @ModelID2 INT;

SELECT @ModelID2 = dbo.ModelID
(
    'restaurantguest',              -- @EventSet
    0,                              -- @enumerate_multiple_events
    '2026-01-01',                   -- @StartDateTime
    '2026-01-31',                   -- @EndDateTime
    NULL,                           -- @transforms
    1,                              -- @ByCase
    'Time Between',                 -- @Metric
    '{"EmployeeID":2}',             -- @CaseFilterProperties
    NULL,                           -- @EventFilterProperties
    'MarkovChain'                   -- @ModelType
);

SELECT @ModelID2 AS ModelID2;
```

For a date-range comparison, keep the same properties but change the date window.

## Step 3: compare the two models

Once both models exist, compare them with `dbo.InsertModelSimilarities`.

```sql
EXEC dbo.InsertModelSimilarities
     @ModelID1 = @ModelID1,
     @ModelID2 = @ModelID2,
     @DisplaySegments = 1;
```

The current implementation sorts the model IDs so the pair is stored in a consistent order, loads both sets of segments from `dbo.ModelEvents`, and raises an error if either model has no segments.

## Step 4: review the summary result

`dbo.InsertModelSimilarities` stores or updates the row in `dbo.ModelSimilarity` with these metrics:

* `CombinedUniqueSegments`
* `PercentSameSegments`
* `Model1Segments`
* `Model2Segments`
* `SameSegments_ttest`
* `CosineSimilarity`

Example:

```sql
SELECT *
FROM dbo.ModelSimilarity
WHERE ModelID1 = CASE WHEN @ModelID1 < @ModelID2 THEN @ModelID1 ELSE @ModelID2 END
  AND ModelID2 = CASE WHEN @ModelID1 < @ModelID2 THEN @ModelID2 ELSE @ModelID1 END;
```

## What the summary metrics mean

### `PercentSameSegments`

This is a Jaccard-like overlap score based on shared transition pairs relative to the combined unique transition set. Higher means the two models are built from more of the same segments.

### `CosineSimilarity`

This compares the transition probabilities of the shared segments. Two models can have the same segments but different probability distributions. Cosine similarity is meant to capture how close those probability vectors are.

### `SameSegments_ttest`

This is an average t-test-like value based on the segment averages, variances, and row counts for shared segments. It is meant to reflect how different the average transition metrics are where the same segment exists in both models. 

## When `@DisplaySegments = 1`

The current implementation already has a segment display mode. Its metadata explicitly says it can display segment-by-segment comparison details. 

That said, a dedicated segment comparison object is easier for agents and tutorials because it provides a stable rowset for downstream processing.

## Proposed new object: `dbo.ModelSimilaritySegments`

A good next addition is a table-valued function or stored procedure that returns one row per segment across both models, with flags showing whether the segment exists in both models or only one.

This answers the question:

**Where exactly are the two models different?**

Suggested output columns:

* `EventA`
* `EventB`
* `Model1Prob`
* `Model2Prob`
* `ProbDiff`
* `AbsProbDiff`
* `Model1Avg`
* `Model2Avg`
* `AvgDiff`
* `Model1Rows`
* `Model2Rows`
* `PresentInModel1`
* `PresentInModel2`
* `SegmentStatus`
* `Segment_ttest`

## Example use cases for `dbo.ModelSimilaritySegments`

### Compare January vs February

```sql
SELECT *
FROM dbo.ModelSimilaritySegments(101, 102)
ORDER BY AbsProbDiff DESC, EventA, EventB;
```

### Compare employee 1 vs employee 2

```sql
SELECT *
FROM dbo.ModelSimilaritySegments(@ModelID1, @ModelID2)
WHERE SegmentStatus <> 'SameSegment'
   OR AbsProbDiff >= 0.10
ORDER BY AbsProbDiff DESC, EventA, EventB;
```

That will highlight:

* segments unique to one employee
* shared segments whose probabilities differ materially
* shared segments whose average time differs

## Recommended agent workflow

1. Decide the slice definition you want to compare.
2. Find or create both models first.
3. Run `dbo.InsertModelSimilarities`.
4. Read the summary from `dbo.ModelSimilarity`.
5. Use `dbo.ModelSimilaritySegments` to identify the specific transitions that differ.

## Source material

This skill is based on the current TimeSolution SQL objects in the database script, especially:

* `dbo.InsertModelSimilarities`, which compares two existing models, loads segments from `dbo.ModelEvents`, and stores summary metrics in `dbo.ModelSimilarity`
* `dbo.ModelID`, which finds an existing model from a full parameter definition
* `dbo.ModelMatrix`, which returns the transition matrix for a single model 
* `dbo.ModelEventsByProperty`, which shows the current pattern of locating parameter-matched models and then joining to `dbo.ModelEvents`

