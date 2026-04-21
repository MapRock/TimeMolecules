## How to compare similarity between two Markov models

In TimeSolution, the main object for comparing two stored Markov models is **`dbo.InsertModelSimilarities`**. It compares two models already stored in `dbo.ModelEvents`, calculates several similarity metrics, and writes the result into `dbo.ModelSimilarity` for later retrieval or recommendation workflows. Its own metadata describes it as computing **Jaccard-style overlap of segments, cosine similarity of transition probabilities, and a t-test over average transition times**, with optional segment-by-segment display. 

### What this procedure is for

Use `dbo.InsertModelSimilarities` when an agent needs to answer questions such as:

* How structurally similar are Model 12 and Model 18?
* Do two models share many of the same `EventA -> EventB` segments?
* Even if they share segments, are the **transition probabilities** similar?
* For shared segments, are the **average transition times** materially different?

The result is persisted in `dbo.ModelSimilarity`, which stores at least these fields:

* `ModelID1`
* `ModelID2`
* `CombinedUniqueSegments`
* `PercentSameSegments`
* `Model1Segments`
* `Model2Segments`
* `SameSegments_ttest`
* `CosineSimilarity`

---

## Prerequisites

Before calling the procedure, an AI agent should ensure:

1. **Both models already exist** and have rows in `dbo.ModelEvents`. The procedure reads the transition segments directly from `dbo.ModelEvents`.
2. The models are stored models, not just ad hoc result sets. In practice that usually means they were previously created through the model-creation flow and populated into `ModelEvents`.
3. The caller has permission to execute the procedure and write into `dbo.ModelSimilarity`.

If a model has no segments in `ModelEvents`, the procedure raises an error and returns. It explicitly checks for zero rows for both input model IDs.

---

## Stored procedure

### `dbo.InsertModelSimilarities`

### Parameters

The procedure accepts three parameters:

* `@ModelID1 INT`
  ID of the first model to compare. Must exist in `ModelEvents`. 

* `@ModelID2 INT`
  ID of the second model to compare. Must exist in `ModelEvents`. 

* `@DisplaySegments BIT = 1`
  If `1`, the procedure emits a segment-by-segment comparison result set showing only the shared segments between the two models.

### Sample call

```sql
EXEC dbo.InsertModelSimilarities
     @ModelID1 = 1,
     @ModelID2 = 8,
     @DisplaySegments = 1;
```

That sample call is included in the object metadata itself.

---

## What the procedure actually does

### 1. Normalizes model order

The procedure first **sorts the two model IDs**, swapping them if needed so the smaller ID is always `ModelID1` and the larger is always `ModelID2`. This matters because it makes the stored comparison canonical: comparing `(8,1)` and `(1,8)` lands on the same row key order.

This is important for agents because it makes the comparison effectively **order-insensitive** at the persistence level.

### 2. Loads model segments into temporary tables

It copies each model’s rows from `dbo.ModelEvents` into in-memory tables `@M1` and `@M2`, keeping:

* `EventA`
* `EventB`
* `Avg`
* variance derived from `POWER(StDev, 2)`
* `Rows`
* `Prob`

So the comparison is not just based on topology. It uses both structural and statistical information already stored for each segment.

### 3. Counts segments and overlap

The procedure unions the `EventA -> EventB` pairs from both models into a combined segment list, counts how many unique transition pairs exist across both models, and then computes **`PercentSameSegments`** as the proportion of combined unique segments that appear in both models. The code comment notes this is “similar to jaccard.”

### 4. Computes cosine similarity over probabilities

For segments that exist in both models, it computes:

* dot product of the matching `Prob` values
* magnitude of each model’s probability vector
* cosine similarity = dot product / (magnitude1 * magnitude2)

This tells you whether the two models distribute probability similarly across their shared transition edges.

### 5. Computes a t-test-like score for shared segments

If there is nonzero overlap, the procedure computes an average of per-segment values of:

