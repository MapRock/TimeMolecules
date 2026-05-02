
# Event and Case Properties: OpenTelemetry, Bayesian Probabilities, and Hidden States

**Tutorial ID:** `event_case_properties_opentelemetry_bayesian`  
**Version:** Spring 2026 Refresh  
**Related tutorials:**

- `tutorials/star_schema/`
- `tutorials/data_vault_connect_time_molecules_to_semantic_layer/`
- `tutorials/property_mdm_iri_rollup/`

## Purpose

Time Molecules is not only about event sequences.

A Markov model can tell us:

```text
Given Event A, what is the probability of Event B?
````

But many real process questions are more conditional:

```text
Given these case properties and event properties,
what is the probability of the next event or outcome?
```

That is where event properties, case properties, OpenTelemetry-style payloads, Bayesian probabilities, and hidden-state reasoning come together.

The event sequence gives the Markov/process side. The properties provide the context. Bayesian probabilities use those properties as conditions. Hidden states are inferred from those conditions, from event sequences, or from related processes.

## 1. Events are not just names

An event name tells us what happened:

```text
Warning
Adjustment
Failure
Restart
ShipmentArrived
PromptSubmitted
Pitch
Strike
```

But the event name alone is rarely enough.

A useful event also carries a payload. This is the same general idea used in telemetry systems such as OpenTelemetry: an event is a timestamped observation with structured attributes.

A simplified OpenTelemetry-style event might look like this:

```json
{
  "time_unix_nano": 1717359286123456789,
  "body": {
    "event.name": "machine_warning",
    "event.description": "A machine warning was generated during a production run."
  },
  "attributes": {
    "case.production_run_id": "run_001",
    "case.machine_id": "machine_17",
    "case.shift": "night",
    "case.product_type": "product_x",

    "actual.temperature": 212.4,
    "actual.vibration": 0.87,
    "actual.warning_code": "HIGH_VIBRATION",

    "expected.temperature": 185.0,
    "expected.vibration": 0.40,
    "expected.output_rate": 125.0,

    "intended.output_rate": 130.0,

    "hidden.machine_state": "possible_bearing_wear",
    "hidden.operator_state": "compensating"
  }
}
```

The strict OpenTelemetry export format is more verbose, but the basic idea is simple: an event has a timestamp, a name, and structured attributes.

In Time Molecules, those attributes become event and case properties.

## 2. Raw event properties in Time Molecules

The raw event property payload is stored in `dbo.EventProperties`.

The verified columns are:

```text
EventID
ActualProperties
ExpectedProperties
AggregationProperties
LastUpdated
CreateDate
IntendedProperties
TriggerFunction
```

A simple inspection query is:

```sql
SELECT TOP 100
    EventID,
    ActualProperties,
    IntendedProperties,
    ExpectedProperties,
    AggregationProperties,
    TriggerFunction,
    CreateDate,
    LastUpdated
FROM dbo.EventProperties
ORDER BY EventID DESC;
```

The four main event-property payloads are:

| Column                  | Purpose                                                               |
| ----------------------- | --------------------------------------------------------------------- |
| `ActualProperties`      | What actually happened                                                |
| `IntendedProperties`    | What was intended, targeted, or attempted                             |
| `ExpectedProperties`    | What was expected, forecast, predicted, or modeled                    |
| `AggregationProperties` | Values useful for grouping, summarizing, filtering, or model-building |

This distinction matters. A process often becomes much more intelligible when actual, intended, and expected values are kept separate.

For example, a machine may have:

```text
intended output rate
expected output rate
actual output rate
```

The difference between those values may itself become analytically meaningful.

## 3. Raw case properties

Case-level payloads are stored in `dbo.CaseProperties`.

The verified columns are:

Case-level payloads are stored in `dbo.CaseProperties`.

The verified columns are:

| Column | Description |
|---|---|
| `CaseID` | The identifier of the case or process instance that these properties describe. This is the primary key of `dbo.CaseProperties` and links the property payload to a specific case. |
| `Properties` | A JSON-style payload of descriptive case-level properties. These are the contextual attributes of the case, such as customer, machine, location, shift, game, visit, encounter, or other process-level characteristics. |
| `TargetProperties` | A JSON-style payload of target, intended, desired, or comparison properties for the case. These can represent goals, expected case-level outcomes, planned values, or values used for later comparison against actual case behavior. |
| `CreateDate` | The datetime when the case-property row was created. |
|

These properties describe the larger context of the case rather than a single event. For example, if the case is a production run, `Properties` might describe the machine, shift, product, or plant. `TargetProperties` might describe the intended output, expected throughput, or target quality level for that run.

A simple inspection query is:

```sql
SELECT TOP 100
    CaseID,
    Properties,
    TargetProperties,
    CreateDate
