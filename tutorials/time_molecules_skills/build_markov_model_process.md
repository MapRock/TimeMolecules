
# Creating a Markov Model – Classic Skill Pattern

This procedure demonstrates the classic, repeatable pattern for building a Markov Model in Time Molecules.  
It is written as a reusable **skill** that both human analysts and AI agents can follow step-by-step.  
The example uses the ER Lab workflow (`CaseTypeID = 15`).


## Step 1: Choose the Case Type

Decide which kind of case (process) you want to model. Here we are interested in the ER Lab workflow.

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
| CaseTypeID | Description                                                                                                                                                                                                                                 | ParentCaseTypeID | Name            | IRI  | AccessBitmap |
| ---------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------: | --------------- | ---- | -----------: |
|          1 | Restaurant meal service process: Captures the full customer journey in a typical sit-down restaurant, including ordering, seating, food preparation, service interactions, payments, complaints, and tipping events.                        |             NULL | Meal            | NULL |            7 |
|          2 | Delivery or pickup vehicle route tracking: Represents logistics and transportation events for package delivery, garbage collection, or similar pickup/delivery operations along defined routes.                                             |             NULL | Truck Trip      | NULL |            7 |
|          3 | Daily commute to work: Tracks individual or aggregated commuting patterns, routes, times, modes of transportation, and related events from home to workplace and return.                                                                    |             NULL | Commute to Work | NULL |            7 |
|          4 | Poker game and tournament events: Records real-time or historical data from poker sessions including player count, seating, dealer button position, tournament numbers, and gameplay actions.                                               |             NULL | PokerGame       | NULL |            7 |
|          6 | Daily sales performance tracking for liquor retail: Iowa state liquor store sales data including store-level transactions, product movement, revenue, and sales metrics over time.                                                          |             NULL | DailySalesPerf  | NULL |            7 |
|          7 | Internet sale / e-commerce transaction: Captures online purchase events, order processing, customer interactions, and fulfillment activities from web-based retail platforms.                                                               |             NULL | Internet Sale   | NULL |            7 |
|          8 | Daily stock market performance data: End-of-day quotes, pricing, volume, and trading metrics for publicly traded stocks and securities.                                                                                                     |             NULL | Stock Day2Day   | NULL |            7 |
|          9 | General e-commerce site events: Broad category for online retail platform activities including browsing, cart additions, purchases, and customer behavior on digital storefronts.                                                           |             NULL | e-commerce site | NULL |            7 |
|         10 | Medical and clinical patient events: Encompasses healthcare-related records from hospitals and clinics, including demographics, diagnoses, procedures, and clinical workflows.                                                              |             NULL | Medical         | NULL |            7 |
|         11 | Parsed photo / computer vision object detection events: Images processed by object detection models where each recognized object becomes an individual event with associated metadata, all linked to the original photo as the parent case. |             NULL | Parsed Photo    | NULL |            7 |
|         12 | Unknown or unclassified case type: Placeholder for events or cases that have not been mapped to a specific known business process or domain.                                                                                                |             NULL | Unknown         | NULL |            7 |
|         14 | Emergency Room patient encounters: Core emergency department visits including registration, triage, chief complaints, arrival mode, patient demographics, and initial assessment in a hospital setting.                                     |               10 | ER              | NULL |            7 |
|         15 | Emergency Room Laboratory workflow: Lab test orders, processing, panels, and results originating from or associated with an Emergency Room visit.                                                                                           |               14 | ER-Lab          | NULL |            7 |
|         16 | Emergency Room MRI / Radiology workflow: MRI imaging orders, studies, and radiology procedures initiated during or linked to an Emergency Room patient encounter.                                                                           |               14 | ER-MRI          | NULL |            7 |
|         17 | Emergency Room Case Management: Coordination, tracking, and management activities for patients within the Emergency Department, including follow-up, disposition, and resource allocation.                                                  |               14 | ER-CaseMgt      | NULL |            7 |
Let's select CaseTypeID=15:
```sql
DECLARE @CaseTypeID INT = 15;
```

## Step 2: Review Events Related to This Case Type

