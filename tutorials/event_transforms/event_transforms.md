
# How to use transforms in TimeSolution

Transforms in TimeSolution convert one event code into another event name before modeling. Their purpose is to regroup events into broader or alternate categories so the same underlying event stream can be studied at different semantic levels. In practice, a transforms definition is a JSON mapping from original event names to replacement event names, and TimeSolution stores these mappings in `dbo.Transforms`, parses them with `dbo.ParseTransforms`, and references them through a stable `TransformsKey` in downstream procedures. :contentReference[oaicite:0]{index=0} :contentReference[oaicite:1]{index=1}

## What this skill is for

This skill explains:

1. what transforms are
2. how they are stored
3. how TimeSolution procedures use them
4. how an AI agent should create and reuse them
5. how to apply them safely in model-building workflows

The intended audience is an AI agent that needs to query or update the TimeSolution database while preserving consistent process semantics.

## What a transform does

A transform maps one event name to another.

Examples:

- `heavytraffic` → `traffic`
- `moderatetraffic` → `traffic`
- `lighttraffic` → `traffic`

That lets the agent regroup multiple event codes into a broader category before building sequences, Markov models, or other process outputs. The metadata for `dbo.ParseTransforms` explicitly describes it as turning a transforms JSON object into a normalized rowset of source-event to target-event mappings for downstream modeling. :contentReference[oaicite:2]{index=2}

In other words, transforms do **not** change the underlying source event rows in `EventsFact`. They provide a remapping layer that lets modeling and analysis treat events differently.

## Core objects involved

### `dbo.Transforms`
This table stores distinct transforms payloads and their metadata. The key columns are:

- `TransformsKey` — binary key for the transforms set
- `Transforms` — the JSON mapping itself
- `Code` — short code or identifier
- `Description` — human explanation of the transform set :contentReference[oaicite:3]{index=3}

### `dbo.TransformsKey`
This scalar function computes the canonical binary key for a transforms JSON payload. It is referenced by both `dbo.InsertTransforms` and `dbo.UpdateTransform`. :contentReference[oaicite:4]{index=4} :contentReference[oaicite:5]{index=5}

### `dbo.InsertTransforms`
This procedure computes the canonical key for a transforms JSON payload and inserts it into `dbo.Transforms` if it is not already present. It returns the `TransformsKey` for downstream use. :contentReference[oaicite:6]{index=6}

### `dbo.UpdateTransform`
This procedure updates an existing transforms entry by computing its key, ensuring code uniqueness for that key, updating its code and description, and logging the update event. :contentReference[oaicite:7]{index=7}

### `dbo.ParseTransforms`
This table-valued function parses a JSON object of source→target mappings and returns a normalized rowset with:

- `fromkey`
- `tokey`

It also supports passing a `Code` instead of raw JSON, in which case it looks up the corresponding JSON from `dbo.Transforms`. If duplicate source keys appear, it selects the alphabetically first target value. :contentReference[oaicite:8]{index=8} :contentReference[oaicite:9]{index=9}

## Why transforms exist

TimeSolution is about integration and flexible regrouping. A process can be studied at different levels:

- the raw event-code level
- a slightly normalized level
- a higher semantic grouping level

Transforms let you reuse the same event data for multiple modeling perspectives without rewriting the source data. For example, a website clickstream might preserve raw page names in the warehouse, while a transform groups many specific pages into broader buckets such as `dietpage`, `proteinbars`, or `traffic`. The sample `UpdateTransform` metadata shows exactly this style of mapping. :contentReference[oaicite:10]{index=10}

## JSON format for transforms

The expected input is a JSON object where each key is the original event code and each value is the transformed event code.

Example:

```json
{
  "heavytraffic": "traffic",
  "moderatetraffic": "traffic",
  "lighttraffic": "traffic"
}
````

Another example from the script metadata:

```json
{
  "arnold1": "arnold",
  "arnold2": "arnold",
  "keto1": "dietpage",
  "weightwatcher1": "dietpage",
  "vanproteinbars": "proteinbars",
  "chocproteinbars": "proteinbars"
}
```

The `ParseTransforms` metadata and examples confirm this structure.  

## Important behavior of `dbo.ParseTransforms`

`dbo.ParseTransforms` accepts one parameter:

* `@transforms NVARCHAR(MAX)` — either raw JSON or a `Code` referencing a row in `dbo.Transforms` 

If the input matches a `Code` in `dbo.Transforms`, the function loads that stored JSON first. Then it parses the JSON into rows. This is important because an agent can either:

* pass the raw JSON directly
* or pass the short code of a stored transform

That makes transforms reusable and easier to reference consistently across procedures. 

The function also resolves duplicates conservatively by taking the alphabetically first target for a duplicated source key. That is a validation and normalization behavior, not a signal that duplicate keys are desirable. An agent should still aim to provide clean, non-duplicated JSON. 

## How stored procedures use transforms

The current stored-procedure metadata shows `@transforms` as a standard parameter in sequence/modeling procedures. For example, `sp_Sequences` includes:

* `@transforms NVARCHAR(MAX)` — described as a JSON or code mapping of event rename transformations 

That means sequence-building logic is designed to accept a transform layer before computing process statistics. In other words, transforms are part of the **model definition**, not just an afterthought.

This also explains why TimeSolution stores a `TransformsKey`: two models that differ only by transform definition should be treated as different model definitions. The metadata for `InsertTransforms` and the references to `TransformsKey` in downstream logic support that pattern. 

## Recommended agent workflow

### Step 1: decide whether regrouping is needed

Use transforms when you want to:

* combine several low-level events into one broader category
* standardize synonyms or near-synonyms
* study the same process at a more abstract level
* reduce fragmentation from overly specific event names

Do **not** use transforms if the original event distinctions are analytically important for the current task.

### Step 2: create or retrieve the transform definition

If the transform set should be reusable, store it in `dbo.Transforms` using `dbo.InsertTransforms`.

Example:

```sql
DECLARE @TransformsKey VARBINARY(16);