FROM dbo.CaseProperties
ORDER BY CaseID DESC;
```

A case is the larger process instance.

Examples:

```text
Production run
Customer journey
Shipment
Patient encounter
Sales cycle
AI agent session
Baseball at-bat
Poker hand
```

An event is one observation inside that case.

Examples:

```text
Machine warning
Operator adjustment
Shipment scanned
Page viewed
Prompt submitted
Pitch thrown
Card dealt
```

Case properties describe the larger situation. Event properties describe the specific observation.

## 4. Parsed event properties

The raw JSON payloads are useful for ingestion, but parsed properties are much easier to query.

The parsed event-property table is `dbo.EventPropertiesParsed`.

The verified columns are:

| Column | Description |
|---|---|
| `EventID` | The identifier of the event that the parsed property belongs to. This links the property back to the source event in the event stream. |
| `PropertyName` | The name of the parsed property extracted from the event payload. Examples might include values such as temperature, vibration, pitch type, warning code, location, or outcome, depending on the source event. |
| `PropertySource` | Indicates which event-property payload the value came from. In the current schema, this maps through `dbo.PropertySource`, where `0 = InputProperties`, `1 = OutputProperties`, and `2 = AggregationProperties`. Conceptually, this distinguishes different classes of event payload values. |
| `PropertyValueNumeric` | The numeric value of the property, when the property can be represented as a number. This supports filtering, comparison, aggregation, statistical analysis, metrics, and probability calculations. |
| `PropertyValueAlpha` | The text value of the property, when the property is categorical, descriptive, coded, or otherwise non-numeric. |
| `IsJSON` | Indicates whether the parsed property value itself is JSON. This allows a property to contain a nested structure rather than a simple scalar value. |
| `SourceColumnID` | The source-column lineage identifier for the property, when known. This links the parsed property back to `dbo.SourceColumns`, helping preserve where the property came from in the original source data. |
| `CreateDate` | The datetime when the parsed event-property row was created. |
| `LastUpdate` | The datetime when the parsed event-property row was last updated. |
| `EventPropertyCountAllocation` | A count-allocation value used when event properties participate in aggregation or probability calculations. This helps distribute event-property contribution when a property participates in counted analytical structures. |
| `EventDate` | The datetime of the event associated with this parsed property. This allows property-level analysis by time without always joining back to the event table. |
| `Event` | The event name associated with this parsed property. This allows the property to be analyzed in the context of the event type or event label. |
| `CaseID` | The identifier of the case or process instance containing the event. This links the parsed event property back to the larger process instance. |
| `AccessBitmap` | Security bitmap used to support access filtering. This allows property-level rows to participate in the Time Molecules access-control pattern. |

These parsed rows turn event payload JSON into queryable relational values. That is what allows event properties to participate in filtering, Bayesian probability generation, dimensional modeling, Data Vault structures, semantic-layer mapping, and hidden-state inference.

There is also a view named `dbo.vwEventPropertiesParsed`.

The verified columns exposed by the view are:

| Column | Description |
|---|---|
| `EventID` | The identifier of the event that the parsed property belongs to. This links the property back to the source event in the event stream. |
| `PropertyName` | The name of the parsed property extracted from the event payload. |
| `PropertySource` | Indicates which event-property payload the value came from. In the current schema, this maps through `dbo.PropertySource`, where `0 = InputProperties`, `1 = OutputProperties`, and `2 = AggregationProperties`. |
| `PropertyValueNumeric` | The numeric value of the property, when the property can be represented as a number. |
| `PropertyValueAlpha` | The text value of the property, when the property is categorical, descriptive, coded, or otherwise non-numeric. |
| `ValueIsJSON` | Indicates whether the property value itself is JSON. This is useful when the parsed value contains a nested structure rather than a simple scalar value. |
| `SourceColumnID` | The source-column lineage identifier for the property, when known. This links the parsed property back to `dbo.SourceColumns`. |
| `SourceID` | The identifier of the source system, feed, table, file, stream, or other origin associated with the source column. |
| `SourceDescription` | The description of the source that supplied the property. This helps analysts and AI agents understand the origin and intended meaning of the property. |
| `SourceName` | The human-readable name of the source that supplied the property. |
| `SourceColumnName` | The column name in the original source that supplied or corresponds to this parsed property. |

`dbo.vwEventPropertiesParsed` is the more lineage-friendly way to inspect parsed event properties. It exposes the parsed property values together with source metadata, making the event payload easier to connect to ingestion lineage, semantic-layer terms, dimensional attributes, Data Vault satellites, Bayesian conditions, and hidden-state inference.

A safe inspection query is:

```sql
SELECT TOP 100
    EventID,
    PropertyName,
    PropertySource,
    PropertyValueNumeric,
    PropertyValueAlpha,
    ValueIsJSON,
    SourceColumnID,
    SourceID,
    SourceName,
    SourceColumnName