See exactly which events belong to the chosen case type and how often they occur. This helps you understand the raw material you will be modeling.

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
| CaseTypeID | CaseTypeName | CaseTypeDescription                                                                                                                               | CaseTypeIRI | Event       | EventDescription | Occurrences |
| ---------: | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- | ----------- | ---------------- | ----------: |
|         15 | ER-Lab       | Emergency Room Laboratory workflow: Lab test orders, processing, panels, and results originating from or associated with an Emergency Room visit. | NULL        | LAB_POSTED  | NULL             |          10 |
|         15 | ER-Lab       | Emergency Room Laboratory workflow: Lab test orders, processing, panels, and results originating from or associated with an Emergency Room visit. | NULL        | LAB_ORDERED | NULL             |          10 |
|         15 | ER-Lab       | Emergency Room Laboratory workflow: Lab test orders, processing, panels, and results originating from or associated with an Emergency Room visit. | NULL        | BLOOD_DRAWN | NULL             |          10 |


## Step 3: Create a New EventSet (idempotent)

Build a comma-separated list of the events that define this case type and register it as an official EventSet.  
`InsertEventSets` is idempotent, so you can run this step safely as many times as you like.

```sql
DECLARE @EventSet NVARCHAR(1000) = (
    SELECT STRING_AGG([Event], ',')
    FROM [dbo].[vwCaseTypeEventCounts]
    WHERE CaseTypeID = @CaseTypeID
);

PRINT CONCAT('EventSet: ', @EventSet);   -- BLOOD_DRAWN,LAB_ORDERED,LAB_POSTED

DECLARE @EventSetKey VARBINARY(16);
DECLARE @EventSetCode NVARCHAR(50) = 'ERLAB';

EXEC dbo.InsertEventSets
    @EventSet = @EventSet,
    @EventSetCode = @EventSetCode,
    @EventSetKey = @EventSetKey OUTPUT,
    @IsSequence = 0;   -- A set of events; order does not matter yet.

PRINT CONCAT('EventSetKey ', CONVERT(varchar(32), @EventSetKey, 2));
```

## Step 4: Load Events into the Work Area

Pull the actual event instances that match the EventSet into a temporary work table so we can manipulate and analyze them.

```sql
DECLARE @SessionID UNIQUEIDENTIFIER = NEWID();   -- Unique work session ID

EXEC dbo.sp_SelectedEvents
    @EventSet = @EventSet,
    @SessionID = @SessionID;

SELECT * FROM WORK.SelectedEvents WHERE SessionID = @SessionID;
```

## Step 5: Compute the Basic Markov Model

Create the first Markov model from the raw events. This gives you the baseline transition probabilities with no modifications.

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

Look at the properties attached to the events. This is your chance to discover useful attributes (Glucose, Sodium, etc.) that you might want to use for filtering or splitting events later.

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

## Step 7: Create an Event Transform (Glucose example)

Define rules that split or rename events based on their properties. Here we turn a plain `LAB_POSTED` event into more meaningful events (`HIGH_GLUS`, `LOW_GLUC`, `NORMAL_GLUC`) depending on the Glucose value.

```sql
DECLARE @SplitEventTransforms NVARCHAR(1000) = '{
    "MD_EVAL_START":"BEGIN_EVAL",
    "LAB_POSTED":{"toEvent":"HIGH_GLUS","op":"GT","Value1":"Glucose","Value2":110},
    "LAB_POSTED":{"toEvent":"LOW_GLUC","op":"LT","Value1":"Glucose","Value2":60},
    "LAB_POSTED":{"toEvent":"NORMAL_GLUC","op":"BETWEEN","Value1":"Glucose","Value2":60,"Value3":110}
}';
DECLARE @EventSet NVARCHAR(100)='ERLAB'

-- Preview what the transformed events look like
EXEC dbo.sp_SelectedEvents
    @EventSet = @EventSet,
    @Transforms = @SplitEventTransforms;
```

## Step 8: Compute a Markov Model with the Transforms Applied

Re-run the model using the transformed events. You should now see more segments because the single `LAB_POSTED` event has been split into three distinct states.

