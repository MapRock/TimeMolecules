
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

Here is the SQL in one piece:

```sql
/*
Classic procedure for creating a Markov Model.
*/

/*
Step 1. What kind of case are we interested in?

Let's pick CaseTypes.CaseTypeID=15, ER Lab workflow.
*/
SELECT TOP (1000) 
	[CaseTypeID]
	,[Description]
	,[ParentCaseTypeID]
	,[Name]
	,[IRI]
	,[AccessBitmap]
  FROM [TimeSolution].[dbo].[CaseTypes]
DECLARE @CaseTypeID INT=15
 /*
 Step 2: Look at what events are related to CaseTypeID=15
 */
 SELECT TOP (1000) [CaseTypeID]
      ,[CaseTypeName]
      ,[CaseTypeDescription]
      ,[CaseTypeIRI]
      ,[Event]
      ,[EventDescription]
      ,[Occurrences]
  FROM [TimeSolution].[dbo].[vwCaseTypeEventCounts]
  WHERE
	CaseTypeID=@CaseTypeID

/*
Step 3: We'll create a new EventSet. If it already exists, InsertEventSets is idempotent, nothing with happen.
*/
DECLARE @EventSet NVARCHAR(1000)=(SELECT STRING_AGG([Event],',') FROM [dbo].[vwCaseTypeEventCounts] WHERE CaseTypeID=@CaseTypeID)
PRINT CONCAT('EventSet: ',@EventSet) ----BLOOD_DRAWN,LAB_ORDERED,LAB_POSTED
DECLARE @EventSetKey VARBINARY(16)
DECLARE @EventSetCode NVARCHAR(50)='ERLAB'
--This is idempotent, so don't worry about running repeatedly.
EXEC dbo.InsertEventSets 
        @EventSet = @EventSet,
        @EventSetCode = @EventSetCode,
        @EventSetKey = @EventSetKey OUTPUT,
        @IsSequence = 0;	--A set of events, order doesn't matter.
PRINT CONCAT('EventSetKey ',CONVERT(varchar(32), @EventSetKey, 2)) --F31A9B3FFCFD2C1B56635718E6F1DCCB

/*
Step 4: Check for events with that event set of . 12 events from 4 cases, 2026-03-27 through 2026-03-29.
*/

DECLARE @SessionID UNIQUEIDENTIFIER=NEWID() --SessionID of the WORK.SelectedEvents work area.
EXEC dbo.sp_SelectedEvents @EventSet=@EventSet,@SessionID=@SessionID
SELECT * FROM WORK.SelectedEvents WHERE SessionID=@SessionID

DECLARE @ModelID INT=NULL
DECLARE @DistinctCases INT=NULL

/*
Step 5: Create a Markov Model from the events in @SessionID.
There are two segments made up of three event types (BLOOD_DRAWN,LAB_ORDERED,LAB_POSTED)
*/
EXEC dbo.MarkovProcess2 
    @EventSet=@EventSet,
    @enumerate_multiple_events=0,
    @StartDateTime='2025-01-01',
    @EndDateTime='2026-12-31',
	@Transforms=NULL,	--No transforms.
    @DistinctCases=@DistinctCases OUTPUT,
    @ModelID=@ModelID OUTPUT;
PRINT CONCAT('ModelID: ',CAST(@ModelID AS VARCHAR(10)),' Distinct Cases: '+CAST(@DistinctCases AS VARCHAR(10)))

/*
At this point we created a Markov model. But let's get a little fancier, beginning with an Event transform.

Step 6: Examine the properties of the events for anything we'd like to alter.

Examine Event-level properties. Notice the properties: Glucose and Sodium. We'll work with Sodium later.
*/

SELECT EventID,PropertyName,PropertyValueAlpha,PropertyValueNumeric,SourceName
FROM vwEventPropertiesParsed
WHERE eventID IN (SELECT EventID FROM WORK.SelectedEvents WHERE SessionID=@SessionID)
ORDER BY PropertyName

/*
This example splits an event into other events based on simple logic.
The LAB_POSTED event has a Glucose property. If the Glucose for the LAB is high, low, or normal,
we'll transform the "LAB_POSTED" to an event that says more than "LAB_POSTED".
*/
DECLARE @SplitEventTransforms NVARCHAR(1000)='{
		"MD_EVAL_START":"BEGIN_EVAL",
        "LAB_POSTED":{"toEvent":"HIGH_GLUS","op":"GT","Value1":"Glucose","Value2":110},
        "LAB_POSTED":{"toEvent":"LOW_GLUC","op":"LT","Value1":"Glucose","Value2":60},
        "LAB_POSTED":{"toEvent":"NORMAL_GLUC","op":"BETWEEN","Value1":"Glucose","Value2":60,"Value3":110}
    }'

--View the events with those transforms.
EXEC dbo.sp_SelectedEvents @EventSet=@EventSet,@Transforms=@SplitEventTransforms

--Three segments made from four event types.
EXEC dbo.MarkovProcess2 
    @EventSet=@EventSet,
    @enumerate_multiple_events=0,
    @StartDateTime='2025-01-01',
    @EndDateTime='2026-12-31',
	@Transforms=@SplitEventTransforms,
    @DistinctCases=@DistinctCases OUTPUT,
    @ModelID=@ModelID OUTPUT;
PRINT CONCAT('ModelID: ',CAST(@ModelID AS VARCHAR(10)),' Distinct Cases: '+CAST(@DistinctCases AS VARCHAR(10)))

/*
Now, let's filter out Sodium levels GTE 138.
We see there are two events with the property of Sodium GTE than 138.

However, we really want cases where there is an event (LAB_POSTED) where Sodium in GTE 138, not just the events.
We still have the full event set from before under SessionID=@SessionID. What we ultimately want is to filter
out cases where Sodium is NOT 138 though 200.
This call to sp_Selected events filtered the events. There will be an event from two cases, meeting that filter.
We'll create another SessionID named @Session_Na for this filtered set.
*/
DECLARE @Session_Na UNIQUEIDENTIFIER=NEWID() --SessionID for sodium filter.
DECLARE @EventFilterProperties NVARCHAR(1000)='{"Sodium":{"start":138,"end":200}}'
EXEC dbo.sp_SelectedEvents 
	@EventSet=@EventSet,
	@Transforms=@SplitEventTransforms,
	@EventFilterProperties=@EventFilterProperties,
	@SessionID=@Session_Na 
SELECT * FROM WORK.SelectedEvents WHERE SessionID=@Session_Na

--Now, we'll filter out from the original @SessionID and cases not in @Session_Na.
DELETE FROM WORK.SelectedEvents 
WHERE
	SessionID=@SessionID AND
	CaseID NOT IN (SELECT e.CaseID FROM WORK.SelectedEvents e WHERE e.SessionID=@Session_Na)
SELECT * FROM WORK.SelectedEvents WHERE SessionID=@SessionID

SET @ModelID=NULL	
EXEC dbo.MarkovProcess2 
    @EventSet=@EventSet,
    @StartDateTime='2025-01-01',
    @EndDateTime='2026-12-31',
    @ModelID=@ModelID OUTPUT,
	@SessionID=@SessionID
SELECT * FROM WORK.MarkovProcess WHERE SessionID=@SessionID
PRINT CONCAT('ModelID: ',CAST(@ModelID AS VARCHAR(10)),' Distinct Cases: '+CAST(@DistinctCases AS VARCHAR(10)))

--Clean up the WORK tables.
DELETE FROM WORK.SelectedEvents WHERE SessionID=@SessionID
DELETE FROM WORK.SelectedEvents WHERE SessionID=@Session_Na
DELETE FROM WORK.MarkovProcess WHERE SessionID=@SessionID

```