EXEC dbo.InsertTransforms
    @Transforms = N'{
        "heavytraffic":"traffic",
        "moderatetraffic":"traffic",
        "lighttraffic":"traffic"
    }',
    @Code = N'TRAFFIC_GROUPING',
    @Transformskey = @TransformsKey OUTPUT;

SELECT @TransformsKey AS TransformsKey;
```

This procedure computes the canonical key and inserts the definition only if it does not already exist. 

### Step 3: inspect the normalized mapping

Use `dbo.ParseTransforms` to verify what the engine will actually use.

Example with raw JSON:

```sql
SELECT *
FROM dbo.ParseTransforms(N'{
    "heavytraffic":"traffic",
    "moderatetraffic":"traffic",
    "lighttraffic":"traffic"
}');
```

Example with a stored code:

```sql
SELECT *
FROM dbo.ParseTransforms(N'TRAFFIC_GROUPING');
```

That second form works because `ParseTransforms` can treat the input as a code lookup into `dbo.Transforms`. 

### Step 4: use the transform in downstream procedures

Pass the transform JSON or stored code into procedures such as `sp_Sequences`.

Example:

```sql
EXEC dbo.sp_Sequences
    @EventSet = N'lighttraffic,moderatetraffic,heavytraffic',
    @enumerate_multiple_events = 0,
    @StartDateTime = '2026-01-01',
    @EndDateTime = '2026-01-31',
    @transforms = N'TRAFFIC_GROUPING',
    @ByCase = 1,
    @Metric = N'Time Between',
    @CaseFilterProperties = NULL,
    @EventFilterProperties = NULL,
    @ForceRefresh = 0;
```

The exact behavior downstream depends on the procedure, but the metadata makes clear that transform-based event renaming is part of the sequence/model parameter set. 

## Best practices for agents

### Prefer reusable codes for common transforms

If the same regrouping will be used more than once, store it in `dbo.Transforms` and reference it by `Code`. This makes model definitions easier to reproduce and audit. 

### Keep transforms semantically coherent

A transform should regroup events for a clear analytical reason. Do not merge unrelated events merely to reduce cardinality.

Good:

* `heavytraffic`, `moderatetraffic`, `lighttraffic` → `traffic`

Less good:

* `heavytraffic`, `customercomplaint`, `storeclosed` → `problem`

### Preserve the original data

Transforms should not be used to overwrite source event codes in warehouse tables. They are a modeling layer.

### Avoid accidental ambiguity

Do not create multiple competing transform codes for nearly identical definitions unless there is a governed reason. Reuse existing codes where practical.

### Validate before use

Always inspect with `dbo.ParseTransforms` before using a new transform set in a modeling procedure.

## Updating a stored transform

If the transform definition needs maintenance, use `dbo.UpdateTransform`.

Example based on the current script pattern:

```sql
DECLARE @tk VARBINARY(16);

EXEC dbo.UpdateTransform
    @Transforms = N'{
        "arnold1":"arnold",
        "arnold2":"arnold",
        "keto1":"dietpage",
        "weightwatcher1":"dietpage",
        "vanproteinbars":"proteinbars",
        "chocproteinbars":"proteinbars"
    }',
    @Code = N'Map1',
    @Dessciption = N'Maps event variants into grouped categories',
    @Transformskey = @tk OUTPUT;

SELECT @tk AS TransformsKey;
```

This updates the transform metadata while preserving the canonical key logic. 

## A concrete example

Suppose the raw event stream contains these web events:

* `arnold1`
* `arnold2`
* `keto1`
* `weightwatcher1`
* `vanproteinbars`
* `chocproteinbars`

You want a higher-level process view with broader event groups:

* `arnold`
* `dietpage`
* `proteinbars`

Create the transform:

```sql
DECLARE @TransformsKey VARBINARY(16);

EXEC dbo.InsertTransforms
    @Transforms = N'{
        "arnold1":"arnold",
        "arnold2":"arnold",
        "keto1":"dietpage",
        "weightwatcher1":"dietpage",
        "vanproteinbars":"proteinbars",
        "chocproteinbars":"proteinbars"
    }',
    @Code = N'WEB_GROUPING_1',
    @Transformskey = @TransformsKey OUTPUT;
```

Verify it:

```sql
SELECT *
FROM dbo.ParseTransforms(N'WEB_GROUPING_1');
```

Then use `WEB_GROUPING_1` as the `@transforms` input for sequence or model-building procedures. This lets the same raw clickstream be studied at a broader semantic level.  

## Relationship to model identity

Transforms are part of the definition of a model or sequence result. A model built with no transforms is not the same as a model built with `WEB_GROUPING_1`, even if every other parameter is identical. This is why TimeSolution stores transforms through a stable key and includes them in downstream parameterized workflows.  

## Source material

This tutorial is based on the current TimeSolution SQL objects in the provided database scripts, especially:

* `dbo.Transforms`, which stores transform JSON payloads and metadata 
* `dbo.InsertTransforms`, which computes and stores canonical transform definitions and returns `TransformsKey` 
* `dbo.UpdateTransform`, which updates stored transform definitions and metadata 
* `dbo.ParseTransforms`, which parses raw JSON or a stored code into source→target mappings  
* `sp_Sequences`, whose parameter list shows `@transforms` as part of the sequence/model definition 

The repository schema file `timesolution_stored_procedures.sql` was also referenced by the request as supporting source material for how the procedures use transforms.


