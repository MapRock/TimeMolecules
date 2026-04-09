
# How to use IRI columns in TimeSolution

TimeSolution is about integration across events, cases, source metadata, and external semantics. One important mechanism for that integration is the use of `IRI` columns in lookup-style tables. In the schema metadata, the `IRI` column is explicitly described as “the gateway to a knowledge graph” for several core dimensions, including `CaseTypes`, `DimAnomalyCategories`, `DimEvents`, and `SourceColumns`.  The `timesolution_tables.sql` schema file in the repository also documents `SourceColumns.Description` as the text used to help determine an RDF/knowledge-graph class that matches the meaning of the column, and then pairs that with `SourceColumns.IRI`. :contentReference[oaicite:1]{index=1}

## What this skill is for

This skill explains:

1. what the `IRI` column means in TimeSolution
2. which TimeSolution tables use it today
3. how an AI agent should populate and maintain it
4. how it is consumed by existing TimeSolution code
5. how to query it safely and usefully

The goal is not to turn TimeSolution into a full RDF store. The goal is to give TimeSolution rows a durable semantic link outward to a knowledge graph such as Wikidata, SKOS, FOAF, DBpedia, or your own enterprise ontology. 

## Why `IRI` exists

In TimeSolution, business and process concepts live in relational lookup tables because that is the practical BI and process-mining side of the system. But relational codes alone are local. `IRI` provides a portable identifier that can connect those local members to broader semantic meaning.

Examples:

- a `CaseType` can be linked to a broader domain class
- a `DimEvent` member can be linked to a concept in a process ontology
- a `SourceColumn` can be linked to a known property in an external vocabulary
- an anomaly category can be linked to a controlled term in an ontology

This is why the schema repeatedly describes `IRI` as the gateway to a knowledge graph. 

## Where `IRI` is used now

From the current schema material, the `IRI` column is explicitly documented in at least these tables:

- `dbo.CaseTypes`
- `dbo.DimAnomalyCategories`
- `dbo.DimEvents`
- `dbo.SourceColumns` :contentReference[oaicite:4]{index=4}

Those are exactly the kinds of lookup dimensions an agent should expect to enrich semantically.

The repository schema file also shows `SourceColumns.Description` and `SourceColumns.IRI` as a pair: the description helps determine the meaning of the source column, and the `IRI` stores the semantic identifier chosen for it. :contentReference[oaicite:5]{index=5}

## How existing TimeSolution code uses `IRI`

TimeSolution already includes a metadata export procedure designed for semantic-web and LLM-facing use:

- `dbo.get_semantic_web_llm_values` dynamically discovers tables with `Description` and `IRI` columns and returns a unified result set of object name, type, description, IRI, code column, and code value. Its metadata explicitly says this is for semantic-web and LLM embedding purposes. 

That procedure also has instance-level logic for important lookup tables:

- `DimEvents`
- `EventSets`
- `CaseTypes`
- `SourceColumns`

and emits their `IRI` values into a single output stream for downstream use. 

So the practical answer is:

**`IRI` is not just decorative metadata. It is already part of the export surface that TimeSolution uses to prepare semantic-web and LLM-oriented metadata.** 

## Prerequisites

Before an agent sets `IRI` values, it should confirm:

1. the row already has a stable local identifier such as `Event`, `Name`, or a source-column identity
2. the row has a meaningful `Description`
3. the selected `IRI` is the intended semantic target and not just a string that looks plausible
4. the organization’s policy allows external ontology links such as Wikidata or DBpedia, or else a private enterprise ontology should be used instead

In practice, `Description` should be authored first or improved first, because TimeSolution’s own schema notes say the description is intended to help determine the matching RDF class or concept. :contentReference[oaicite:9]{index=9}

## What a good `IRI` should look like

A good `IRI` in TimeSolution should be:

- stable
- globally meaningful or enterprise-meaningful
- specific enough to match the row’s concept
- not just a search URL
- not temporary
- not a human-only description

Good examples:

- a Wikidata entity URI
- a DBpedia resource URI
- a SKOS concept URI
- a FOAF property/class URI
- an enterprise ontology URI you control

Bad examples:

- a Google search URL
- a documentation page that only discusses the concept loosely
- a local dev URL that is not stable
- a literal text label instead of an identifier

## Recommended setup pattern

### Pattern 1: lookup members as ontology concepts

For lookup-style tables such as `CaseTypes`, `DimEvents`, and `DimAnomalyCategories`, use the `IRI` column to point to the semantic concept represented by that row.

Examples:

- a case type representing an emergency-room workflow could point to an enterprise ontology class for that workflow
- a `DimEvents` row such as `labresultposted` could point to a known event concept in a domain ontology
- an anomaly category such as `delay` could point to a concept in a quality or operations ontology

### Pattern 2: `SourceColumns` as semantic properties

For `SourceColumns`, the `IRI` should usually represent the meaning of the source field itself.

Examples:

- a source column meaning “patient identifier” maps to the ontology property or class for patient identity
- a source column meaning “pickup timestamp” maps to a date/time event property concept
- a source column meaning “store location code” maps to a location identifier concept

This is one of the most valuable uses, because `SourceColumns` sits at the metadata bridge between external source systems and TimeSolution’s internal event and case structures. The schema notes explicitly tie `SourceColumns.Description` to figuring out the RDF class that matches the meaning of the column. :contentReference[oaicite:10]{index=10}

