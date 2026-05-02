
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

```text
CaseID
Properties
TargetProperties
CreateDate
```

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

```text
EventID
PropertyName
PropertySource
PropertyValueNumeric
PropertyValueAlpha
IsJSON
SourceColumnID
CreateDate
LastUpdate
EventPropertyCountAllocation
EventDate
Event
CaseID
AccessBitmap
```

There is also a view named `dbo.vwEventPropertiesParsed`.

The verified columns exposed by the view are:

```text
EventID
PropertyName
PropertySource
PropertyValueNumeric
PropertyValueAlpha
ValueIsJSON
SourceColumnID
SourceID
SourceDescription
SourceName
SourceColumnName
```

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

```text
SourceID
Description
SourceProperties
Name
DefaultTableName
IRI
DatabaseName
ServerName
PropertiesJSONFullyQualifiedColumnName
TargetJSONFullyQualifiedColumnName
DefaultObserverID
AccessBitmap
```

The verified columns in `dbo.SourceColumns` are:

```text
SourceColumnID
SourceID
TableName
ColumnName
IsKey
IsOrdinal
DataType
Description
IRI
ObserverID
AccessBitmap
```

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
    @SeqA NVARCHAR(MAX),
    @SeqB NVARCHAR(MAX),
    @EventSet NVARCHAR(MAX),
    @StartDateTime DATETIME = NULL,
    @EndDateTime DATETIME = NULL,
    @transforms NVARCHAR(MAX),
    @CaseFilterProperties NVARCHAR(MAX),
    @EventFilterProperties NVARCHAR(MAX),
    @GroupType NVARCHAR(10),
    @SessionID UNIQUEIDENTIFIER = NULL OUTPUT,
    @CreatedBy_AccessBitmap BIGINT = NULL,
    @AccessBitmap BIGINT = NULL
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

```text
ModelID
GroupType
EventSetAKey
EventSetBKey
ACount
BCount
A_Int_BCount
PB|A
PA|B
TotalCases
PA
PB
CreateDate
AnomalyCategoryIDA
AnomalyCategoryIDB
LastUpdate
```

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



```
```
