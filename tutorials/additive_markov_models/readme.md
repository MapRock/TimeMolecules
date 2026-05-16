
# Partially Additive Markov Models

## Purpose

This tutorial explains an important idea in Time Molecules: Markov models are not fully additive in the same simple way that ordinary BI measures like `SalesAmount`, `Quantity`, or `OrderCount` are additive. However, parts of a Markov model can be additive under the right conditions.

This matters because partial additivity is one of the bridges between Time Molecules and conventional Business Intelligence. Traditional OLAP systems get much of their performance from additive measures. Time Molecules can use a related idea on the time side of BI: if two models are known not to overlap, and if their parameters are compatible, selected model statistics can be combined without rereading all of the underlying events.

This tutorial is conceptual. Code support for this pattern will be addressed in a future refresh.

---

## The BI analogy: why additivity matters

In conventional BI, additive measures are one of the main reasons pre-aggregated cubes work.

For example, if a table has billions of sales rows, a cube might pre-aggregate sales at the day level:

| Date | SalesAmount | OrderCount |
|---|---:|---:|
| 2026-05-01 | 1,200,000 | 40,000 |
| 2026-05-02 | 1,340,000 | 42,500 |
| 2026-05-03 | 1,180,000 | 38,750 |

Once those daily aggregates exist, the system does not need to rescan billions of transaction rows to calculate month, quarter, or year totals. It can add the daily aggregates.

That is the basic OLAP trick:

> Aggregate once at a useful lower level, then roll up by addition when the measure allows it.

Adding a few dozen or few hundred daily rows is much cheaper than recalculating from billions of source rows.

Time Molecules applies a similar idea to event sequences and Markov models.

---

## The time-side version of additivity

A Markov model segment represents a transition from one event to another:

