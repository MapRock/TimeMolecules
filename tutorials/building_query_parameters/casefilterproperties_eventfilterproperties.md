

# How to Construct `CaseFilterProperties` and `EventFilterProperties` JSON in TimeSolution

This tutorial explains how to build `CaseFilterProperties` and `EventFilterProperties` JSON correctly in TimeSolution.

These filters are used in many TimeSolution procedures and functions to limit the events or cases being analyzed. They are simple in concept, but there is one place people often get tripped up: you need to use the **right property name** and the **right value type**. Some properties are stored as text, others as numeric values. If you guess wrong, you may get no rows back or misleading results.

This tutorial is based on the TimeSolution database script and the general tutorial style used in the Time Molecules repository.

## What these JSON filters are for

`CaseFilterProperties` filters at the **case** level.

`EventFilterProperties` filters at the **event** level.

In plain terms:

* use `CaseFilterProperties` when you want only cases that have certain case properties
* use `EventFilterProperties` when you want only events that have certain event properties

These are usually passed as JSON objects such as:

```json
{"EmployeeID":1,"LocationID":1}
```

or

```json
{"PatientSex":"F"}
```

The key is the property name. The value must match the stored type.

## Where to find valid property names

Do not guess property names if you can avoid it.

The safest places to look are:

* `vwCasePropertiesParsed`
* `vwEventPropertiesParsed`

These views are especially useful because they show parsed properties in a form that is easier to inspect than raw property blobs.

A typical workflow is:

1. search the parsed-property view for a likely property
2. confirm the exact `PropertyName`
3. look at whether values appear in `PropertyValueAlpha` or `PropertyValueNumeric`
4. build the JSON with the correct type

## Why type matters

TimeSolution parsed-property tables separate values into two columns:

* `PropertyValueAlpha`
* `PropertyValueNumeric`

That means a property is usually represented one way or the other for a given row.

Examples:

* `EmployeeID` is likely numeric
* `PatientSex` is likely alpha
* `LocationID` is likely numeric
* `OrderID` might be alpha or numeric depending on the source
* `TournamentNumber` might look numeric, but you should still verify

If a property is stored in `PropertyValueNumeric`, your JSON should use an unquoted number:

```json
{"EmployeeID":1}
```

If a property is stored in `PropertyValueAlpha`, your JSON should use a quoted string:

```json
{"PatientSex":"F"}
```

That distinction is important.

## Step 1: inspect case properties

Start by looking at case-level properties.

Example:

```sql
SELECT TOP (100)
    CaseID,
    PropertyName,
    PropertyValueAlpha,
    PropertyValueNumeric
FROM dbo.vwCasePropertiesParsed
ORDER BY PropertyName, CaseID;
```

If you are looking for a specific property:

```sql
SELECT TOP (100)
    CaseID,
    PropertyName,
    PropertyValueAlpha,
    PropertyValueNumeric
FROM dbo.vwCasePropertiesParsed
WHERE PropertyName = 'EmployeeID';
```

What you are checking:

* is the property name really `EmployeeID` and not `employeeid` or something else
* are the values appearing in `PropertyValueNumeric`
* are there nulls in one column and real values in the other

If you see values like this:

| PropertyName | PropertyValueAlpha | PropertyValueNumeric |
| ------------ | -----------------: | -------------------: |
| EmployeeID   |               NULL |                    1 |
| EmployeeID   |               NULL |                    2 |

then build the filter as numeric JSON:

```json
{"EmployeeID":1}
```

If instead you see:

| PropertyName | PropertyValueAlpha | PropertyValueNumeric |
| ------------ | ------------------ | -------------------: |
| PatientSex   | F                  |                 NULL |
| PatientSex   | M                  |                 NULL |

then build the filter as alpha JSON:

```json
{"PatientSex":"F"}
```

## Step 2: inspect event properties

Do the same for event-level properties.

Example:

```sql
SELECT TOP (100)
    EventID,
    PropertyName,
    PropertyValueAlpha,
    PropertyValueNumeric
FROM dbo.vwEventPropertiesParsed
ORDER BY PropertyName, EventID;
```

If you are targeting a specific property:

```sql
SELECT TOP (100)
    EventID,
    PropertyName,
    PropertyValueAlpha,
    PropertyValueNumeric
FROM dbo.vwEventPropertiesParsed
WHERE PropertyName = 'Fuel';
```

If `Fuel` appears in `PropertyValueNumeric`, then use:

```json
{"Fuel":12.5}
```

If something like `RoundStatus` appears in `PropertyValueAlpha`, then use:

```json
{"RoundStatus":"final"}
```

## Step 3: construct the JSON object

Once you know the property names and types, construct the JSON object carefully.

### Numeric example

```json
{"EmployeeID":1,"LocationID":3}
```

### Alpha example

```json
{"PatientSex":"F","State":"HI"}
```

### Mixed example

```json
{"EmployeeID":1,"PatientSex":"F"}
```

Mixed JSON is fine as long as each value uses the correct type.

## Step 4: pass the JSON into TimeSolution objects

These filters are passed into procedures and functions that accept `@CaseFilterProperties` and `@EventFilterProperties`.

A typical pattern looks like this:

```sql
DECLARE @CaseFilterProperties NVARCHAR(MAX) =
    N'{"EmployeeID":1,"LocationID":1}';

DECLARE @EventFilterProperties NVARCHAR(MAX) =
    N'{"Fuel":12.5}';
```

