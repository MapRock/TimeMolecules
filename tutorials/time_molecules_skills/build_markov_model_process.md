
# Classic Procedure for Creating a Markov Model

This is the classic step-by-step procedure for building a Markov Model in Time Molecules using an ER Lab workflow example (`CaseTypeID = 15`).

It is intended to show AI agents a common pattern.

## Step 1: Choose the Case Type

Let's pick `CaseTypeID = 15` (ER Lab workflow).

```sql
SELECT TOP (1000)
    [CaseTypeID],
    [Description],
    [ParentCaseTypeID],
    [Name],
    [IRI],
    [AccessBitmap]
FROM [TimeSolution].[dbo].[CaseTypes];
```

```sql
DECLARE @CaseTypeID INT = 15;
```

## Step 2: Review Events Related to This Case Type

```sql
SELECT TOP (1000)
    [CaseTypeID],
    [CaseTypeName],
    [CaseTypeDescription],
    [CaseTypeIRI],
    [Event],
    [EventDescription],
    [Occurrences]
FROM [TimeSolution].[dbo].[vwCaseTypeEventCounts]
WHERE CaseTypeID = @CaseTypeID;
```

## Step 3: Create a New EventSet (idempotent)

```sql
DECLARE @EventSet NVARCHAR(1000) = (
    SELECT STRING_AGG([Event], ',')
    FROM [dbo].[vwCaseTypeEventCounts]
    WHERE CaseTypeID = @CaseTypeID
);

PRINT CONCAT('EventSet: ', @EventSet);   -- BLOOD_DRAWN,LAB_ORDERED,LAB_POSTED

DECLARE @EventSetKey VARBINARY(16);
DECLARE @EventSetCode NVARCHAR(50) = 'ERLAB';

-- This is idempotent, so you can run it repeatedly with no side effects.
EXEC dbo.InsertEventSets
    @EventSet = @EventSet,
    @EventSetCode = @EventSetCode,
    @EventSetKey = @EventSetKey OUTPUT,
    @IsSequence = 0;   -- A set of events, order doesn't matter.

PRINT CONCAT('EventSetKey ', CONVERT(varchar(32), @EventSetKey, 2));
```

## Step 4: Load Events into the Work Area

```sql
DECLARE @SessionID UNIQUEIDENTIFIER = NEWID();

EXEC dbo.sp_SelectedEvents
    @EventSet = @EventSet,
    @SessionID = @SessionID;

SELECT * FROM WORK.SelectedEvents WHERE SessionID = @SessionID;
```

## Step 5: Build the Basic Markov Model

```sql
DECLARE @ModelID INT = NULL;
DECLARE @DistinctCases INT = NULL;

EXEC dbo.MarkovProcess2
    @EventSet = @EventSet,
    @enumerate_multiple_events = 0,
    @StartDateTime = '2025-01-01',
    @EndDateTime = '2026-12-31',
    @Transforms = NULL,          -- No transforms yet
    @DistinctCases = @DistinctCases OUTPUT,
    @ModelID = @ModelID OUTPUT;

PRINT CONCAT('ModelID: ', CAST(@ModelID AS VARCHAR(10)),
             ' Distinct Cases: ', CAST(@DistinctCases AS VARCHAR(10)));
```

## Step 6: Examine Event Properties (before adding transforms)

```sql
SELECT 
    EventID,
    PropertyName,
    PropertyValueAlpha,
    PropertyValueNumeric,
    SourceName
FROM vwEventPropertiesParsed
WHERE EventID IN (SELECT EventID FROM WORK.SelectedEvents WHERE SessionID = @SessionID)
ORDER BY PropertyName;
```

## Step 7: Add Event Transforms (Glucose example)

```sql
DECLARE @SplitEventTransforms NVARCHAR(1000) = '{
    "MD_EVAL_START":"BEGIN_EVAL",
    "LAB_POSTED":{"toEvent":"HIGH_GLUS","op":"GT","Value1":"Glucose","Value2":110},
    "LAB_POSTED":{"toEvent":"LOW_GLUC","op":"LT","Value1":"Glucose","Value2":60},
    "LAB_POSTED":{"toEvent":"NORMAL_GLUC","op":"BETWEEN","Value1":"Glucose","Value2":60,"Value3":110}
}';

-- View the transformed events
EXEC dbo.sp_SelectedEvents
    @EventSet = @EventSet,
    @Transforms = @SplitEventTransforms;

-- Build a new model with the transforms applied
EXEC dbo.MarkovProcess2
    @EventSet = @EventSet,
    @enumerate_multiple_events = 0,
    @StartDateTime = '2025-01-01',
    @EndDateTime = '2026-12-31',
    @Transforms = @SplitEventTransforms,
    @DistinctCases = @DistinctCases OUTPUT,
    @ModelID = @ModelID OUTPUT;

PRINT CONCAT('ModelID: ', CAST(@ModelID AS VARCHAR(10)),
             ' Distinct Cases: ', CAST(@DistinctCases AS VARCHAR(10)));
```

## Step 8: Filter Cases by Property (Sodium ≥ 138)

```sql
DECLARE @Session_Na UNIQUEIDENTIFIER = NEWID();
DECLARE @EventFilterProperties NVARCHAR(1000) = '{"Sodium":{"start":138,"end":200}}';

EXEC dbo.sp_SelectedEvents
    @EventSet = @EventSet,
    @Transforms = @SplitEventTransforms,
    @EventFilterProperties = @EventFilterProperties,
    @SessionID = @Session_Na;

SELECT * FROM WORK.SelectedEvents WHERE SessionID = @Session_Na;

-- Remove cases that do NOT meet the Sodium filter
DELETE FROM WORK.SelectedEvents
WHERE SessionID = @SessionID
  AND CaseID NOT IN (SELECT CaseID FROM WORK.SelectedEvents WHERE SessionID = @Session_Na);

SELECT * FROM WORK.SelectedEvents WHERE SessionID = @SessionID;

SET @ModelID = NULL;

EXEC dbo.MarkovProcess2
    @EventSet = @EventSet,
    @StartDateTime = '2025-01-01',
    @EndDateTime = '2026-12-31',
    @ModelID = @ModelID OUTPUT,
    @SessionID = @SessionID;

SELECT * FROM WORK.MarkovProcess WHERE SessionID = @SessionID;

PRINT CONCAT('ModelID: ', CAST(@ModelID AS VARCHAR(10)),
             ' Distinct Cases: ', CAST(@DistinctCases AS VARCHAR(10)));
```

## Cleanup

```sql
DELETE FROM WORK.SelectedEvents WHERE SessionID = @SessionID;
DELETE FROM WORK.SelectedEvents WHERE SessionID = @Session_Na;
DELETE FROM WORK.MarkovProcess WHERE SessionID = @SessionID;
```