## How an AI agent should populate `IRI`

An agent should use a disciplined sequence.

### Step 1: read the row and its description

For example:

```sql
SELECT
    SourceColumnID,
    SourceID,
    TableName,
    ColumnName,
    Description,
    IRI
FROM dbo.SourceColumns
WHERE IRI IS NULL
  AND Description IS NOT NULL;
````

### Step 2: infer the intended meaning from the description and context

Use:

* `Description`
* table name
* column name
* source name
* neighboring metadata such as source database or case/event role

### Step 3: choose the best semantic target

Prefer:

1. enterprise ontology URI, if one exists
2. well-established external ontology URI
3. no `IRI` yet, if confidence is low

An agent should **not** write an `IRI` when it is uncertain and there is no review path. Low-confidence matches are worse than blanks.

### Step 4: write the `IRI`

Example:

```sql
UPDATE dbo.SourceColumns
SET IRI = 'http://www.wikidata.org/entity/Q570780'
WHERE SourceColumnID = 123;
```

Or for `DimEvents`:

```sql
UPDATE dbo.DimEvents
SET IRI = 'https://example.org/ontology/events/OrderPlaced'
WHERE Event = 'orderplaced';
```

The exact URI should match your ontology strategy.

## Actionable example

Suppose `dbo.SourceColumns` contains a row:

* `TableName = PatientVisit`
* `ColumnName = AdmitDate`
* `Description = Date and time patient was admitted`

An agent workflow would be:

1. read the row
2. determine that the semantic meaning is an admission timestamp, not just any date
3. select the best ontology property or enterprise property URI for admission datetime
4. write that URI into `SourceColumns.IRI`
5. validate it later through semantic export

Then verify with:

```sql
SELECT
    SourceColumnID,
    TableName,
    ColumnName,
    Description,
    IRI
FROM dbo.SourceColumns
WHERE SourceColumnID = 123;
```

## How to validate the setup

The most direct validation path in current TimeSolution is to run:

```sql
EXEC dbo.get_semantic_web_llm_values @IncludeEventsAndCases = 0;
```

That procedure was built specifically to gather rows from tables with `Description` and `IRI` columns and emit a unified semantic-web / LLM feed.

If your `IRI` updates are correct, they should appear in its output for the relevant dimension rows. The procedure’s later logic explicitly includes `DimEvents`, `EventSets`, `CaseTypes`, and `SourceColumns` instance rows with their `IRI` values.

## Recommended guardrails for agents

An AI agent should follow these rules:

* do not overwrite a non-null `IRI` unless explicitly instructed or unless a review workflow exists
* do not fabricate ontology links from weak evidence
* do not use temporary or search-result URLs
* do not treat free-text description as equivalent to a semantic identifier
* prefer enterprise-controlled URIs when governance matters
* log or flag uncertain mappings for review instead of writing them automatically

A safe pattern is:

```sql
UPDATE dbo.SourceColumns
SET IRI = @IRI
WHERE SourceColumnID = @SourceColumnID
  AND IRI IS NULL;
```

That makes the agent additive rather than destructive.

## Query patterns agents can use

### Find lookup rows missing IRIs

```sql
SELECT Name, Description, IRI
FROM dbo.CaseTypes
WHERE IRI IS NULL
  AND Description IS NOT NULL;
```

```sql
SELECT Event, Description, IRI
FROM dbo.DimEvents
WHERE IRI IS NULL
  AND Description IS NOT NULL;
```

```sql
SELECT SourceColumnID, TableName, ColumnName, Description, IRI
FROM dbo.SourceColumns
WHERE IRI IS NULL
  AND Description IS NOT NULL;
```

### Review rows that already have IRIs

```sql
SELECT Event, Description, IRI
FROM dbo.DimEvents
WHERE IRI IS NOT NULL;
```

### Export for semantic/LLM use

```sql
EXEC dbo.get_semantic_web_llm_values 0;
```

## Relationship to the broader integration story

TimeSolution is fundamentally an integration system: event data, cases, parsed properties, source metadata, models, and semantic metadata all need to line up. `IRI` is one of the cleanest bridges from local BI/process structures into a knowledge graph. It does not replace relational keys. It complements them by giving important lookup members a portable semantic identity.

## Source material

This tutorial is based on:

* the TimeSolution database script and related SQL files in your provided materials, especially `dbo.get_semantic_web_llm_values` and its metadata/utilization blocks, which describe the semantic-web and LLM export of tables containing `Description` and `IRI` columns
* the current instance-level export logic showing `DimEvents`, `EventSets`, `CaseTypes`, and `SourceColumns` with `IRI` values in the semantic metadata output
* the repository schema file `timesolution_tables.sql`, which documents several `IRI` columns as “the gateway to a knowledge graph” and ties `SourceColumns.Description` to determining a matching RDF class ([GitHub][1])
* the general TimeSolution / Enterprise Intelligence integration framing in the provided appendices material, where lookup and metadata structures are linked outward to the enterprise knowledge graph 


[1]: https://raw.githubusercontent.com/MapRock/TimeMolecules/main/data/timesolution_schema/timesolution_tables.sql "raw.githubusercontent.com"