[
(m1.Avg - m2.Avg) / \sqrt{(m1.Var / m1.Rows) + (m2.Var / m2.Rows)}
]

using only shared segments with nonzero variance on both sides. It stores the result in `SameSegments_ttest`. 

This gives a rough measure of how different the **average transition times** are for shared segments.

### 6. Upserts into `dbo.ModelSimilarity`

If a row for that model pair already exists, it updates it. Otherwise it inserts a new row. So this procedure is **idempotent with respect to storage of the pairwise similarity record**: rerunning it refreshes the metrics rather than creating duplicates.

---

## What gets returned

When `@DisplaySegments = 1`, the procedure emits a result set for the shared segments showing values such as:

* `m1_EventA`, `m2_EventA`
* `m1_EventB`, `m2_EventB`
* `m1_Avg`, `m2_Avg`
* `m1_Rows`, `m2_Rows`
* `m1_Prob`, `m2_Prob` 

This is useful for an agent that wants to explain *why* two models are similar or different instead of only storing the top-line score.

When `@DisplaySegments = 0`, the main effect is the update/insert into `dbo.ModelSimilarity`. The procedure itself does not advertise a separate scalar return value.

---

## How an AI agent should interpret the metrics

### `CombinedUniqueSegments`

Total number of distinct `EventA -> EventB` pairs across both models. Higher values usually mean the union of behaviors is broader. 

### `PercentSameSegments`

Share of combined unique segments that appear in both models. This is the most direct measure of structural overlap.

### `CosineSimilarity`

Similarity of the shared transition-probability profile. Two models may share the same segments but assign very different probabilities; cosine similarity distinguishes that. 

### `SameSegments_ttest`

A rough indicator of timing difference on shared segments. Large magnitude suggests the same transitions happen with different average durations. 

### `Model1Segments` and `Model2Segments`

Raw segment counts loaded from `ModelEvents` for each model. Helpful context when judging whether a comparison is between similarly sized models.

---

## Actionable example

A good agent workflow is:

### Step 1: compare two existing models

```sql
EXEC dbo.InsertModelSimilarities
     @ModelID1 = 101,
     @ModelID2 = 203,
     @DisplaySegments = 1;
```

### Step 2: read the stored similarity row

```sql
SELECT
    ModelID1,
    ModelID2,
    CombinedUniqueSegments,
    PercentSameSegments,
    Model1Segments,
    Model2Segments,
    SameSegments_ttest,
    CosineSimilarity
FROM dbo.ModelSimilarity
WHERE ModelID1 = CASE WHEN 101 < 203 THEN 101 ELSE 203 END
  AND ModelID2 = CASE WHEN 101 < 203 THEN 203 ELSE 101 END;
```

This second query works well because the procedure itself stores the pair in sorted order.

---

## Practical guidance for agents

An agent should follow these rules:

* **Do not assume input order matters.** The procedure normalizes the order of model IDs before storing. 
* **Do not compare models that have not been persisted into `ModelEvents`.** The procedure will error if one side has no segments.
* **Use `@DisplaySegments = 1`** when an explanation is needed. This surfaces the shared segments and their metrics. 
* **Use `@DisplaySegments = 0`** when the goal is just to refresh similarity records in bulk.
* **Treat the code as instructional, not production-hardened.** The metadata explicitly says error handling, security hardening, indexing, and scale concerns are simplified or omitted. 

---

## Minimal tutorial summary

To compare similarity between two Markov models in TimeSolution:

1. Make sure both model IDs exist in `dbo.ModelEvents`.
2. Execute `dbo.InsertModelSimilarities @ModelID1, @ModelID2, @DisplaySegments`. 
3. Let the procedure compute:

   * segment overlap,
   * cosine similarity on probabilities,
   * timing difference score,
   * and persist the result in `dbo.ModelSimilarity`.
4. Query `dbo.ModelSimilarity` later for reuse, ranking, grouping, or recommendations.


