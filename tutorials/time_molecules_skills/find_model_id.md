# How to find a `ModelID` in TimeSolution

In TimeSolution, `ModelID` is one of the most important keys an agent can obtain. It is the identifier for a stored model definition and is the bridge to downstream objects such as `dbo.ModelMatrix`, `dbo.ModelEvents`, `dbo.InsertModelSimilarities`, Bayesian routines, drill-through logic, and model metadata. The existing tutorials in the repository follow a practical pattern: explain the object, list prerequisites, describe parameters carefully, and then show a concrete call. This tutorial follows that same pattern. ([GitHub][1])

## What an agent is trying to do

Usually an agent needs one of these outcomes:

* find the `ModelID` for an already-known model definition
* find candidate models that approximately match a definition
* find models that were sliced by certain case or event properties
* confirm whether a model already exists before trying to build or refresh it

For those tasks, the core objects are:

* `dbo.ModelID` — scalar lookup for one matching `ModelID`
* `dbo.ModelsByParameters` — broader parameter-based search returning candidate models
* `dbo.ModelsWithProperties` — property-oriented browsing of existing models

The script you provided shows `dbo.ModelID` as the scalar function that looks up an existing model by full definition, returning the first matching `ModelID` or `NULL` if none is found. 

## Prerequisites

Before trying to locate a model, an agent should assume:

1. The `TimeSolution` database and its core model objects were created from the database script. 
2. The model, if already stored, should have a row in `dbo.Models` and usually corresponding rows in `dbo.ModelEvents`. The later tutorials in the repo rely on stored models for comparison and adjacency-style exploration.  ([GitHub][1])
3. Access filtering matters. The script applies `(dbo.UserAccessBitmap() & m.AccessBitmap)=m.AccessBitmap`, so a model can exist and still not be visible to the current caller. 

## First choice: `dbo.ModelID`

`dbo.ModelID` is the best early task object when the agent already knows the intended model definition fairly well. The script metadata describes it as looking up a matching model from the full parameter set: event set, date range, enumeration behavior, transforms, grouping, metric, filters, and model type. 

### What `dbo.ModelID` is for

Use `dbo.ModelID` when the agent wants one answer:

* “Does this exact model already exist?”
* “What is the `ModelID` for this event set, date range, metric, and filter combination?”

If no match is found, it returns `NULL`. 

### Parameters of `dbo.ModelID`

From the script metadata and surrounding code, these are the important inputs.

| Parameter                    | Type                                       | Valid / typical values                                                                 | Meaning                                                                                                                                                                                                |
| ---------------------------- | ------------------------------------------ | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `@EventSet`                  | `NVARCHAR(MAX)`                            | event set name, CSV of events, or other event-set definition used in your environment  | Identifies the event universe for the model. The metadata describes it as an identifier or CSV defining the event set.                                                                                 |
| `@enumerate_multiple_events` | `BIT` in metadata, used as `INT` elsewhere | usually `0` or `1`                                                                     | `0` collapses repeated occurrences; `1` enumerates each occurrence. In newer code, some callers describe values `>0` as enumerating, but the common stored-model case is `0` or `1`.                   |
| `@StartDateTime`             | `DATETIME`                                 | `NULL` or a concrete lower bound                                                       | Lower bound of the model time range.                                                                                                                                                                   |
| `@EndDateTime`               | `DATETIME`                                 | `NULL` or a concrete upper bound                                                       | Upper bound of the model time range.                                                                                                                                                                   |
| `@transforms`                | `NVARCHAR(MAX)`                            | `NULL` or JSON transform definition                                                    | Event-name transform mapping. The insert logic hashes and stores this through `dbo.TransformsKey`.                                                                                                     |
| `@ByCase`                    | `BIT`                                      | usually `1` or `0`                                                                     | `1` means compute per case; `0` means treat all selected events as one sequence. The code defaults this to `1`.                                                                                        |
| `@metric`                    | `NVARCHAR(20)`                             | commonly `'Time Between'` or another metric defined in `dbo.Metrics`; sometimes `NULL` | Metric used for inter-event measurement. Insert logic defaults it to `'Time Between'` when inserting models. `ModelEventsByProperty` notes that `NULL` can mean all metrics in some search contexts.   |
| `@CaseFilterProperties`      | `NVARCHAR(MAX)`                            | `NULL` or JSON like `{"EmployeeID":1,"CustomerID":2}`                                  | Case-level property slice. These are stored into `dbo.ModelProperties` with `CaseLevel=1`.                                                                                                             |
| `@EventFilterProperties`     | `NVARCHAR(MAX)`                            | `NULL` or JSON                                                                         | Event-level property slice. These are stored into `dbo.ModelProperties` with `CaseLevel=0`.                                                                                                            |
| `@ModelType`                 | `NVARCHAR(50)`                             | commonly `'MarkovChain'`; possibly other model categories in your environment          | Model category. Insert logic defaults it to `'MarkovChain'`.                                                                                                                                           |
| `@AccessBitmap`              | access-related input in newer call chains  | typically current user access bitmap                                                   | In newer stored-procedure paths, access is part of the model identity path and visibility filters. At query time, models are filtered by access bitmap.                                                |