```sql
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

## Step 9: Filter Cases by Property (Sodium ≥ 138)

Apply a property filter to keep only cases that contain at least one event meeting the Sodium condition. We use a second session so we can safely compare and filter.

```sql
DECLARE @Session_Na UNIQUEIDENTIFIER = NEWID();

DECLARE @EventFilterProperties NVARCHAR(1000) = '{"Sodium":{"start":138,"end":200}}';

EXEC dbo.sp_SelectedEvents
    @EventSet = @EventSet,
    @Transforms = @SplitEventTransforms,
    @EventFilterProperties = @EventFilterProperties,
    @SessionID = @Session_Na;

SELECT * FROM WORK.SelectedEvents WHERE SessionID = @Session_Na;
```

## Step 10: Remove Cases That Do Not Meet the Filter

Keep only the cases that passed the Sodium filter by deleting the others from the original work session.

```sql
DELETE FROM WORK.SelectedEvents
WHERE SessionID = @SessionID
  AND CaseID NOT IN (SELECT CaseID FROM WORK.SelectedEvents WHERE SessionID = @Session_Na);

SELECT * FROM WORK.SelectedEvents WHERE SessionID = @SessionID;
```

## Step 11: Compute the Final Filtered Markov Model

Build the final Markov model using the filtered event set. Because rows already exist in `WORK.SelectedEvents`, `MarkovProcess2` will use them directly.

```sql
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


# Complete SQL
Here is the SQL in one piece you can run in SSMS or otherwise.

```sql
/*
Classic procedure for computinga Markov Model.

Note that this script uses MarkovProcess2, which computes a Markov model, but does not 
persist it. To create and save, use CreateUpdateMarkovProcess. MarkovProcess2 uses sp_SelectedEvents and in turn, CreateUpdateMarkovProcess
using MarkovProcess2.

The separation is to enable flexibility at each level.
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
Step 5: Compute a Markov Model from the events in @SessionID.
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
At this point we computed a Markov model. But let's get a little fancier, beginning with an Event transform.

Step 6: Examine the properties of the events for anything we'd like to alter.

Examine Event-level properties. Notice the properties: Glucose and Sodium. We'll work with Sodium later.
*/

SELECT EventID,PropertyName,PropertyValueAlpha,PropertyValueNumeric,SourceName
FROM vwEventPropertiesParsed
WHERE eventID IN (SELECT EventID FROM WORK.SelectedEvents WHERE SessionID=@SessionID)
ORDER BY PropertyName

/*
Step 7: Create a transform of events.
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

/*
Step 8: Compute a Markov model reflecting the transformed events.
Three segments made from four event types.
*/
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
Step 9: Now, let's filter out Sodium levels GTE 138.
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

/*
Step 10: Filter out from the original @SessionID and cases not in @Session_Na.
*/
DELETE FROM WORK.SelectedEvents 
WHERE
	SessionID=@SessionID AND
	CaseID NOT IN (SELECT e.CaseID FROM WORK.SelectedEvents e WHERE e.SessionID=@Session_Na)
SELECT * FROM WORK.SelectedEvents WHERE SessionID=@SessionID

/*
Step 11 - Compute a Markov model from the modified @SessionID event set.
*/
SET @ModelID=NULL	
EXEC dbo.MarkovProcess2 
    @EventSet=@EventSet,
    @StartDateTime='2025-01-01',
    @EndDateTime='2026-12-31',
    @ModelID=@ModelID OUTPUT,
	@SessionID=@SessionID	--The value of @SessionID and the fact that there are rows in WORK.SelectedEvents
							--for this SessionID tells MarkovProcess2 to use those rows instead of calling
							--sp_SelectedEvents.
SELECT * FROM WORK.MarkovProcess WHERE SessionID=@SessionID
PRINT CONCAT('ModelID: ',CAST(@ModelID AS VARCHAR(10)),' Distinct Cases: '+CAST(@DistinctCases AS VARCHAR(10)))

/*
Clean up the WORK tables.
*/
DELETE FROM WORK.SelectedEvents WHERE SessionID=@SessionID
DELETE FROM WORK.SelectedEvents WHERE SessionID=@Session_Na
DELETE FROM WORK.MarkovProcess WHERE SessionID=@SessionID

```