FROM dbo.vwEventPropertiesParsed
ORDER BY EventID DESC, PropertyName;
```

Notice that the view resolves `PropertySource` into a readable value using `dbo.PropertySource`.

The verified mapping in `dbo.PropertySource` is:

```text
0 = InputProperties
1 = OutputProperties
2 = AggregationProperties
```

That naming is older than the current `ActualProperties`, `IntendedProperties`, and `ExpectedProperties` framing, but the role is similar: the system needs to remember what kind of property it is looking at.

## 5. Parsed case properties

The parsed case-property table is `dbo.CasePropertiesParsed`.

The verified columns are:

```text
CaseID
PropertyName
PropertyValueNumeric
PropertyValueAlpha
SourceColumnID
AddedProperty
CreateDate
LastUpdate
SortValue
StartDateTime
EndDateTime
AccessBitmap
```

There is also a view named `dbo.vwCasePropertiesParsed`.

The verified columns exposed by the view are:

```text
CaseID
PropertyName
PropertyValueNumeric
PropertyValueAlpha
ValueIsJson
SourceColumnID
TableName
ColumnName
ColumnDescription
SourceID
SourceDescription
SourceName
```

A safe inspection query is:

```sql
SELECT TOP 100
    CaseID,
    PropertyName,
    PropertyValueNumeric,
    PropertyValueAlpha,
    ValueIsJson,
    SourceColumnID,
    TableName,
    ColumnName,
    ColumnDescription,
    SourceID,
    SourceDescription,
    SourceName
