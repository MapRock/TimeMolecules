
# Pre-Created Markov Models: The Time Molecules Counterpart to OLAP Aggregations

In OLAP, pre-aggregations existed to preserve compute: process once, read many times. They were not created because people enjoyed waiting for long processing jobs. They existed because query-time stalls were unacceptable and because some combinations of dimensions were hit often enough that it made sense to materialize them ahead of time. That same logic applies to Time Molecules. ([Soft Coded Logic][1])

This tutorial is about **pre-creating persisted Markov models** for combinations that are expected to be queried often or that would otherwise require expensive scans of `EventsFact` at query time. The idea is related to the dicing pattern shown in the `diced_markov_models` tutorial, but the purpose is different. The dicing tutorial is mainly about creating comparable analytical slices. This tutorial is about reducing query-time stalls and preserving compute for large or frequently requested models. ([GitHub][2])

## Why this is a separate topic from dicing

The existing diced models tutorial shows a very important Time Molecules pattern:

1. build a driving set of slices
2. vary one dimension deliberately
3. call `CreateUpdateMarkovProcess` once per slice
4. capture the resulting `ModelID` values for comparison later ([GitHub][2])

That is the right pattern when the goal is **comparison**.

This tutorial uses the same basic shape, but for a different reason:

* the models may be hit frequently
* the underlying event population may be large
* repeated ad hoc model creation can stall queries
* it is often better to create the models ahead of time and reuse them

That is why this deserves to be treated as a separate topic. It is not just dicing again. It is the Time Molecules version of **pre-aggregation**. ([Soft Coded Logic][1])

## The analogy to OLAP aggregation designs

In classic OLAP cubes, an aggregation design identified combinations of attributes worth materializing ahead of time. The point was not to precompute everything. The point was to precompute the combinations that would preserve the most compute and reduce the most pain at query time. Your OLAP pre-aggregation post makes that point directly: pre-aggregation is about doing the work before the user asks, instead of making the query pay the full cost each time. ([Soft Coded Logic][1])

In Time Molecules, the equivalent idea is a **model aggregation design**:

* instead of attribute combinations, we have combinations of `CreateUpdateMarkovProcess` parameters
* instead of storing sums and counts, we store persisted Markov models
* instead of solving repeated `GROUP BY` cost, we mitigate repeated scans and grouping over large portions of `EventsFact`

The analogy is not perfect, but it is close enough to be useful. In both cases, the main idea is the same:

**process once, read many times.** ([Soft Coded Logic][1])

## Why `CreateUpdateMarkovProcess` matters here

This topic is about persisted models, not just displayed models.

`MarkovProcess2` is useful for generating model output for display or temporary analysis. But for pre-created models, the important entry point is `CreateUpdateMarkovProcess`, because it persists the models and gives them identities that can be reused later. The dicing tutorial already uses `CreateUpdateMarkovProcess` in exactly that persisted-per-slice way. ([GitHub][2])

That is why this tutorial is built around `CreateUpdateMarkovProcess`, even though `MarkovProcess2` may still be part of the underlying implementation path.

## What a model aggregation design is

A **model aggregation design** is a stored specification of parameter combinations for `CreateUpdateMarkovProcess` that should be materialized in advance.

Instead of a single property value, the design can hold **arrays of values** for one or more parameters. The system reads the design, expands the intended combinations, and creates one model for each combination.

The design may contain:

* fixed parameters shared by all models
* arrays of values for dimensions you want to vary
* date windows
* transforms
* event sets
* case property filters
* event property filters
* metric settings
* flags such as `ByCase` or `enumerate_multiple_events`

Some arrays may contain only one value. That is fine. The point is to give the design a consistent structure so that combinations can be expanded systematically.

## What kinds of parameters belong in the design

A practical design can include parameters such as:

* `@EventSet`
* `@enumerate_multiple_events`
* `@StartDateTime`
* `@EndDateTime`
* `@transforms`
* `@ByCase`
* `@metric`
* `@CaseFilterProperties`
* `@EventFilterProperties`

The fixed values stay constant across the design. The array-valued parameters are the ones that produce multiple stored models.

For example:

* event set may be fixed at `cardiology`
* metric may be fixed at the default time-between-events metric
* transforms may be fixed or may vary across a small set
* date windows may vary by month
* case filter JSON may vary by location, department, or other property slices

That gives you a grid of models that are likely to be reused.

## Sample JSON design shape

Here is a simple example of what a model aggregation design could look like.

