
# Tutorial: Importing events from `STAGE.ImportEvents` into Time Molecules

The main import path is:

1. Load rows into `STAGE.ImportEvents`.
2. Run `dbo.ImportEventsFromStage`.
3. Review logging and imported data.
4. Parsed case and event properties are then refreshed automatically by the procedure.  

## 1. What `STAGE.ImportEvents` is for

`STAGE.ImportEvents` is the landing table for staged event rows. Each row represents **one event occurrence** belonging to a case. The current columns are:

* `SourceID`
* `CaseID`
* `Event`
* `EventDescription`
* `EventDate`
* `CaseProperties`
* `CaseTargetProperties`
* `EventActualProperties`
* `EventExpectedProperties`
* `EventAggregationProperties`
* `EventIntendedProperties`
* `DateAdded`
* `AccessBitmap`
* `CaseType`
* `NaturalKey_SourceColumnID` 

`dbo.ImportEventsFromStage` reads from this stage table, validates the rows, inserts any new event names into `dbo.DimEvents`, creates a batch, maps the staged natural `CaseID` values to new internal numeric `CaseID` values, loads `dbo.Cases`, `dbo.CaseProperties`, `dbo.EventsFact`, and `dbo.EventProperties`, and then refreshes parsed properties.   

## 2. Minimum required fields

At minimum, each staged row should have valid values for:

* `SourceID`
* `CaseID`
* `Event`
* `EventDate`
* `DateAdded`
* `AccessBitmap`

`CaseType` is not strictly required because the procedure will fall back to the `Unknown` case type if needed during case creation, but the validation step does check that any non-null `CaseType` exists in `dbo.CaseTypes` by name. It also validates that `SourceID` exists in `dbo.Sources`, that `Event` length is not greater than 50, and that `CaseProperties` is valid JSON if populated.  

## 3. How to fill each staging column

### `SourceID`

Use the `SourceID` from `dbo.Sources`. The procedure validates that the value exists. If you do not know the correct source, create or identify it first in `dbo.Sources`. The `Sources` table also holds metadata such as `Name`, `DefaultTableName`, `DatabaseName`, `ServerName`, and JSON-related defaults.  

Example:

```sql
SELECT SourceID, Name, DefaultTableName, Description
FROM dbo.Sources
ORDER BY Name;
```

### `CaseID`

This is the **natural key from the source system**, not the final internal `dbo.Cases.CaseID`. The import procedure groups stage rows by this value, creates a new internal numeric `CaseID` for each distinct staged natural key, and stores the original value into `dbo.Cases.NaturalKey`. 

Use something stable and source-native, for example:

* claim number
* visit ID
* order ID
* workflow instance ID
* session ID

A good mental model is: **all rows that belong to the same process instance should share the same staged `CaseID`.**

### `Event`

The event name must be 50 characters or less, or validation fails. The procedure also inserts any new event names into `dbo.DimEvents`, using `EventDescription` when available.  

Good examples:

* `arrive`
* `lab_ordered`
* `mri_started`
* `payment_received`

Bad examples:

* long verbose sentence-style labels
* values that vary row by row because of embedded IDs or timestamps

### `EventDescription`

Optional but useful. If the event name is new, the procedure uses `MAX(COALESCE(EventDescription, Event))` when inserting into `dbo.DimEvents`. So this is your chance to give a cleaner business description for the event type. 

### `EventDate`

Stored in stage as `nvarchar(30)`, but imported into `dbo.EventsFact` as `DATETIME`. So populate it with a SQL Server-convertible date/time string. The procedure recalculates `CaseOrdinal` within each case using `ORDER BY EventDate, Event`.  

Use an unambiguous format such as:

```sql
2026-04-17T08:30:00
```

### `CaseProperties`

Optional JSON describing the case as a whole. Validation checks this field for valid JSON when non-null. The procedure stores it in `dbo.CaseProperties.Properties`, and later `dbo.InsertCaseProperties @CompleteRefresh=1` reparses all case properties into the parsed relational form.   

This is where tuple-like case descriptors belong. Typical examples:

* patient
* product
* store
* campaign
* employee
* region
* diagnosis group

Example:

```json
{"patientid":"P10017","facility":"Boise ER","payer":"Medicare","gender":"F"}
```

### `CaseTargetProperties`

Optional JSON for what the case was aiming at or targeting. The procedure loads this into `dbo.CaseProperties.TargetProperties`. This is distinct from the descriptive case properties and is meant for target-related context. 

Example:

```json
{"target_department":"Cardiology","target_los_hours":4}
```

### `EventActualProperties`

Optional JSON for actual observed measurements or context tied to the individual event. The procedure loads it into `dbo.EventProperties.ActualProperties`. 

Example:

```json
{"heart_rate":118,"room":"ER-12","employeeid":"E778"}
```

### `EventExpectedProperties`

Optional JSON for what was expected at that event. Stored in `dbo.EventProperties.ExpectedProperties`. 

Example:

```json
{"expected_wait_minutes":15}
```

### `EventAggregationProperties`

Optional JSON describing aggregation or grouping context for the event. Stored in `dbo.EventProperties.AggregationProperties`. 