```text
EventA -> EventB
````

For example:

```text
ordered -> served
```

A stored model segment may include statistics such as:

| Statistic | Meaning                                                          |
| --------- | ---------------------------------------------------------------- |
| `Rows`    | Number of observed transitions from `EventA` to `EventB`.        |
| `Prob`    | Probability of `EventB` following `EventA`.                      |
| `Avg`     | Average metric value for the segment, often time between events. |
| `Sum`     | Sum of the metric values for the segment.                        |
| `Min`     | Minimum metric value.                                            |
| `Max`     | Maximum metric value.                                            |
| `StDev`   | Standard deviation of the metric value.                          |
| `CoefVar` | Coefficient of variation.                                        |

Some of these values are naturally additive. Some are not. Some can be recomputed from additive components.

The key point is:

> A Markov model as a whole is not simply additive, but some of its segment statistics can be added or recomputed from additive components when the compared models are logically non-overlapping and parameter-compatible.

---

## The easiest additive case

The easiest case is when two models have the same logical definition except for non-overlapping date ranges.

For example:

| ModelID | EventSet          | CaseFilterProperties | EventFilterProperties | StartDateTime | EndDateTime |
| ------: | ----------------- | -------------------- | --------------------- | ------------- | ----------- |
|     101 | `restaurantguest` | `{"LocationID":1}`   | NULL                  | 2026-01-01    | 2026-01-31  |
|     102 | `restaurantguest` | `{"LocationID":1}`   | NULL                  | 2026-02-01    | 2026-02-28  |

These two models are compatible because they use the same event set and the same property filters.

They are also non-overlapping because January and February do not overlap.

If the same event transition exists in both models:

```text
ordered -> served
```

then selected statistics for that segment can be combined.

---

## Why non-overlap is the main issue

The main danger is double-counting.

If two stored models were built from overlapping event populations, adding their segment counts would count some transitions twice.

For example:

| ModelID | StartDateTime | EndDateTime |
| ------: | ------------- | ----------- |
|     201 | 2026-01-01    | 2026-01-31  |
|     202 | 2026-01-15    | 2026-02-15  |

These models overlap from January 15 through January 31. Adding their segment rows would not be safe because the same underlying events may be present in both models.

This is why the system must be able to determine non-overlap logically from model parameters.

The goal is not to retrieve all of the original events and compare them. That would defeat the purpose. If the source event table may contain millions or billions of rows, rereading it just to decide whether two models can be added is exactly what pre-aggregation is trying to avoid.

Instead, Time Molecules should determine additivity from model metadata:

| Metadata area       | Question                                                             |
| ------------------- | -------------------------------------------------------------------- |
| Event set           | Are the models based on the same event set or compatible event sets? |
| Date range          | Do the model date windows overlap?                                   |
| Case properties     | Are the case filters identical, compatible, or mutually exclusive?   |
| Event properties    | Are the event filters identical, compatible, or mutually exclusive?  |
| Transform settings  | Were the events transformed in the same way?                         |
| Metric              | Are the same metric definitions used?                                |
| Case handling       | Are both models by-case or both non-case models?                     |
| Enumeration setting | Do both models handle repeated events the same way?                  |

If the model parameters prove that the underlying event populations do not overlap, then selected values can be combined safely.

---

## What can be added?

Assume two compatible, non-overlapping models both contain this segment:

```text
ordered -> served
```

Model A:

| EventA  | EventB | Rows |   Sum |  Avg |
| ------- | ------ | ---: | ----: | ---: |
| ordered | served |  100 | 1,200 | 12.0 |

Model B:

| EventA  | EventB | Rows | Sum |  Avg |
| ------- | ------ | ---: | --: | ---: |
| ordered | served |   50 | 900 | 18.0 |

The combined segment can add `Rows` and `Sum`:

```text
CombinedRows = 100 + 50 = 150
CombinedSum  = 1200 + 900 = 2100
```

The combined average should not be calculated by simply averaging the two averages:

```text
Wrong:
(12.0 + 18.0) / 2 = 15.0
```

The correct combined average is weighted by rows:

```text
Correct:
CombinedAvg = CombinedSum / CombinedRows
CombinedAvg = 2100 / 150 = 14.0
```

So even when `Avg` itself is not additive, it can be recomputed from additive components.

---

## Additive, recomputable, and non-additive values

A useful way to think about model statistics is to group them into three categories.

| Statistic |                                           Additive? | Notes                                                                                  |
| --------- | --------------------------------------------------: | -------------------------------------------------------------------------------------- |
| `Rows`    |                                                 Yes | Segment counts can be added when the underlying event populations are non-overlapping. |
| `Sum`     |                                                 Yes | Metric sums can be added when the same metric is used.                                 |
| `Avg`     |                                        Recomputable | Do not add averages directly. Recompute from combined `Sum / Rows`.                    |
| `Prob`    |                                        Recomputable | Do not add probabilities directly. Recompute from combined transition counts.          |
| `Min`     |                                        Recomputable | Combined minimum is the minimum of the segment minimums.                               |
| `Max`     |                                        Recomputable | Combined maximum is the maximum of the segment maximums.                               |
| `StDev`   |          Recomputable with enough stored components | Requires more than just average and row count for an exact combined value.             |
| `CoefVar` |                                        Recomputable | Recompute from combined average and standard deviation.                                |
| `Skew`    | Recomputable only with sufficient stored components | Requires additional distribution information.                                          |

This is why the phrase “partially additive” is important.

The model is not additive in the simple OLAP sense, but enough of the model can be additive or recomputable that pre-created models can become building blocks for larger models.

---

## Probability is not directly additive

Probability is one of the easiest places to make a mistake.

Suppose one model has:

| EventA  | EventB | Rows | Prob |
| ------- | ------ | ---: | ---: |
| ordered | served |  100 | 0.80 |

Another has:

| EventA  | EventB | Rows | Prob |
| ------- | ------ | ---: | ---: |
| ordered | served |   50 | 0.50 |

The combined probability is not:

```text
0.80 + 0.50 = 1.30
```

It is also not necessarily:

```text
(0.80 + 0.50) / 2 = 0.65
```

The probability must be recomputed from the combined counts:

```text
P(EventB | EventA) =
combined rows for EventA -> EventB /
combined rows for all transitions from EventA
```

So `Prob` is not additive. But if the stored model has the right counts, it can be recomputed without going back to the raw events.

That is the important distinction.

---

## Case and event property compatibility

Date ranges are the easiest way to prove non-overlap, but they are not the only way.

Two models may use the same date range but still be non-overlapping because their case-level filters are mutually exclusive.

Example:

| ModelID | CaseFilterProperties |
| ------: | -------------------- |
|     301 | `{"LocationID":1}`   |
|     302 | `{"LocationID":2}`   |

If a case can only belong to one `LocationID`, then these two models are logically mutually exclusive by location.

That means the same case should not appear in both models.

Similarly:

| ModelID | CaseFilterProperties           |
| ------: | ------------------------------ |
|     401 | `{"CustomerType":"Retail"}`    |
|     402 | `{"CustomerType":"Wholesale"}` |

If `CustomerType` is a single-valued case property, then the two models may be safely additive across that dimension.

The same idea can apply to event properties, but event properties require more care because different events within the same case may have different event property values. Case properties are usually easier to reason about for non-overlap.

---

## Compatible parameters

Before two models can be considered additive, they must be compatible.

At minimum, they should usually match on:

| Parameter                       | Why it matters                                                               |
| ------------------------------- | ---------------------------------------------------------------------------- |
| `EventSet` / `EventSetKey`      | The models must be built from the same logical event vocabulary.             |
| `transforms` / `transformskey`  | Transformed event names must mean the same thing in both models.             |
| `ByCase`                        | A by-case model and a non-case model are not the same kind of sequence.      |
| `enumerate_multiple_events`     | Repeated events must be handled consistently.                                |
| `Metric`                        | Segment statistics must describe the same measurement.                       |
| `ModelType`                     | Different model types may not be structurally compatible.                    |
| `CaseFilterProperties`          | Filters must be identical, compatible, or provably mutually exclusive.       |
| `EventFilterProperties`         | Filters must be identical, compatible, or provably mutually exclusive.       |
| `StartDateTime` / `EndDateTime` | Date windows must not overlap unless another rule proves mutual exclusivity. |

This is why the model parameters are not just administrative metadata. They are part of the logical proof that determines whether stored models can be reused as additive components.

---

## Example: additive date slices

Suppose the system has already built monthly models:

| ModelID | EventSet          | LocationID | StartDateTime | EndDateTime |
| ------: | ----------------- | ---------: | ------------- | ----------- |
|     501 | `restaurantguest` |          1 | 2026-01-01    | 2026-01-31  |
|     502 | `restaurantguest` |          1 | 2026-02-01    | 2026-02-28  |
|     503 | `restaurantguest` |          1 | 2026-03-01    | 2026-03-31  |

A query asks for a first-quarter model for `LocationID = 1`.

Instead of scanning the underlying restaurant event table, the system could combine the three monthly models if it can prove that:

1. The models use the same event set.
2. The models use the same transforms.
3. The models use the same metric.
4. The models use the same case and event filters.
5. The date ranges do not overlap.
6. The date ranges fully cover the requested quarter.

Then the system can add segment rows and metric sums, and recompute averages and probabilities.

That is directly analogous to adding daily sales aggregates to get a monthly or quarterly sales total.

---

## Example: additive property slices

Suppose the system has already built models by location:

| ModelID | EventSet          | CaseFilterProperties |
| ------: | ----------------- | -------------------- |
|     601 | `restaurantguest` | `{"LocationID":1}`   |
|     602 | `restaurantguest` | `{"LocationID":2}`   |
|     603 | `restaurantguest` | `{"LocationID":3}`   |

A user asks for a model across all three locations.

If `LocationID` is a single-valued case property and the locations are mutually exclusive, the system can combine the models safely.

Again, the system should not have to inspect the raw events. It should be able to reason from the model parameters and the semantics of the property.

This is where property metadata becomes important. The system must know whether a property behaves like a mutually exclusive dimension, a multi-valued tag, a hierarchy member, or something else.

---

## Why this belongs to the time-side of BI

Traditional BI uses additive facts to avoid recalculating everything from base transactions.

Time Molecules can use partially additive Markov models to avoid recalculating everything from base events.

The analogy is:

| Traditional BI                    | Time Molecules                                                |
| --------------------------------- | ------------------------------------------------------------- |
| Transaction rows                  | Event rows                                                    |
| Additive measures                 | Additive segment counts and metric sums                       |
| Daily pre-aggregates              | Pre-created Markov models by date/property slices             |
| Roll up day to month/quarter/year | Combine compatible non-overlapping models                     |
| Recompute derived measures        | Recompute probabilities, averages, and other model statistics |
| Cube aggregation design           | Markov model aggregation design                               |

This is an important part of Time Molecules as the time-side of BI.

The goal is not merely to store Markov models. The goal is to make time-oriented models reusable, comparable, and composable.

---

## Why the system should avoid retrieving underlying events

The whole point of a stored model is to avoid unnecessary rescans of the event warehouse.

If the system has to retrieve every underlying event to determine whether two models can be combined, then the stored model has lost much of its value.

Instead, the system should answer questions like these from metadata:

```text
Are the date ranges non-overlapping?
Are the case filters mutually exclusive?
Are the event filters mutually exclusive?
Are the event sets the same?
Were the same transforms used?
Was the same metric used?
Were repeated events handled the same way?
```

If those questions can be answered logically, then stored models become reusable building blocks.

This is the Time Molecules version of the OLAP pre-aggregation strategy.

---

## Future implementation direction

Future code can support this pattern by adding logic that evaluates whether two or more models are safely combinable.

That logic could inspect model metadata such as:

| Metadata                       | Use                                                                                            |
| ------------------------------ | ---------------------------------------------------------------------------------------------- |
| `EventSetKey`                  | Confirms that the same event set definition was used.                                          |
| `transformskey`                | Confirms that the same event transforms were used.                                             |
| `StartDateTime`, `EndDateTime` | Determines whether model date windows overlap.                                                 |
| `CaseFilterProperties`         | Determines whether case-level filters are identical, compatible, or mutually exclusive.        |
| `EventFilterProperties`        | Determines whether event-level filters are identical, compatible, or mutually exclusive.       |
| `Metric`                       | Confirms that metric statistics are comparable.                                                |
| `ByCase`                       | Confirms compatible case-sequence behavior.                                                    |
| `enumerate_multiple_events`    | Confirms compatible repeated-event handling.                                                   |
| property metadata / MDM        | Helps determine whether properties are mutually exclusive, hierarchical, or rollup-compatible. |

The implementation should avoid retrieving raw event rows unless metadata is insufficient to prove additivity.

When safe, it can combine segment-level rows and sums, then recompute derived values.

---

## Summary

Markov models in Time Molecules are **partially additive**.

They are not additive in the same simple way as sales totals or row counts in a conventional cube. Probabilities, averages, standard deviations, and other derived values cannot simply be added.

However, when models are parameter-compatible and logically non-overlapping, important components of the model can be added:

```text
Rows can be added.
Metric sums can be added.
Averages can be recomputed.
Probabilities can be recomputed.
Minimums and maximums can be recomputed.
Other statistics may be recomputed if enough supporting components are stored.
```

This is a key idea for the time-side of BI.

Just as conventional BI avoids rescanning billions of fact rows by rolling up additive aggregates, Time Molecules can avoid rereading large event populations by combining compatible pre-created Markov models.

The crucial requirement is logical proof of non-overlap and compatibility from model parameters and property metadata, without going back to the raw events.