### Practical notes for agents

The important thing is that `dbo.ModelID` is for an exact definition match, not a fuzzy search. If an agent only knows some of the model characteristics, it should search with `dbo.ModelsByParameters` first and then narrow down. That is also visible in the insert flow: `InsertModel` uses `ModelsByParameters` to check whether a matching model already exists before inserting. 

## Second choice: `dbo.ModelsByParameters`

If `dbo.ModelID` is the exact lookup, `dbo.ModelsByParameters` is the candidate finder. It is used throughout the script to retrieve models matching parameter patterns. The metadata describes it as selecting Markov models whose parameters match event set, time window, transforms, grouping, metric, filter properties, and model type, returning their keys and metadata. 

### What `dbo.ModelsByParameters` is for

Use it when the agent wants:

* “Show me candidate models that match this definition.”
* “Find all models with this event set and these filters.”
* “Check whether there is already a stored model before creating one.”
* “Browse models across a metric or filter family.”

### Parameters of `dbo.ModelsByParameters`

The call sites and metadata show these inputs:

| Parameter                    | Type                           | Valid / typical values                       | Meaning                                                                                                                                                                     |
| ---------------------------- | ------------------------------ | -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `@EventSet`                  | `NVARCHAR(MAX)`                | event set name, CSV, or event-set definition | Matches the model’s event set.                                                                                                                                              |
| `@enumerate_multiple_events` | `INT` / logical bit flag       | usually `0` or `1`                           | Match collapse vs enumeration behavior.                                                                                                                                     |
| `@StartDateTime`             | `DATETIME`                     | `NULL` or lower bound                        | Match the model’s date window.                                                                                                                                              |
| `@EndDateTime`               | `DATETIME`                     | `NULL` or upper bound                        | Match the model’s date window.                                                                                                                                              |
| `@transforms`                | `NVARCHAR(MAX)`                | `NULL` or JSON transforms                    | Match transform definition.                                                                                                                                                 |
| `@ByCase`                    | `BIT`                          | `1` or `0`                                   | Match case-based or global sequence mode.                                                                                                                                   |
| `@Metric`                    | `NVARCHAR(20)`                 | metric name or `NULL`                        | Match metric; some callers use `NULL` to avoid restricting metric.                                                                                                          |
| `@CaseFilterProperties`      | `NVARCHAR(MAX)`                | `NULL` or JSON                               | Match case-level property slices.                                                                                                                                           |
| `@EventFilterProperties`     | `NVARCHAR(MAX)`                | `NULL` or JSON                               | Match event-level property slices.                                                                                                                                          |
| `@ModelType`                 | `NVARCHAR(50)`                 | often `'MarkovChain'`                        | Match model category.                                                                                                                                                       |
| `@ExactCasePropertiesMatch`  | `BIT` or nullable logical flag | `1`, `0`, or `NULL` depending on caller      | Controls strictness of case-property matching. Insert logic passes `1` to avoid creating duplicates with the same full slice. Search-style callers sometimes pass `NULL`.   |

### Important behavior

The script shows that `ModelsByParameters` checks:

* date range
* event set key
* enumerate flag
* transform key
* `ByCase`
* metric
* case properties in `dbo.ModelProperties`
* event properties in `dbo.ModelProperties`
* access permissions through `AccessBitmap`
* model type 

That makes it the most useful browse-and-confirm function before model creation.

## Third choice: `dbo.ModelsWithProperties`

Your prompt said “modelsbyproperties.” In the current script I found `dbo.ModelsWithProperties`, not `dbo.ModelsByProperties`. I would treat `ModelsWithProperties` as the current property-oriented browsing object unless you have a local alias or older object by the other name. The script explicitly says it differs from `ModelsByParameters` because it searches by case and event properties used for slicing. 

### What `dbo.ModelsWithProperties` is for

Use it when the agent wants:

* “What models were sliced by `EmployeeID`?”
* “Show me models that carry `CustomerID` and `LocationID` properties.”
* “Browse the property dimensions that existing models were built on.”

### Parameters of `dbo.ModelsWithProperties`

| Parameter             | Type            | Valid / typical values                                           | Meaning                                                                                                                                         |
| --------------------- | --------------- | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `@SelectedProperties` | `NVARCHAR(MAX)` | comma-separated property names such as `'EmployeeID,CustomerID'` | Returns models and up to five property slots for the named properties. If `NULL`, the function returns a placeholder row with `ModelID = -1`.   |

### Example

```sql
SELECT *
FROM dbo.ModelsWithProperties('EmployeeID,CustomerID');
```

That exact pattern appears in the script metadata. 

## JSON formats agents should use