Example:

```json
{"shift":"night","department":"ER","week":"2026-W16"}
```

### `EventIntendedProperties`

Optional JSON describing intended action or intent for that event. Stored in `dbo.EventProperties.IntendedProperties`. 

Example:

```json
{"intended_disposition":"admit","priority":"high"}
```

### `DateAdded`

This is the import watermark column. The procedure imports only staged rows where `DateAdded > @ImportFromDate`. If you do not pass `@ImportFromDate`, it defaults to `MAX(EventDate)` from `dbo.EventsFact`.  

That means this column matters operationally. Set it to the ETL load time into stage, not the business event time.

### `AccessBitmap`

This is the row-level access bitmap for the staged data. For cases, the case map takes `MAX(x.AccessBitmap)` per natural case; for events, the event-level row imported to `dbo.EventsFact` uses `COALESCE(imp.AccessBitmap, @UserAccessBitmap)`. Since the stage table column is `NOT NULL`, you should usually populate it deliberately.  

### `CaseType`

Optional case type name, but if supplied it must exist in `dbo.CaseTypes` by `Name`, or validation fails. If null or unmatched during case insert, the procedure falls back to the `Unknown` case type ID.  

Examples:

* `Emergency Room Visit`
* `Sales Cycle`
* `Customer Web Session`

Use the exact `Name` value from `dbo.CaseTypes`.

### `NaturalKey_SourceColumnID`

This column exists in `STAGE.ImportEvents`, but the attached `dbo.ImportEventsFromStage` does **not** currently use it anywhere in the import logic. So right now it looks like metadata for lineage or future use, not part of the active load.  

My recommendation is:

* populate it when you know which source column supplied the natural case key
* do not depend on it for the current import behavior

## 4. How `SourceID` and `SourceColumnID` should be chosen

Use `dbo.Sources` to identify the source system, and `dbo.SourceColumns` to identify the source columns within that source. `SourceColumns` includes:

* `SourceColumnID`
* `SourceID`
* `TableName`
* `ColumnName`
* `IsKey`
* `IsOrdinal`
* `DataType`
* `Description` 

Use these helper queries:

```sql
SELECT SourceID, Name, DefaultTableName, Description
FROM dbo.Sources
ORDER BY Name;

SELECT SourceColumnID, SourceID, TableName, ColumnName, IsKey, IsOrdinal, DataType, Description
FROM dbo.SourceColumns
ORDER BY SourceID, TableName, ColumnName;
```

Or the combined view:

```sql
SELECT *
FROM dbo.vwSourceColumnsFull
ORDER BY SourceID, TableName, ColumnName;
```

That view joins source columns to source metadata. 

Practical guidance:

* `SourceID` should identify the source application or source dataset.
* `NaturalKey_SourceColumnID` should identify the source column that supplied the staged `CaseID`.
* For JSON properties like `patientid`, `employeeid`, `store`, `claimnumber`, those property names should ideally line up with `SourceColumns.ColumnName` where possible so later profiling and semantic cleanup are easier. The profiling procedure `dbo.sp_CasePropertyProfiling` explicitly tries to match parsed case property names to `SourceColumns.ColumnName`. 

## 5. Guidance for `CaseFilterProperties` and `EventFilterProperties`

I did **not** see columns with those exact names in the current `STAGE.ImportEvents` table. What I do see is a property model where case-level JSON lands in `CaseProperties` and event-level JSON lands in the various event property JSON columns, then later gets parsed into relational property tables.  

So in current schema terms, the practical equivalents are:

* **`CaseFilterProperties` concept** → put the tuple-defining case descriptors into `CaseProperties`
* **`EventFilterProperties` concept** → put event-level descriptors into `EventActualProperties` and, if needed, the other event JSON buckets

Why this matters: downstream procedures commonly use JSON/property-based selection logic for case populations. For example, `sp_CompareEventProximities` takes `@CaseFilterProperties1` and `@CaseFilterProperties2` as JSON filters for tuple-defined populations, so the properties you load here are what make that kind of filtering possible later. 

Practical recommendation:

* anything that defines **which case this is** or **which population the case belongs to** goes into `CaseProperties`
* anything that defines **what was true at this specific event occurrence** goes into `EventActualProperties`
* keep property names stable and business-meaningful

Example case-oriented JSON:

```json
{"employeeid":"E778","facility":"Boise ER","department":"ER","payer":"Medicare"}
```

Example event-oriented JSON:

```json
{"room":"ER-12","wait_minutes":22,"triage_level":3}
```

## 6. Example staged load

Here is a reasonable example:

```sql
INSERT INTO STAGE.ImportEvents
(
    SourceID,
    CaseID,
    Event,
    EventDescription,
    EventDate,
    CaseProperties,
    CaseTargetProperties,
    EventActualProperties,
    EventExpectedProperties,
    EventAggregationProperties,
    EventIntendedProperties,
    DateAdded,
    AccessBitmap,
    CaseType,
    NaturalKey_SourceColumnID
)
VALUES
(
    12,
    N'ERVISIT-100045',
    N'arrive',
    N'Patient arrives in emergency room',
    N'2026-04-17T08:11:00',
    N'{"patientid":"P10017","facility":"Boise ER","payer":"Medicare"}',
    N'{"target_department":"Cardiology"}',
    N'{"room":"ER-12","employeeid":"E778"}',
    N'{"expected_wait_minutes":15}',
    N'{"shift":"day","department":"ER"}',
    N'{"intended_disposition":"admit"}',
    GETDATE(),
    1,
    N'Emergency Room Visit',
    441
);
```