FROM dbo.vwCasePropertiesParsed
ORDER BY CaseID DESC, PropertyName;
```

The parsed property structures are where Time Molecules starts moving from raw event capture into queryable analytical structure.

## 6. Sources and SourceColumns

Properties should not remain anonymous payload fragments.

Time Molecules uses `dbo.Sources` and `dbo.SourceColumns` to preserve where properties came from.

The verified columns in `dbo.Sources` are:

| Column | Description |
|---|---|
| `SourceID` | The identifier of the source system, stream, table, file, feed, or other origin of event and case data. |
| `Description` | A human-readable description of the source and its role in the Time Molecules environment. |
| `SourceProperties` | A JSON-style payload of metadata about the source itself. This can describe source-level characteristics that are not captured by the individual relational columns. |
| `Name` | The human-readable name of the source. |
| `DefaultTableName` | The default table name associated with the source, when the source maps naturally to a table or table-like structure. |
| `IRI` | A semantic-web identifier for the source, when the source is linked to an ontology, vocabulary, knowledge graph, or other semantic reference. |
| `DatabaseName` | The database associated with the source, when applicable. |
| `ServerName` | The server associated with the source, when applicable. |
| `PropertiesJSONFullyQualifiedColumnName` | The fully qualified column name containing the source’s properties JSON payload, when applicable. |
| `TargetJSONFullyQualifiedColumnName` | The fully qualified column name containing the source’s target, intended, expected, or comparison JSON payload, when applicable. |
| `DefaultObserverID` | The default observer associated with this source. This can identify the system, process, agent, person, or mechanism that observed or supplied the data. |
| `AccessBitmap` | Security bitmap used to support source-level access filtering. |

The verified columns in `dbo.SourceColumns` are:

| Column | Description |
|---|---|
| `SourceColumnID` | The identifier of a specific source column or source field. Parsed event and case properties can use this value to preserve lineage back to the original source field. |
| `SourceID` | The source identifier that this column belongs to. This links the column back to `dbo.Sources`. |
| `TableName` | The table name associated with the source column, when applicable. |
| `ColumnName` | The name of the column or field in the original source. |
| `IsKey` | Indicates whether the source column participates as a key or identifying field in the source data. |
| `IsOrdinal` | Indicates whether the source column represents an ordinal, sequence, rank, or ordering value. |
| `DataType` | The data type of the source column or field. |
| `Description` | A human-readable description of the source column and its meaning. |
| `IRI` | A semantic-web identifier for the source column, when the column is linked to an ontology, vocabulary, knowledge graph, or semantic-layer concept. |
| `ObserverID` | The observer associated with this source column, when different from or more specific than the source’s default observer. |
| `AccessBitmap` | Security bitmap used to support source-column-level access filtering. |

Together, `dbo.Sources` and `dbo.SourceColumns` give event and case properties lineage. A parsed property is no longer just a JSON key/value pair. It can be traced back to a source, a table, a column, an observer, a security context, and potentially an IRI-linked semantic meaning.

A safe lineage query is:

```sql
SELECT TOP 200
    s.SourceID,
    s.Name AS SourceName,
    s.Description AS SourceDescription,
    s.DefaultTableName,
    s.DatabaseName,
    s.ServerName,
    s.IRI AS SourceIRI,

    sc.SourceColumnID,
    sc.TableName,
    sc.ColumnName,
    sc.IsKey,
    sc.IsOrdinal,
    sc.DataType,
    sc.Description AS SourceColumnDescription,
    sc.IRI AS SourceColumnIRI
FROM dbo.Sources AS s
LEFT JOIN dbo.SourceColumns AS sc
    ON sc.SourceID = s.SourceID
ORDER BY
    s.Name,
    sc.TableName,
    sc.ColumnName;
```

This is important because the same property name can mean different things in different systems.

For example:

```text
location
```

could mean:

```text
machine location
warehouse location
customer location
delivery location
pitch location
```

`Sources` and `SourceColumns` help preserve lineage and meaning. They also help when the same properties are later used in dimensional models, Data Vault, semantic layers, or knowledge graphs.

## 7. Properties as Bayesian conditions

A Markov model asks:

```text
Given Event A, what is the probability of Event B?
```

A Bayesian or conditional probability question asks:

```text
Given these properties, what is the probability of Event B?
```

For example:

```text
Given:
  shift = night
  product_type = product_x
  warning_code = HIGH_VIBRATION

What is the probability of:
  Warning -> Failure
