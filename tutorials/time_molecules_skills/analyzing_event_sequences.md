
# Analyzing Sequences in TimeSolution

In TimeSolution, **sequences** are a middle ground between raw event logs and full Markov models. They still aggregate across many cases, but instead of focusing on the complete model of all transitions, they focus on **specific ordered event fragments** and what tends to happen after them. The core object for this is `dbo.Sequences`, with `dbo.sp_Sequences` as the stored-procedure counterpart. Both build on `dbo.SelectedEvents`, which filters and enriches the underlying event stream before sequence statistics are computed. :contentReference[oaicite:0]{index=0} :contentReference[oaicite:1]{index=1} :contentReference[oaicite:2]{index=2}

## What a sequence is

A sequence here is an ordered fragment such as:

- `arrive,greeted,seated`
- `admit,lab_ordered,resulted`
- `cart_add,checkout_start,payment`

The `dbo.Sequences` function takes such an event sequence, finds where it appears across cases, and returns statistics about:

- the sequence itself (`Seq`)
- the last event in the sequence (`lastEvent`)
- the next event that follows it (`nextEvent`)
- how often that next event follows (`Rows`)
- the total number of occurrences of the sequence (`TotalRows`)
- the conditional probability `Prob = Rows / TotalRows`
- timing statistics for the whole sequence and for the final hop
- how many distinct cases contain the sequence (`Cases`)
- whether the result came from cache (`FromCache`) :contentReference[oaicite:3]{index=3}

That means a sequence is not yet “the whole process.” It is a **prefix or fragment of process behavior** summarized across many cases.

## Why sequences are useful

Sequences are useful when you want to study process fragments without committing to the full complexity of a Markov model. They answer questions like:

- When this ordered fragment occurs, what usually happens next?
- How common is this fragment?
- How much time does this fragment usually take?
- Does the next step differ across filtered populations?
- Is this fragment a stable pathway or a noisy one?

This makes sequences especially good for exploring candidate pathways, validating event sets, and studying meaningful process fragments before or alongside full model creation. The metadata for `dbo.Sequences` explicitly describes it as returning sequence-level statistics, backed by `SelectedEvents`, `ModelID`, `SetDefaultModelParameters`, and `ModelSequences` for caching. :contentReference[oaicite:4]{index=4}

## Core objects involved

### `dbo.Sequences`

`dbo.Sequences` is a table-valued function that accepts:

- `@EventSet`
- `@enumerate_multiple_events`
- `@StartDateTime`
- `@EndDateTime`
- `@transforms`
- `@ByCase`
- `@Metric`
- `@CaseFilterProperties`
- `@EventFilterProperties`
- `@ForceRefresh`

and returns one row per discovered sequence/next-event combination, including probability and timing statistics. :contentReference[oaicite:5]{index=5}

### `dbo.sp_Sequences`

`dbo.sp_Sequences` is the stored-procedure version. Its metadata notes that for short results the TVF is often faster, while for very large fact sets the stored procedure may be faster. That makes it the better choice when the sequence exploration needs to run over a large amount of event data. :contentReference[oaicite:6]{index=6}

### `dbo.SelectedEvents`

`dbo.SelectedEvents` is the feeder object underneath sequence and Markov analysis. It filters and enriches `EventsFact` according to:

- event set
- date range
- transforms
- case-level filters
- event-level filters
- metric choice
- access bitmap security

and returns rows with `CaseID`, `Event`, `EventDate`, `Rank`, `EventOccurence`, `EventID`, and metric-related columns. That ranked, filtered stream is what sequence logic builds on. :contentReference[oaicite:7]{index=7}

### `dbo.ParseEventSet`

`dbo.ParseEventSet` helps interpret `@EventSet`. It can treat the input either as a literal comma-delimited set or as an `EventSetCode` looked up in `dbo.EventSets`. That means the sequence logic can work from either an explicit list like `arrive,greeted,seated` or a named event set such as `restaurantguest`. :contentReference[oaicite:8]{index=8}

## What sequence analysis is actually doing

Sequence analysis in TimeSolution works roughly like this:

1. Filter the raw events down to the relevant population using `SelectedEvents`.
2. Respect case boundaries if `@ByCase = 1`.
3. Look for the requested ordered fragment across those ranked event streams.
4. Aggregate the matching sequence occurrences across all relevant cases.
5. Measure what next event tends to follow that fragment.
6. Calculate timing and probability statistics for that fragment. :contentReference[oaicite:9]{index=9} :contentReference[oaicite:10]{index=10}

So if you ask for the sequence `arrive,greeted,seated`, the function is not merely checking whether those events exist. It is evaluating that ordered fragment across cases and summarizing what comes next and how stable that pathway is.

## Example queries

### 1. Analyze an explicit event fragment