Case and event filter properties are stored through `OPENJSON`, with numeric values going to `PropertyValueNumeric` and nonnumeric values going to `PropertyValueAlpha`. 

So an agent should prefer simple flat JSON objects such as:

```json
{"EmployeeID":1,"CustomerID":2}
```

or

```json
{"LocationID":17,"Shift":"Dinner"}
```

Keep the JSON flat unless your local code explicitly supports nested structures. The storage logic shown in the script is keyed around one-level property pairs. 

## Recommended lookup sequence for agents

### Strategy A: exact lookup first

Use this when the agent already knows the model definition.

```sql
DECLARE @ModelID INT;

SELECT @ModelID = dbo.ModelID
(
    'restaurantguest',      -- @EventSet
    0,                      -- @enumerate_multiple_events
    '1900-01-01',           -- @StartDateTime
    '2050-12-31',           -- @EndDateTime
    NULL,                   -- @transforms
    1,                      -- @ByCase
    'Time Between',         -- @metric
    '{"EmployeeID":1}',     -- @CaseFilterProperties
    NULL,                   -- @EventFilterProperties
    'MarkovChain',          -- @ModelType
    dbo.UserAccessBitmap()  -- access context, if your local signature includes it
);

SELECT @ModelID AS ModelID;
```

This example is conservative: it uses the same kinds of inputs shown elsewhere in the script and mirrors the shape used by the current model-creation path. The repository examples also show this general style of concrete, parameterized calls.   ([GitHub][1])

### Strategy B: browse candidates, then pick one

Use this when the agent is uncertain about exact filters or wants a list.

```sql
SELECT *
FROM dbo.ModelsByParameters
(
    'restaurantguest',                 -- @EventSet
    0,                                 -- @enumerate_multiple_events
    '1900-01-01',                      -- @StartDateTime
    '2050-12-31',                      -- @EndDateTime
    NULL,                              -- @transforms
    1,                                 -- @ByCase
    'Time Between',                    -- @Metric
    '{"EmployeeID":1,"CustomerID":2}', -- @CaseFilterProperties
    NULL,                              -- @EventFilterProperties
    'MarkovChain',                     -- @ModelType
    1                                  -- @ExactCasePropertiesMatch
);
```

Then the agent can select the returned `ModelID` and continue with downstream objects such as:

```sql
SELECT * FROM dbo.ModelMatrix(@ModelID);
```

`dbo.ModelMatrix` is explicitly documented in the script as returning `EventA`, `EventB`, and `Prob` for a given `ModelID`. 

### Strategy C: discover useful slices first

Use this when the agent is exploring what kinds of models exist.

```sql
SELECT *
FROM dbo.ModelsWithProperties('EmployeeID,CustomerID,LocationID');
```

That lets the agent see which model rows were stored with those slicing properties before trying exact lookup. 

## How this fits into the create-or-reuse flow

A useful agent pattern is:

1. Normalize candidate defaults for date range, order, enumerate flag, and metric.
2. Try `dbo.ModelID` for an exact match.
3. If `NULL`, try `dbo.ModelsByParameters` for near matches.
4. If the agent still needs a model, call the model-creation path such as `dbo.MarkovProcess2`.
5. Capture the resulting `@ModelID` output and use that for subsequent tasks.

The script for `dbo.MarkovProcess2` makes this explicit: if `@ModelID` is `NULL`, it computes or looks up a `ModelID` from the provided model definition before proceeding. 

## Common mistakes for agents

Do not treat `ModelID` as globally meaningful without its slice definition. A model is defined by its event set, date window, transforms, grouping, metric, and filters, not just by the integer key. 

Do not ignore `AccessBitmap`. An existing model can be hidden from the current caller. 

Do not assume `metric = NULL` means the same thing everywhere. In some search paths it broadens matching; in insertion paths the default is coerced to `'Time Between'`.  

Do not overuse fuzzy property discovery when you already know the full model definition. `dbo.ModelID` is cheaper and clearer for that case.

## Minimal actionable example

This is the simplest full path an agent can follow safely:

```sql
DECLARE @ModelID INT;

SELECT @ModelID = dbo.ModelID
(
    'restaurantguest',
    0,
    '1900-01-01',
    '2050-12-31',
    NULL,
    1,
    'Time Between',
    '{"EmployeeID":1,"CustomerID":2}',
    NULL,
    'MarkovChain',
    dbo.UserAccessBitmap()
);

IF @ModelID IS NULL
BEGIN
    SELECT *
    FROM dbo.ModelsByParameters
    (
        'restaurantguest',
        0,
        '1900-01-01',
        '2050-12-31',
        NULL,
        1,
        'Time Between',
        '{"EmployeeID":1,"CustomerID":2}',
        NULL,
        'MarkovChain',
        1
    );
END
ELSE
BEGIN
    SELECT @ModelID AS ModelID;
    SELECT * FROM dbo.ModelMatrix(@ModelID);
END
```

That gives the agent a practical branch:

* exact match found: proceed
* no exact match: inspect candidates