```

That is the role of `dbo.CreateUpdateBayesianProbabilities`.

The verified procedure signature is:

```sql
CREATE PROCEDURE dbo.CreateUpdateBayesianProbabilities
    @SeqA NVARCHAR(MAX),                         -- The first event or event sequence, representing condition A in the Bayesian probability calculation.
    @SeqB NVARCHAR(MAX),                         -- The second event or event sequence, representing condition or outcome B in the Bayesian probability calculation.
    @EventSet NVARCHAR(MAX),                     -- The event set used to limit which events are included in the analysis.
    @StartDateTime DATETIME = NULL,              -- Optional lower bound for event dates included in the probability calculation.
    @EndDateTime DATETIME = NULL,                -- Optional upper bound for event dates included in the probability calculation.
    @transforms NVARCHAR(MAX),                   -- Optional transform definition or transform code used to remap event names before calculating probabilities.
    @CaseFilterProperties NVARCHAR(MAX),         -- Optional JSON filter for case-level properties used to restrict the cases included in the calculation.
    @EventFilterProperties NVARCHAR(MAX),        -- Optional JSON filter for event-level properties used to restrict the events included in the calculation.
    @GroupType NVARCHAR(10),                     -- The grouping level used for co-occurrence counting, such as CaseID, DAY, MONTH, or YEAR.
    @SessionID UNIQUEIDENTIFIER = NULL OUTPUT,   -- Optional session identifier used to isolate intermediate work rows for this calculation.
    @CreatedBy_AccessBitmap BIGINT = NULL,       -- Optional access bitmap representing the creator or caller’s access context.
    @AccessBitmap BIGINT = NULL                  -- Optional access bitmap assigned to the generated Bayesian probability rows.
```

A pattern call looks like this:

```sql
DECLARE @SessionID UNIQUEIDENTIFIER;

EXEC dbo.CreateUpdateBayesianProbabilities
    @SeqA = N'Warning',
    @SeqB = N'Failure',
    @EventSet = N'Warning,OperatorAdjustment,Failure,Restart',
    @StartDateTime = '2026-01-01',
    @EndDateTime = '2026-05-02',
    @transforms = NULL,
    @CaseFilterProperties = N'{"shift":"night","product_type":"product_x"}',
    @EventFilterProperties = N'{"warning_code":"HIGH_VIBRATION"}',
    @GroupType = N'CaseID',
    @SessionID = @SessionID OUTPUT,
    @CreatedBy_AccessBitmap = NULL,
    @AccessBitmap = NULL;
```

Replace the event names and property names with values that actually exist in your data.

The conceptual pattern is:

```text
SeqA:
  the condition event or sequence

SeqB:
  the outcome event or sequence

CaseFilterProperties:
  filters on case-level context

EventFilterProperties:
  filters on event-level context

GroupType:
  how the co-occurrence is grouped