```sql
SELECT *
FROM dbo.Sequences(
    'arrive,greeted,seated',
    1,
    '1900-01-01',
    '2050-12-31',
    NULL,
    1,
    NULL,
    NULL,
    NULL,
    0
);
````

This exact pattern appears in the metadata examples for `dbo.Sequences`. It asks: across the filtered cases, when the ordered fragment `arrive,greeted,seated` occurs, what next events tend to follow, and with what probabilities and timing? 

### 2. Analyze a named event set

```sql
SELECT *
FROM dbo.Sequences(
    'restaurantguest',
    1,
    '1900-01-01',
    '2050-12-31',
    NULL,
    1,
    NULL,
    NULL,
    NULL,
    0
);
```

This uses an event-set code rather than a literal list. `ParseEventSet` allows that code to resolve through `dbo.EventSets`.  

### 3. Use the stored procedure for larger workloads

```sql
EXEC dbo.sp_Sequences
    'arrive,greeted,seated',
    1,
    '1900-01-01',
    '2050-12-31',
    NULL,
    1,
    NULL,
    NULL,
    NULL,
    0;
```

This is useful when the underlying result set is large and you want the stored-procedure execution path instead of the TVF. 

### 4. Inspect the underlying filtered events

```sql
SELECT *
FROM dbo.SelectedEvents(
    'arrive,greeted,seated',
    1,
    NULL,
    NULL,
    NULL,
    1,
    NULL,
    NULL,
    NULL
)
ORDER BY CaseID, [Rank];
```

This is often the best debugging step. If the sequence results look odd, inspect the ranked event stream first. `SelectedEvents` shows the actual filtered sequence of events by case.

## How sequences differ from full Markov models

A full Markov model in TimeSolution, created through objects like `MarkovProcess2`, computes a broader model of transitions and segment statistics across an event population. It is designed to return a first- to third-order model, potentially cached and reused, with transition rows such as `EventA -> EventB` and associated statistics. `MarkovProcess2` explicitly populates its raw working set from `SelectedEvents`.

Sequences are narrower. They are about **a specific ordered fragment and what follows it**, rather than the full transition structure of the process. In practice:

* **Sequences** help explore a path fragment.
* **Markov models** help characterize the broader process.

That makes sequences useful for exploratory work, targeted hypothesis testing, and studying meaningful subpaths without yet building or interpreting the whole model.

## Good use cases for sequences

### Validating a pathway

You suspect that `arrive -> greeted -> seated` is a meaningful fragment in a restaurant process. Sequence analysis tells you whether that fragment really appears often enough to matter and what tends to happen after it.

### Comparing filtered populations

You can apply case and event filter properties in `SelectedEvents` and therefore in `Sequences`. That lets you ask whether the same fragment behaves differently under different conditions, such as location, customer type, fuel range, or other parsed properties. 

### Designing event sets

If you are trying to define a clean event set for modeling, sequences help reveal whether certain fragments behave coherently or whether they branch noisily.

### Studying timing

Because `dbo.Sequences` returns `SeqAvg`, `SeqStDev`, `HopAvg`, and related measures, it can show not just what usually happens next, but whether the pathway is fast, slow, or highly variable. 

## Interpreting the output columns

Some of the most important output columns are:

* `Seq`: the ordered fragment being analyzed
* `lastEvent`: the last event in that fragment
* `nextEvent`: the event that followed the fragment
* `TotalRows`: total number of times the fragment occurred
* `Rows`: number of times this specific `nextEvent` followed the fragment
* `Prob`: conditional probability that `nextEvent` follows the fragment
* `ExitRows`: how often the fragment ended without a next event
* `Cases`: distinct cases containing the fragment
* `SeqAvg`, `SeqStDev`, `SeqMin`, `SeqMax`: timing statistics for the full fragment
* `HopAvg`, `HopStDev`, `HopMin`, `HopMax`: timing statistics for the final hop
* `FromCache`: whether the result came from `dbo.ModelSequences`
* `length`: number of events in the fragment

These columns together let you judge not only whether a fragment is common, but whether it is stable, how it tends to continue, and whether it is analytically interesting.

## Practical workflow

A good workflow for sequence analysis is:

1. Decide on a candidate fragment or named event set.
2. Run `SelectedEvents` first to confirm the filtered event stream looks right.
3. Run `dbo.Sequences` for quick exploratory work.
4. Use `dbo.sp_Sequences` if the result set is large.
5. Look at `Prob`, `Cases`, and timing columns to decide whether the fragment is meaningful.
6. If the fragment proves important, move up to full Markov analysis with `MarkovProcess2`.

## Summary

In TimeSolution, sequences are aggregated process fragments built across many cases. They are not raw event logs, and they are not yet the full Markov model. Instead, they let you study ordered event fragments, what tends to follow them, how often they occur, and how long they usually take. The key objects are `dbo.Sequences`, `dbo.sp_Sequences`, `dbo.SelectedEvents`, and `dbo.ParseEventSet`, with optional caching through `dbo.ModelSequences`. This makes sequence analysis a useful bridge between basic event filtering and full process modeling.