and then:

```sql
SELECT *
FROM dbo.SelectedEvents(
    'restaurantguest',
    0,
    '1900-01-01',
    '2050-12-31',
    NULL,
    1,
    NULL,
    @CaseFilterProperties,
    @EventFilterProperties
);
```

The exact object may vary, but the usage pattern is the same: build JSON as text and pass it into the parameter.

## Common mistakes

### 1. Using the wrong property name

This is the simplest mistake.

Wrong:

```json
{"employee_id":1}
```

when the actual property name is:

```json
{"EmployeeID":1}
```

Always inspect the parsed-property views first.

### 2. Quoting a numeric value

Wrong:

```json
{"EmployeeID":"1"}
```

if `EmployeeID` is stored in `PropertyValueNumeric`.

Use:

```json
{"EmployeeID":1}
```

instead.

### 3. Leaving text unquoted

Wrong:

```json
{"PatientSex":F}
```

Use:

```json
{"PatientSex":"F"}
```

instead.

### 4. Filtering on the wrong level

If the property is case-level, putting it into `EventFilterProperties` may not work the way you expect.

If the property is event-level, putting it into `CaseFilterProperties` may also be wrong.

When in doubt:

* inspect `vwCasePropertiesParsed`
* inspect `vwEventPropertiesParsed`

and see where the property actually lives.

### 5. Assuming a property is numeric because it looks numeric

Some identifiers look numeric but are stored as text. Check first.

For example, an `OrderID` might be stored as alpha even if it contains only digits.

## A practical discovery pattern

Here is a good step-by-step pattern for a human user or AI agent.

### Find likely case properties

```sql
SELECT TOP (100)
    PropertyName,
    COUNT(*) AS RowsFound,
    SUM(CASE WHEN PropertyValueAlpha IS NOT NULL THEN 1 ELSE 0 END) AS AlphaRows,
    SUM(CASE WHEN PropertyValueNumeric IS NOT NULL THEN 1 ELSE 0 END) AS NumericRows
FROM dbo.vwCasePropertiesParsed
GROUP BY PropertyName
ORDER BY PropertyName;
```

### Find likely event properties

```sql
SELECT TOP (100)
    PropertyName,
    COUNT(*) AS RowsFound,
    SUM(CASE WHEN PropertyValueAlpha IS NOT NULL THEN 1 ELSE 0 END) AS AlphaRows,
    SUM(CASE WHEN PropertyValueNumeric IS NOT NULL THEN 1 ELSE 0 END) AS NumericRows
FROM dbo.vwEventPropertiesParsed
GROUP BY PropertyName
ORDER BY PropertyName;
```

This gives you a quick profile of which properties exist and how they are usually stored.

## Examples

### Example 1: filter restaurant cases to one employee

First inspect:

```sql
SELECT TOP (20)
    PropertyName,
    PropertyValueAlpha,
    PropertyValueNumeric
FROM dbo.vwCasePropertiesParsed
WHERE PropertyName = 'EmployeeID';
```

Suppose values are numeric.

Then:

```sql
DECLARE @CaseFilterProperties NVARCHAR(MAX) = N'{"EmployeeID":1}';
```

### Example 2: filter emergency-room cases by patient sex

First inspect:

```sql
SELECT TOP (20)
    PropertyName,
    PropertyValueAlpha,
    PropertyValueNumeric
FROM dbo.vwCasePropertiesParsed
WHERE PropertyName = 'PatientSex';
```

Suppose values are alpha.

Then:

```sql
DECLARE @CaseFilterProperties NVARCHAR(MAX) = N'{"PatientSex":"F"}';
```

### Example 3: filter poker events by number of players

First inspect:

```sql
SELECT TOP (20)
    PropertyName,
    PropertyValueAlpha,
    PropertyValueNumeric
FROM dbo.vwEventPropertiesParsed
WHERE PropertyName = 'Players';
```

If values are numeric:

```sql
DECLARE @EventFilterProperties NVARCHAR(MAX) = N'{"Players":6}';
```

### Example 4: mixed case filter

```sql
DECLARE @CaseFilterProperties NVARCHAR(MAX) =
    N'{"EmployeeID":1,"LocationID":1}';
```

This is a common pattern in TimeSolution examples.

## Guidance for AI agents

If an AI agent is asked to build `CaseFilterProperties` or `EventFilterProperties`, it should not jump straight to JSON.

A better sequence is:

1. identify whether the requested property sounds like a case property or event property
2. inspect `vwCasePropertiesParsed` or `vwEventPropertiesParsed`
3. confirm the exact `PropertyName`
4. detect whether values are alpha or numeric
5. build the JSON with the correct type
6. pass the JSON into the requested procedure or function

That is a more reliable method than guessing.

## Final advice

`CaseFilterProperties` and `EventFilterProperties` are simple once you treat them as a typed key-value filter built from real parsed properties.

The safe rule is:

* property names come from the parsed-property views
* numeric properties use numeric JSON values
* alpha properties use quoted JSON strings
* never assume the type without checking

That extra inspection step prevents a lot of wasted time.

## Source material

This tutorial is based on:

* the attached TimeSolution database script
* the structures and examples in the TimeSolution DDL
* the Time Molecules repository
* the tutorial style used in examples such as `tutorials/link_cases`

If you want, I can also turn this into a repository-style `readme.md` with a short opening summary and tighter formatting for GitHub.