```

`dbo.DefaultGroupType` verifies that valid group types are:

```text
CaseID
DAY
MONTH
YEAR
```

If an invalid value is passed, it falls back to `CaseID`.

## 8. The Bayesian probability output

`CreateUpdateBayesianProbabilities` stores results in `dbo.BayesianProbabilities`.

The verified columns are:

| Column | Description |
|---|---|
| `ModelID` | The identifier of the model associated with the Bayesian probability calculation. |
| `GroupType` | The grouping level used for the probability calculation, such as `CaseID`, `DAY`, `MONTH`, or `YEAR`. |
| `EventSetAKey` | The key representing event or event sequence A. This is the “given” side of the probability calculation when reading `PB\|A`. |
| `EventSetBKey` | The key representing event or event sequence B. This is the outcome side of the probability calculation when reading `PB\|A`. |
| `ACount` | The count of groups where event set A appears. |
| `BCount` | The count of groups where event set B appears. |
| `A_Int_BCount` | The count of groups where both event set A and event set B appear. This is the intersection count used to calculate conditional probabilities. |
| `PB\|A` | Probability of B given A. In practical terms: when A appears, how often does B also appear within the selected grouping context? |
| `PA\|B` | Probability of A given B. In practical terms: when B appears, how often does A also appear within the selected grouping context? |
| `TotalCases` | The total number of groups considered in the calculation. Depending on `GroupType`, this may represent cases, days, months, or years. |
| `PA` | Marginal probability of A across the selected grouping context. |
| `PB` | Marginal probability of B across the selected grouping context. |
| `CreateDate` | The datetime when the Bayesian probability row was created. |
| `AnomalyCategoryIDA` | Optional anomaly category identifier associated with event set A. |
| `AnomalyCategoryIDB` | Optional anomaly category identifier associated with event set B. |
| `LastUpdate` | The datetime when the Bayesian probability row was last updated. |

These rows turn event co-occurrence into reusable conditional probability knowledge. For example, `PB\|A` can be read as “given A, how likely is B?” while `PA\|B` can be read as “given B, how likely was A?” This makes event and property-filtered co-occurrence available for Bayesian reasoning, hidden-state inference, process comparison, and semantic-layer consumption.e


A simple inspection query is:

```sql
SELECT TOP 100
    ModelID,
    GroupType,
    EventSetAKey,
    EventSetBKey,
    ACount,
    BCount,
    A_Int_BCount,
    [PB|A],
    [PA|B],
    TotalCases,
    PA,
    PB,
    CreateDate,
    LastUpdate
FROM dbo.BayesianProbabilities
ORDER BY CreateDate DESC;
```

The most important values are:

| Column         | Meaning                                             |                          |
| -------------- | --------------------------------------------------- | ------------------------ |
| `ACount`       | Count of sequence/event A                           |                          |
| `BCount`       | Count of sequence/event B                           |                          |
| `A_Int_BCount` | Count where A and B appear together in the grouping |                          |
| `PB            | A`                                                  | Probability of B given A |
| `PA            | B`                                                  | Probability of A given B |
| `PA`           | Marginal probability of A                           |                          |
| `PB`           | Marginal probability of B                           |                          |
| `TotalCases`   | Total grouping count used for the calculation       |                          |

This is where properties become probability conditions rather than just descriptive metadata.

## 9. Hidden states

A hidden state is a condition that affects the process but is not directly observed as a normal event.

Examples:

```text
machine bearing wear
calibration drift
operator compensating
material quality problem
pitcher fatigue
customer frustration
patient deterioration
AI agent confusion
```

These states may not appear directly in the raw event stream.

Instead, they may be inferred from event sequences and properties.

For example:

```text
Rising temperature
+ increasing vibration
+ repeated warnings
+ lower output
+ recent maintenance
= possible bearing wear
```

That hidden state can then be stored as a property:

```json
{
  "hidden.machine_state": "possible_bearing_wear"
}
```

Or it can become a synthetic event:

```text
BearingWearSuspected
```

Once represented, the hidden state becomes available to the rest of Time Molecules:

```text
Markov models
Bayesian probabilities
Model comparison
Drill-through
Dimensional models
Data Vault
Semantic layer
Knowledge graph linkage
```

## 10. Hidden states are not limited to one event

A hidden state may be inferred from one event, but often it spans a wider context.

It may span:

```text
several recent events
an entire case
a related case
a time window
a separate process
an external condition
```

Weather may be its own process, but it affects outdoor events.

Maintenance backlog may be its own process, but it affects machine reliability.

Customer support history may be its own process, but it affects churn.

This is why Time Molecules should not treat hidden states as merely extra columns on one event. They may be discovered through relationships between processes.

## 11. HiddenMarkovModels function

The current schema does include `dbo.HiddenMarkovModels`.

Its purpose is to provide a unified transition-probability view over Bayesian probabilities and standard Markov model events.

A simple inspection query is:

```sql
SELECT TOP 100
    ModelID,
    ModelType,
    ParamHash,
    EventA,
    EventB,
    Probability
FROM dbo.HiddenMarkovModels()
ORDER BY
    ModelID,
    EventA,
    EventB;