Then additional events for the same case should reuse the same staged `CaseID`:

```sql
INSERT INTO STAGE.ImportEvents
(
    SourceID, CaseID, Event, EventDescription, EventDate,
    CaseProperties, CaseTargetProperties,
    EventActualProperties, EventExpectedProperties, EventAggregationProperties, EventIntendedProperties,
    DateAdded, AccessBitmap, CaseType, NaturalKey_SourceColumnID
)
VALUES
(
    12,
    N'ERVISIT-100045',
    N'mri_started',
    N'MRI procedure begins',
    N'2026-04-17T10:02:00',
    NULL,
    NULL,
    N'{"machine":"MRI-3","employeeid":"E991"}',
    NULL,
    N'{"department":"Radiology"}',
    NULL,
    GETDATE(),
    1,
    N'Emergency Room Visit',
    441
);
```

## 7. Run the import

The attached procedure supports two patterns:

```sql
EXEC dbo.ImportEventsFromStage;

EXEC dbo.ImportEventsFromStage
    @ImportFromDate = '2026-01-01';
```

If `@ImportFromDate` is null, it uses the current max `EventDate` in `dbo.EventsFact` as the watermark. Only stage rows with `DateAdded > @ImportFromDate` are imported.  

## 8. What happens during import

The procedure does this, in order:

1. Validates stage rows for bad event length, invalid JSON in `CaseProperties`, invalid case type name, and invalid source ID. If any invalid row exists, it logs failure and returns. 
2. Inserts new event types into `dbo.DimEvents`. 
3. Creates a new `BatchID` based on `MAX(BatchID)+1` from `dbo.EventsFact`. 
4. Builds a case map from staged natural `CaseID` to new numeric internal `CaseID`. 
5. Inserts `dbo.Cases`. 
6. Inserts `dbo.CaseProperties`. 
7. Inserts `dbo.EventsFact` with recalculated `CaseOrdinal`. 
8. Inserts `dbo.EventProperties`. 
9. Calls `dbo.UpdateCaseFromEvents`, `dbo.InsertCaseProperties @CompleteRefresh=1`, and `dbo.InsertEventProperties @CompleteRefresh=1`. 

## 9. Logging and monitoring

The procedure calls `dbo.utility_LogProcError` multiple times with messages like:

* `Validation Failed`
* `Event Types`
* `Cases`
* `CaseProperty rows`
* `Event rows`

So yes, progress is logged, but based on what I could verify from your uploaded files, the persisted table I could confirm is **`dbo.ProcErrorLog`**, not `ProcLogEvents`. I would phrase the tutorial accordingly unless you know there is another newer logging table not present in this schema.  

A reasonable check after import is:

```sql
SELECT TOP 100 *
FROM dbo.ProcErrorLog
ORDER BY LoggedAt DESC;
```

And to inspect what was loaded most recently:

```sql
SELECT TOP 100 *
FROM dbo.EventsFact
ORDER BY EventID DESC;
```

## 10. Pre-import validation queries

These are worth running before `EXEC dbo.ImportEventsFromStage`:

Check bad source IDs:

```sql
SELECT DISTINCT i.SourceID
FROM STAGE.ImportEvents i
LEFT JOIN dbo.Sources s
    ON s.SourceID = i.SourceID
WHERE s.SourceID IS NULL;
```

Check bad case types:

```sql
SELECT DISTINCT i.CaseType
FROM STAGE.ImportEvents i
LEFT JOIN dbo.CaseTypes ct
    ON ct.Name = i.CaseType
WHERE i.CaseType IS NOT NULL
  AND ct.CaseTypeID IS NULL;
```

Check invalid case JSON:

```sql
SELECT *
FROM STAGE.ImportEvents
WHERE CaseProperties IS NOT NULL
  AND ISJSON(CaseProperties) = 0;
```

Check overlong event names:

```sql
SELECT *
FROM STAGE.ImportEvents
WHERE LEN(Event) > 50;
```

## 11. Recommendations on property design

A few practical rules will make this work better downstream:

* Keep event names short and stable.
* Put business identity and tuple-defining descriptors in `CaseProperties`.
* Put observed event facts in `EventActualProperties`.
* Use exact `CaseType` names from `dbo.CaseTypes`.
* Reuse property names consistently across sources where they mean the same thing.
* Align JSON property names to `SourceColumns.ColumnName` where possible.
* Use `NaturalKey_SourceColumnID` when you know which source column produced the staged `CaseID`, even though the current import procedure does not yet consume it.  

## 12. Sample app to generate flight events at scale

See https://github.com/MapRock/TimeMolecules/blob/main/tutorials/importing_events/generate_hnl_hilo_flight_events.py