```json
{
  "DesignName": "Cardiology monthly by location",
  "Description": "Pre-create monthly cardiology models for two locations.",
  "FixedParameters": {
    "EventSet": "cardiology",
    "enumerate_multiple_events": 0,
    "transforms": null,
    "ByCase": 1,
    "metric": null
  },
  "VariableParameters": {
    "DateWindows": [
      { "StartDateTime": "2025-01-01", "EndDateTime": "2025-02-01" },
      { "StartDateTime": "2025-02-01", "EndDateTime": "2025-03-01" },
      { "StartDateTime": "2025-03-01", "EndDateTime": "2025-04-01" }
    ],
    "CaseFilterProperties": [
      null,
      "{\"LocationID\":1}",
      "{\"LocationID\":2}"
    ]
  }
}
```

That design would generate one model for every combination of:

* monthly date window
* case filter choice

So with 3 windows and 3 case-filter options, it would generate 9 stored models.

## How the combinations are expanded

The design should be thought of as a controlled Cartesian product.

For each parameter group that has multiple values, the system expands all intended combinations. Each combination becomes one call to `CreateUpdateMarkovProcess`.

For example:

* 3 date windows
* 2 transforms
* 4 case property filters

would produce:

**3 × 2 × 4 = 24 models**

This is the core idea. The design defines the coverage. The expansion produces the actual stored models.

## Why this helps performance

The worst part of ad hoc model creation is often not the small result set of model rows. The expensive part is reading and grouping the relevant event population from `EventsFact` to create the model in the first place.

That is exactly why this belongs in the same family of ideas as OLAP pre-aggregation.

If a model:

* covers a very large number of events
* is requested often
* or is part of a common comparison pattern

then persisting it ahead of time can prevent repeated expensive work. This reduces query-time stalls and improves concurrency in the same spirit that OLAP aggregations once did. Your OLAP post makes that exact point in the cube world: the benefit is not nostalgia, but mitigation of repeated query-time compute. ([Soft Coded Logic][1])

## When pre-created models are worth it

Pre-created models are especially useful when:

* the model covers a very large slice of event data
* the same model or similar models are queried frequently
* the model is part of a dashboard or repeated workflow
* users commonly compare the same recurring combinations
* query responsiveness matters more than fully ad hoc flexibility

They are less compelling when every request is truly novel and unlikely to be reused.

## A practical pattern

A practical pre-creation workflow looks like this:

1. identify models that are expensive or likely to be reused
2. define a model aggregation design with fixed and variable parameters
3. expand all intended combinations
4. call `CreateUpdateMarkovProcess` once per combination
5. capture the resulting `ModelID` values
6. reuse those persisted models in later analysis instead of rebuilding them on demand

That is the Time Molecules equivalent of deciding which aggregations are worth processing in advance.

## Relationship to the diced models tutorial

If you have not read the diced Markov models tutorial yet, read that first. It explains the slice-generation pattern clearly and shows how Time Molecules can create comparable process models by varying a dimension deliberately. This tutorial builds on that idea, but changes the motivation.

* **Diced models**: create comparable slices for analysis
* **Pre-created models**: materialize frequently useful slices ahead of time to preserve compute and reduce stalls ([GitHub][2])

The mechanics are related. The intent is different.

## Design considerations

A few practical considerations matter here.

### 1. Do not try to pre-create everything

Just as OLAP aggregation design was about choosing useful combinations rather than every possible combination, model aggregation design should be selective. Otherwise you can explode the number of stored models without getting much benefit. ([Soft Coded Logic][1])

### 2. Favor combinations that are both large and popular

The best candidates are often the ones that:

* scan a lot of event data
* are used repeatedly
* or serve as common starting points for downstream analysis

### 3. Capture the design that created the models

The design itself is useful metadata. It can explain:

* why the model was created
* what combinations were intended
* what parameters were fixed
* and what dimensions were expanded

That makes the pre-created model set more governable.

### 4. Think in BI-style recurring slices

Monthly windows, locations, departments, case types, transforms, and recurring property filters are natural candidates because they mirror the kinds of repeated dimensional combinations BI users already ask for.

## Closing thought

One of the easiest ways to underestimate Time Molecules is to think of Markov models only as things created ad hoc, one query at a time. That is not the whole picture. Time Molecules also shares something important with OLAP cubes: the idea that preserving compute ahead of time can make the analytical system much more practical. Pre-created Markov models are part of that story. They are the Time Molecules side of pre-aggregation. ([Soft Coded Logic][1])


[1]: https://eugeneasahara.com/2025/08/01/the-ghost-of-olap-aggregations-part-1/ "The Ghost of OLAP Aggregations – Part 1 – Pre-Aggregation – Soft Coded Logic"
[2]: https://github.com/MapRock/TimeMolecules/tree/main/tutorials/diced_markov_models "TimeMolecules/tutorials/diced_markov_models at main · MapRock/TimeMolecules · GitHub"