```

The verified output columns are:

```text
ModelID
ModelType
ParamHash
EventA
EventB
Probability
```

Conceptually, this function helps create a Hidden Markov-style view of the process by putting Bayesian and Markov transition probabilities into one comparable shape.

The observed events remain visible:

```text
Warning -> Adjustment -> Restart -> Failure
```

The hidden-state interpretation comes from the conditions and probabilities around those transitions:

```text
possible_bearing_wear
operator_compensating
calibration_drift
material_quality_problem
```

## 12. Relationship to dimensional models

Event and case properties can feed dimensional models.

Examples:

```text
DimMachine
DimShift
DimProduct
DimLocation
DimWarningType
DimHiddenMachineState
DimOperatorAction
```

A fact table may expose measures such as:

```text
event count
warning count
failure count
average temperature
average vibration
probability of failure
probability of restart
```

This is where Time Molecules connects naturally to star schema design.

The dimensional model makes the properties usable for BI tools and semantic layers.

Time Molecules adds the process view:

```text
What usually happens next?
How does the sequence change by property?
Which hidden state changes the transition probabilities?
What changed between two time periods, locations, machines, or customer segments?
```
See: https://github.com/MapRock/TimeMolecules/tree/main/tutorials/star_schema

## 13. Relationship to Data Vault

Data Vault is also a natural fit because event and case properties often arrive from multiple systems and improve over time.

A simple mapping is:

| Time Molecules       | Data Vault-style Role                               |
| -------------------- | --------------------------------------------------- |
| Case                 | Business key / hub candidate                        |
| Event                | Transactional occurrence / link candidate           |
| Event property       | Satellite attribute                                 |
| Case property        | Satellite attribute                                 |
| Source               | Record source                                       |
| SourceColumn         | Attribute lineage                                   |
| Hidden state         | Derived/business-vault attribute or synthetic event |
| Bayesian probability | Analytic/business-vault output                      |
| Markov model         | Process-behavior analytic product                   |

The important point is that Time Molecules can ingest events before every enterprise modeling decision is complete.

The event can be captured first.

The interpretation can improve later.

That is especially important for OpenTelemetry, IoT, application logs, AI agent logs, and other high-volume event streams.

See: https://github.com/MapRock/TimeMolecules/tree/main/tutorials/data_vault_connect_time_molecules_to_semantic_layer

## 14. Relationship to the semantic layer

A semantic layer should not only expose conventional measures.

It can also expose process-aware and probability-aware concepts:

```text
Probability of failure given warning
Probability of restart given warning
Probability of churn given recent support pattern
Probability of next event given current event
Probability of next event given hidden state
```

Properties make those governed semantic concepts possible.

`Sources` and `SourceColumns` help preserve where the property came from.

Dimensional models and Data Vault structures make those properties consumable.

Time Molecules makes them process-aware.

## 15. The full pattern

The pattern is:

```text
1. Ingest events liberally.
2. Preserve raw event and case properties.
3. Anchor incoming fields through Sources and SourceColumns.
4. Parse properties into queryable structures.
5. Build Markov models from event sequences.
6. Build Bayesian probabilities from event and case properties.
7. Infer hidden states from sequences, properties, and related processes.
8. Store hidden states as properties or synthetic events.
9. Feed dimensional models, Data Vault, semantic layers, and knowledge graphs.
10. Drill back from probabilities and models to the underlying events.
```

## 16. Why this matters

An event sequence can tell us what usually follows what.

Event and case properties tell us under what conditions the sequence changes.

Bayesian probabilities tell us how strongly those conditions affect outcomes.

Hidden states give us a way to represent inferred process context.

Together, they move Time Molecules beyond simple Markov chains:

```text
Events provide the sequence.
Properties provide the conditions.
Bayesian probabilities provide conditional likelihoods.
Hidden states provide inferred process context.
Markov models provide process structure.
Sources and SourceColumns provide lineage.
Dimensional models, Data Vault, and semantic layers make the result usable.
```


