USE [TimeSolution]
GO
/****** Object:  StoredProcedure [dbo].[AddEventToCaseProperties]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Stored Procedure": "dbo.AddEventToCaseProperties",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-14",
  "Description": "For every case containing the specified event, upsert a case‐level property (named by @PropertyName or the event) with either the existing metric value or a default, marking it as added post‐ETL and timestamping the update; errors are logged to ProcErrorLog.",
  "Utilization": "Use when an event should also update or enrich case-level properties, especially when important event information needs to become part of the case’s lasting metadata.",
  "Input Parameters": [
    { "name": "@Event",            "type": "NVARCHAR(20)", "default": null, "description": "Name of the event to find in EventsFact (required)." },
    { "name": "@PropertyName",     "type": "NVARCHAR(20)", "default": null, "description": "Name of the case property column to upsert (defaults to @Event)." },
    { "name": "@Metric",           "type": "NVARCHAR(20)", "default": null, "description": "Metric property to pull from EventPropertiesParsed; uses default value if missing." }
  ],
  "Output Notes": [
    { "name": "CasePropertiesParsed", "type": "Table", "description": "Inserted or updated rows for each affected CaseID with PropertyValueNumeric, AddedProperty flag, and LastUpdate timestamp." },
    { "name": "ProcErrorLog",         "type": "Table", "description": "On error, a log row containing procedure name, parameters, and error details." }
  ],
  "Referenced objects": [
    { "name": "dbo.EventsFact",             "type": "Table",                   "description": "Source of CaseID–Event mappings." },
    { "name": "dbo.EventPropertiesParsed",  "type": "Table",                   "description": "Holds parsed event properties and metrics for lookup." },
    { "name": "dbo.CasePropertiesParsed",   "type": "Table",                   "description": "Target table for case‐level properties to merge into." },
    { "name": "dbo.ProcErrorLog",           "type": "Table",                   "description": "Error logging table used in CATCH block." }
  ]
}

Sample utilization:

	--For all poker games with this event, add it as a case-level property.
	--This lets us slice and dice by this property.
    EXEC dbo.AddEventToCaseProperties
        @Event = 'game-state-0',
        @PropertyName = NULL,
        @Metric = 'Amount';

    -- Look for all "bigtip" events, use their "tip" property (if present) 
    -- or default 1, and add it as a case-level property named "tip":
    EXEC dbo.AddEventToCaseProperties 
        @Event = 'bigtip',
        @PropertyName = NULL,   -- defaults to 'bigtip' (@Event).
        @Metric = 'tip';

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/



CREATE PROCEDURE [dbo].[AddEventToCaseProperties]
	@Event NVARCHAR(50),
	@PropertyName NVARCHAR(50)=NULL, --This is what we'll call the case property. It defaults to @Event.
	@Metric NVARCHAR(20) = NULL
AS
BEGIN

    SET NOCOUNT ON;

	-- Validate required parameter
	IF LTRIM(RTRIM(@Event)) = ''
	BEGIN
		RAISERROR (50001, 16, 1, 'Parameter @Event is required and cannot be empty.');
		RETURN;
	END

    DECLARE 
        @PropertySource_Actual TINYINT = 0,
        @DefaultMetricValue    FLOAT   = 1,--Default metric value if the value doesn't exist.
        @IsAddedProperty       BIT     = 1;--This is a property we're adding post ETL.

	SET @PropertyName=COALESCE(@PropertyName,@Event)

	-- Update CaseProperties for all cases that have the specified events
	BEGIN TRY
		MERGE INTO CasePropertiesParsed CP
		USING (
			SELECT DISTINCT 
				EF.CaseID, 
				EF.[Event],
				COALESCE(EPP.PropertyValueNumeric,@DefaultMetricValue) AS MetricValue,
				EPP.PropertyName AS Metric
			FROM 
				EventsFact EF
				LEFT JOIN EventPropertiesParsed EPP 
					ON EF.EventID = EPP.EventID 
					AND EPP.PropertySource = @PropertySource_Actual 
					AND EPP.PropertyName = @Metric
			WHERE EF.[Event] = @Event
		) AS EventCases
		ON CP.CaseID = EventCases.CaseID 
		   AND CP.PropertyName = EventCases.[Event] -- Ensure matching by both CaseID and Metric
		WHEN MATCHED THEN
			UPDATE SET 
				CP.PropertyValueNumeric = EventCases.MetricValue,
				CP.[AddedProperty]=@IsAddedProperty,
				CP.LastUpdate=GETDATE()
		WHEN NOT MATCHED BY TARGET THEN
			INSERT (CaseID, PropertyName, PropertyValueNumeric,AddedProperty) 
			VALUES (
				EventCases.CaseID, 
				@PropertyName,
				EventCases.MetricValue,
				@IsAddedProperty --This property is not part of normal ETL.
			);
	END TRY
    BEGIN CATCH
        INSERT INTO dbo.ProcErrorLog
            (ProcedureName, EventName, PropertyName, MetricName, ErrorNumber, ErrorMessage, ErrorLine)
        VALUES
            (OBJECT_NAME(@@PROCID),
             @Event,
             @PropertyName,
             @Metric,
             ERROR_NUMBER(),
             ERROR_MESSAGE(),
             ERROR_LINE()
            );
        THROW;  -- re-raise so callers know it failed
    END CATCH

END;
GO
/****** Object:  StoredProcedure [dbo].[BayesianProbability2]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "dbo.BayesianProbability2",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": "Computes Bayesian-style conditional probabilities between two event sequences over a specified time window, using the selected event stream to determine how often sequence A occurs, how often sequence B occurs, how often both occur in the same grouped unit, and the resulting conditional and marginal probabilities.",
  "Utilization": "Use when you want to measure how strongly one sequence is associated with another within the same case or time bucket. Helpful for questions such as 'given sequence A, how likely is sequence B,' especially in exploratory process analysis, branch co-occurrence analysis, or hypothesis testing across filtered populations.",
  "Input Parameters": [
    {
      "name": "@SeqA",
      "type": "NVARCHAR(MAX)",
      "default": null,
      "description": "CSV list of events defining sequence A. Can also be resolved from an EventSetCode by dbo.EventSetByCode."
    },
    {
      "name": "@SeqB",
      "type": "NVARCHAR(MAX)",
      "default": null,
      "description": "CSV list of events defining sequence B. Can also be resolved from an EventSetCode by dbo.EventSetByCode."
    },
    {
      "name": "@EventSet",
      "type": "NVARCHAR(MAX)",
      "default": "NULL",
      "description": "Optional override CSV of all events to retrieve. If NULL, the procedure builds the union of events from SeqA and SeqB. Comment in code notes this parameter may no longer be necessary."
    },
    {
      "name": "@StartDateTime",
      "type": "DATETIME",
      "default": "'1900-01-01'",
      "description": "Lower datetime bound for selected events. If NULL, defaults to 1900-01-01."
    },
    {
      "name": "@EndDateTime",
      "type": "DATETIME",
      "default": "'2050-12-31'",
      "description": "Upper datetime bound for selected events. If NULL, defaults to 2050-12-31."
    },
    {
      "name": "@transforms",
      "type": "NVARCHAR(MAX)",
      "default": "NULL",
      "description": "Optional transform code passed to dbo.sp_SelectedEvents for event normalization or mapping."
    },
    {
      "name": "@CaseFilterProperties",
      "type": "NVARCHAR(MAX)",
      "default": "NULL",
      "description": "Optional case-level filter properties passed through to dbo.sp_SelectedEvents."
    },
    {
      "name": "@EventFilterProperties",
      "type": "NVARCHAR(MAX)",
      "default": "NULL",
      "description": "Optional event-level filter properties passed through to dbo.sp_SelectedEvents."
    },
    {
      "name": "@GroupType",
      "type": "NVARCHAR(10)",
      "default": "NULL",
      "description": "Grouping key. NULL defaults through dbo.DefaultGroupType to CASEID. Supported values are CASEID, DAY, MONTH, and YEAR."
    },
    {
      "name": "@SessionID",
      "type": "UNIQUEIDENTIFIER OUTPUT",
      "default": "NULL",
      "description": "Optional session identifier for work-table persistence. If NULL, a new SessionID is created. When NULL on input, the procedure displays and then deletes the result row from WORK.BayesianProbability."
    }
  ],
  "Output Notes": [
    {
      "name": "Session behavior",
      "type": "Behavior",
      "description": "Writes the computed result row to WORK.BayesianProbability using the SessionID. If SessionID was not supplied, the procedure returns the row and then deletes it from the work table."
    },
    {
      "name": "EventSetKeyA",
      "type": "VARBINARY(16)",
      "description": "EventSetKey corresponding to SeqA, resolved or created through dbo.InsertEventSets."
    },
    {
      "name": "EventSetKeyB",
      "type": "VARBINARY(16)",
      "description": "EventSetKey corresponding to SeqB, resolved or created through dbo.InsertEventSets."
    },
    {
      "name": "ACount",
      "type": "INT",
      "description": "Number of grouped units matching sequence A."
    },
    {
      "name": "BCount",
      "type": "INT",
      "description": "Number of grouped units matching sequence B."
    },
    {
      "name": "A_Int_BCount",
      "type": "INT",
      "description": "Number of grouped units matching both sequence A and sequence B."
    },
    {
      "name": "[PB|A]",
      "type": "FLOAT",
      "description": "Conditional probability P(B|A) = A_Int_BCount / ACount."
    },
    {
      "name": "[PA|B]",
      "type": "FLOAT",
      "description": "Conditional probability P(A|B) = A_Int_BCount / BCount."
    },
    {
      "name": "TotalCases",
      "type": "INT",
      "description": "Total number of grouped units in the selected population."
    },
    {
      "name": "PA",
      "type": "FLOAT",
      "description": "Marginal probability of A = ACount / TotalCases."
    },
    {
      "name": "PB",
      "type": "FLOAT",
      "description": "Marginal probability of B = BCount / TotalCases."
    }
  ],
  "Referenced objects": [
    {
      "name": "dbo.sp_SelectedEvents",
      "type": "Stored Procedure",
      "description": "Builds the selected event stream into WORK.SelectedEvents for the supplied filters and session."
    },
    {
      "name": "WORK.SelectedEvents",
      "type": "Table",
      "description": "Temporary work-table source of selected event rows used to test sequence occurrence by case or time bucket."
    },
    {
      "name": "dbo.DefaultGroupType",
      "type": "Scalar Function",
      "description": "Normalizes the grouping mode to CASEID, DAY, MONTH, or YEAR."
    },
    {
      "name": "dbo.EventSetByCode",
      "type": "Scalar Function",
      "description": "Resolves sequence or event-set codes into comma-separated event lists."
    },
    {
      "name": "dbo.InsertEventSets",
      "type": "Stored Procedure",
      "description": "Finds or creates EventSetKey values for SeqA and SeqB before storing the Bayesian result."
    },
    {
      "name": "WORK.BayesianProbability",
      "type": "Table",
      "description": "Stores the computed Bayesian probability result row for the current SessionID."
    },
    {
      "name": "string_split",
      "type": "Built-in Function",
      "description": "Splits SeqA and SeqB CSV inputs into ordered event rows for sequence matching."
    }
  ]
}

Sample utilization:

    -- Fold probability after GameState-1 events in any case, over the full date range.
    EXEC dbo.BayesianProbability2
        @SeqA = 'GameState-1',
        @SeqB = 'folds',
        @EventSet = NULL,
        @StartDateTime = '19000101',
        @EndDateTime   = '20501231',
        @transforms    = NULL,
        @CaseFilterProperties  = NULL,
        @EventFilterProperties = NULL,
        @GroupType     = NULL,
        @SessionID     = NULL;

    -- Probability of “Holter Pos” given “TIA” across all available events.
    EXEC dbo.BayesianProbability2
        @SeqA = 'TIA',
        @SeqB = 'Holter Pos',
        @EventSet = NULL,
        @StartDateTime = NULL,
        @EndDateTime   = NULL,
        @transforms    = NULL,
        @CaseFilterProperties  = NULL,
        @EventFilterProperties = NULL,
        @GroupType     = NULL,
        @SessionID     = NULL;

    -- Probability of “Holter Pos” given “TIA” restricted to the cardiology event set.
    EXEC dbo.BayesianProbability2
        @SeqA = 'TIA',
        @SeqB = 'Holter Pos',
        @EventSet = 'cardiology',
        @StartDateTime = NULL,
        @EndDateTime   = NULL,
        @transforms    = NULL,
        @CaseFilterProperties  = NULL,
        @EventFilterProperties = NULL,
        @GroupType     = NULL,
        @SessionID     = NULL;

Notes:
    • Sequence matching is order-sensitive. The events in SeqA and SeqB must occur in the exact specified order within the grouped unit.
    • GroupType controls whether co-occurrence is evaluated by case, day, month, or year.
    • If @SessionID is supplied, the result remains in WORK.BayesianProbability for downstream processing; otherwise the procedure displays and then deletes the row.
    • The current code constructs @EventSet from SeqA and SeqB when it is NULL; an in-code note suggests the standalone @EventSet parameter may no longer be necessary.

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, concurrency, indexing strategy, partitioning, and performance tuning have been omitted or simplified.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE PROCEDURE [dbo].[BayesianProbability2]
(
	@SeqA NVARCHAR(MAX), --csv. 
	@SeqB NVARCHAR(MAX), --csv sequence.
	@EventSet NVARCHAR(MAX), -- IF NULL, this will be constructed from @SeA and @SeqB
	@StartDateTime DATETIME,
	@EndDateTime DATETIME,
	@transforms NVARCHAR(MAX),
	@CaseFilterProperties NVARCHAR(MAX),
	@EventFilterProperties NVARCHAR(MAX),
	@GroupType NVARCHAR(10), --NULL will default to CASEID. Values: 'CASEID','DAY','MONTH','YEAR'
	@SessionID UNIQUEIDENTIFIER=NULL OUTPUT

)
AS
BEGIN

	DECLARE @ByCase BIT=1 --Yes.
	DECLARE @metric NVARCHAR(20)=NULL
	DECLARE @IsSequence BIT=1 --We're looking for a sequence, not a set.
	DECLARE @enumerate_multiple_events BIT=0

	SET @StartDateTime=COALESCE(@StartDateTime,'01/01/1900')
	SET @EndDateTime=COALESCE(@EndDateTime,'12/31/2050')
	SET @GroupType=dbo.DefaultGroupType(@GroupType)

	DECLARE @DisplayResult BIT=CASE WHEN @SessionID IS NULL THEN 1 ELSE 0 END
	SET @SessionID=COALESCE(@SessionID,NEWID())

	DECLARE @tempSeq NVARCHAR(MAX)= (SELECT [dbo].[EventSetByCode](@SeqA,@IsSequence))
	SET @SeqA = CASE WHEN @tempSeq IS NULL THEN @SeqA ELSE @tempSeq END

	SET @tempSeq = (SELECT [dbo].[EventSetByCode](@SeqB,@IsSequence))
	SET @SeqB = CASE WHEN @tempSeq IS NULL THEN @SeqB ELSE @tempSeq END

	DECLARE @sqA TABLE ([Event] NVARCHAR(50),[Rank] INT) 
	INSERT INTO @sqA
		SELECT [Value] AS [Event], ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [rank]
		FROM string_split(@SeqA,',')

	DECLARE @ArCount INT=@@ROWCOUNT
	DECLARE @Ar1 NVARCHAR(50)=(SELECT [Event] FROM @sqA WHERE [Rank]=1)

	DECLARE @sqB TABLE ([Event] NVARCHAR(50),[Rank] INT) 
	INSERT INTO @sqB
		SELECT [Value] AS [Event], ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [rank]
		FROM string_split(@SeqB,',')

	DECLARE @BrCount INT=@@ROWCOUNT
	DECLARE @Br1 NVARCHAR(50)=(SELECT [Event] FROM @sqB WHERE [Rank]=1)

	IF @EventSet IS NULL
	BEGIN
		SET @EventSet=
		(
			SELECT STRING_AGG([Event],',')
			FROM
			(
				SELECT [Event] FROM @sqA
				UNION
				SELECT [Event] FROM @sqB
			) t
		) 
	END

	DECLARE @RowsReturned BIGINT

	EXEC dbo.sp_SelectedEvents
		 @EventSet = @EventSet,
		 @enumerate_multiple_events = @enumerate_multiple_events,
		 @StartDateTime = @StartDateTime,
		 @EndDateTime = @EndDateTime,
		 @transforms = @transforms,
		 @ByCase = @ByCase,
		 @metric = @metric,
		 @CaseFilterProperties = @CaseFilterProperties,
		 @EventFilterProperties = @EventFilterProperties,
		 @SessionID=@SessionID,
		 @RowsReturned=@RowsReturned OUTPUT

	IF COALESCE(@RowsReturned,0)>0
	BEGIN
		DROP TABLE IF EXISTS #t0
		CREATE TABLE #t0
		(
			[Rank] INT NOT NULL,
			CaseID INT NOT NULL,
			[Event] NVARCHAR(50) NOT NULL
		)

		INSERT INTO #t0
			SELECT 
				[Rank],
				CASE
					WHEN @GroupType='DAY' THEN CAST(CONVERT(char(8), EventDate, 112) AS INT)
					WHEN @GroupType='MONTH' THEN YEAR(EventDate)*100+MONTH(EventDate)
					WHEN @GroupType='YEAR' THEN YEAR(EventDate)
					ELSE CaseID
				END AS CaseID,
				[Event]
			FROM 
				WORK.SelectedEvents t
			WHERE
				SessionID=@SessionID

		-- Supports joins that anchor on CaseID + Rank.
		CREATE CLUSTERED INDEX #t0_index1 ON #t0 (CaseID,[Rank],[Event])

		-- Supports joins that begin from Event name.
		CREATE NONCLUSTERED INDEX #t0_index2 ON #t0 ([Event],CaseID,[Rank])

		DECLARE @TotalCases INT=(SELECT COUNT(DISTINCT CaseID) FROM #t0)

		CREATE TABLE #A (CaseID INT NOT NULL)
		CREATE UNIQUE CLUSTERED INDEX #A_index ON #A (CaseID)

		INSERT INTO #A (CaseID)
			SELECT DISTINCT
				se.CaseID
			FROM
				@sqA sq
				JOIN #t0 se
					ON se.[Event]=sq.[Event]
				JOIN #t0 se1
					ON se1.CaseID=se.CaseID
					AND se1.[Event]=@Ar1
			WHERE
				se.[Rank]=se1.[Rank]+sq.[Rank]-1
			GROUP BY
				se.CaseID
			HAVING
				COUNT(*)=@ArCount

		CREATE TABLE #B (CaseID INT NOT NULL)
		CREATE UNIQUE CLUSTERED INDEX #B_index ON #B (CaseID)

		INSERT INTO #B (CaseID)
			SELECT DISTINCT
				se.CaseID
			FROM
				@sqB sq
				JOIN #t0 se
					ON se.[Event]=sq.[Event]
				JOIN #t0 se1
					ON se1.CaseID=se.CaseID
					AND se1.[Event]=@Br1
			WHERE
				se.[Rank]=se1.[Rank]+sq.[Rank]-1
			GROUP BY
				se.CaseID
			HAVING
				COUNT(*)=@BrCount

		DELETE
		FROM WORK.SelectedEvents
		WHERE SessionID=@SessionID

		DECLARE @ACount INT = (SELECT COUNT(*) FROM #A) 
		DECLARE @BCount INT = (SELECT COUNT(*) FROM #B) 
		DECLARE @A_Int_BCount INT =
		(
			SELECT COUNT(*)
			FROM #A a
			JOIN #B b
				ON a.CaseID=b.CaseID
		)
	DECLARE @EventSetKeyA VARBINARY(16)
	DECLARE @EventSetKeyB VARBINARY(16)

	--The SeqA and SeqB parameters are event sets, even if it's only one.
	--We need an EventSetKey for both of them. It will find it or create a new one.
    EXEC dbo.InsertEventSets 
         @EventSet = @SeqA,
         @EventSetCode = NULL,
         @EventSetKey = @EventSetKeyA OUTPUT,
         @IsSequence = 0;

    EXEC dbo.InsertEventSets 
         @EventSet = @SeqB,
         @EventSetCode = NULL,
         @EventSetKey = @EventSetKeyB OUTPUT,
         @IsSequence = 0;

	INSERT INTO WORK.BayesianProbability
	(
		SessionID,
		EventSetKeyA,
		EventSetKeyB,
		ACount,
		BCount,
		A_Int_BCount,
		[PB|A],
		[PA|B],
		TotalCases,
		PA,
		PB
	)
	VALUES
	(
		@SessionID,
		@EventSetKeyA,
		@EventSetKeyB,
		@ACount,
		@BCount,
		@A_Int_BCount,
		@A_Int_BCount/CAST(@ACount AS FLOAT),
		@A_Int_BCount/CAST(@BCount AS FLOAT),
		@TotalCases,
		@ACount/CAST(@TotalCases AS FLOAT),
		@BCount/CAST(@TotalCases AS FLOAT)
	)
	IF @DisplayResult=1
	BEGIN
		SELECT * FROM WORK.BayesianProbability WHERE SessionID=@SessionID
		DELETE FROM WORK.BayesianProbability WHERE SessionID=@SessionID		
	END

	DROP TABLE #t0
	DROP TABLE #B
	DROP TABLE #A
	END

END
GO
/****** Object:  StoredProcedure [dbo].[BuildTimeSolutionsMetadata]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Stored Procedure": "dbo.BuildTimeSolutionsMetadata",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": "Refreshes WORK.semantic_web_llm_values and dbo.TimeSolutionsMetadata by truncating both tables, repopulating WORK.semantic_web_llm_values from dbo.get_semantic_web_llm_values, and then rebuilding dbo.TimeSolutionsMetadata from dbo.getTimeMoleculesObjectMetadata() plus the WORK table.",
  "Utilization": "Use when you want to fully refresh the metadata tables used for embeddings, semantic search, or LLM-oriented object discovery.",
  "Input Parameters": [],
  "Output Notes": [
    { "name": "WORK.semantic_web_llm_values", "type": "Table", "description": "Reloaded from dbo.get_semantic_web_llm_values." },
    { "name": "dbo.TimeSolutionsMetadata", "type": "Table", "description": "Reloaded from dbo.getTimeMoleculesObjectMetadata() and WORK.semantic_web_llm_values." }
  ],
  "Referenced objects": [
    { "name": "dbo.getTimeMoleculesObjectMetadata", "type": "Table-Valued Function", "description": "Returns metadata for views, scalar functions, stored procedures, and table-valued functions." },
    { "name": "dbo.get_semantic_web_llm_values", "type": "Stored Procedure", "description": "Returns semantic-web / LLM rows used to populate WORK.semantic_web_llm_values." },
    { "name": "WORK.semantic_web_llm_values", "type": "Table", "description": "Intermediate table holding semantic-web / LLM values." },
    { "name": "dbo.TimeSolutionsMetadata", "type": "Table", "description": "Destination table for combined metadata." }
  ]
}

Sample Utilization:

    EXEC dbo.BuildTimeSolutionsMetadata;

Context:
    • This code is provided as-is for teaching and demonstration.
    • It truncates and repopulates both tables each time it runs.
*/
CREATE   PROCEDURE [dbo].[BuildTimeSolutionsMetadata]
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE @AllAccess BIGINT=-1 --AcessBitmap set to include everything.

    IF OBJECT_ID('WORK.semantic_web_llm_values', 'U') IS NULL
    BEGIN
        CREATE TABLE WORK.semantic_web_llm_values
        (
            ObjectName  NVARCHAR(500)  NULL,
            ObjectType  NVARCHAR(50)   NULL,
            Description NVARCHAR(MAX)  NULL,
            Utilization NVARCHAR(MAX)  NULL,
            IRI         NVARCHAR(1000) NULL,
            CodeColumn  NVARCHAR(128)  NULL,
            Code        NVARCHAR(50)   NULL
        );
    END;

    IF OBJECT_ID('dbo.TimeSolutionsMetadata', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TimeSolutionsMetadata
        (
            ObjectType            NVARCHAR(MAX)   NULL,
            ObjectName            NVARCHAR(MAX)  NULL,
            Description           NVARCHAR(MAX)  NULL,
            Utilization           NVARCHAR(MAX)  NULL,
            ParametersJson        NVARCHAR(MAX)  NULL,
            OutputNotes           NVARCHAR(MAX)  NULL,
            ReferencedObjectsJson NVARCHAR(MAX)  NULL,
            IRI                   NVARCHAR(MAX) NULL,
            CodeColumn            NVARCHAR(MAX)  NULL,
            Code                  NVARCHAR(MAX)   NULL,
			AccessBitmap		BIGiNT NULL,
			SampleCode			NVARCHAR(MAX) NULL
        );
    END;

    TRUNCATE TABLE WORK.semantic_web_llm_values;
    TRUNCATE TABLE dbo.TimeSolutionsMetadata;


    INSERT INTO dbo.TimeSolutionsMetadata
    (
        ObjectType,
        ObjectName,
        Description,
        Utilization,
        ParametersJson,
        OutputNotes,
        ReferencedObjectsJson,
        IRI,
        CodeColumn,
        Code,
		AccessBitmap,
		SampleCode
    )
    SELECT
        ObjectType,
        ObjectName,
        Description,
        Utilization,
        ParametersJson,
        OutputNotes,
        ReferencedObjectsJson,
        CAST(NULL AS NVARCHAR(1000)) AS IRI,
        CAST(NULL AS NVARCHAR(128))  AS CodeColumn,
        CAST(NULL AS NVARCHAR(50))   AS Code,
		@AllAccess AS AccessBitMap,
		SampleCode
    FROM dbo.getTimeMoleculesObjectMetadata()
    WHERE ObjectType IN
    (
        'VIEW',
        'SQL_SCALAR_FUNCTION',
        'SQL_STORED_PROCEDURE',
        'SQL_TABLE_VALUED_FUNCTION',
        'SQL_INLINE_TABLE_VALUED_FUNCTION'
    );

    EXEC dbo.get_semantic_web_llm_values;


    INSERT INTO dbo.TimeSolutionsMetadata
    (
        ObjectType,
        ObjectName,
        Description,
        Utilization,
        ParametersJson,
        OutputNotes,
        ReferencedObjectsJson,
        IRI,
        CodeColumn,
        Code,
		AccessBitmap,
		SampleCode
    )
    SELECT
        ObjectType,
        ObjectName,
        Description,
        Utilization,
        CAST(NULL AS NVARCHAR(MAX)) AS ParametersJson,
        CAST(NULL AS NVARCHAR(MAX)) AS OutputNotes,
        CAST(NULL AS NVARCHAR(MAX)) AS ReferencedObjectsJson,
        IRI,
        CodeColumn,
        Code,
		AccessBitmap,
		SampleCode
    FROM WORK.semantic_web_llm_values;
END

GO
/****** Object:  StoredProcedure [dbo].[CalculateBayesianForModels]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "dbo.CalculateBayesianForModels",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": "For a given ModelID, derives Bayesian-style co-occurrence probabilities between case characteristics associated with that model, including both anomaly-derived event sequences and case-property attributes, then inserts or updates the results in dbo.BayesianProbabilities.",
  "Utilization": "Use when you want to compute pairwise conditional probabilities across the characteristic signals associated with a model population. Helpful for discovering which anomaly sequences and case properties tend to co-occur within the same cases, and for persisting those relationships as reusable Bayesian probabilities tied to a specific model.",
  "Input Parameters": [
    {
      "name": "@ModelID",
      "type": "INT",
      "default": null,
      "description": "Identifier of the model whose characteristics and case population will be analyzed."
    }
  ],
  "Output Notes": [
    {
      "name": "Result set 1",
      "type": "Table",
      "description": "Raw characteristic rows derived from dbo.CaseCharacteristics(@ModelID), with one EventSequence per CaseID, Category, and Attribute."
    },
    {
      "name": "Result set 2",
      "type": "Table",
      "description": "Aggregated counts for each distinct characteristic sequence within the model population."
    },
    {
      "name": "Result set 3",
      "type": "Table",
      "description": "Pairwise combinations of characteristics with initialized counts and computed intersections pending update."
    },
    {
      "name": "Result set 4",
      "type": "Table",
      "description": "Final probability rows showing EventSet keys, counts, intersections, conditional probabilities, marginal probabilities, and anomaly category IDs for nonzero intersections."
    },
    {
      "name": "Side effects",
      "type": "Behavior",
      "description": "Seeds missing sequences into dbo.EventSets as sequence entries and MERGEs the computed probabilities into dbo.BayesianProbabilities."
    }
  ],
  "Referenced objects": [
    {
      "name": "dbo.CaseCharacteristics",
      "type": "Table-Valued Function",
      "description": "Supplies the model-specific anomaly signals and case properties used as the input population."
    },
    {
      "name": "dbo.EventSets",
      "type": "Table",
      "description": "Stores event sets and sequences; receives any newly discovered EventSequence values."
    },
    {
      "name": "dbo.EventSetKey",
      "type": "Scalar Function",
      "description": "Computes the key used to seed new EventSet rows."
    },
    {
      "name": "dbo.BayesianProbabilities",
      "type": "Table",
      "description": "Target table updated or inserted with the computed Bayesian probability rows."
    },
    {
      "name": "dbo.DimAnomalyCategories",
      "type": "Table",
      "description": "Maps anomaly category codes to anomaly category IDs for persisted probability rows."
    }
  ]
}

Sample utilization:

    -- Compute and persist Bayesian relationships for all characteristics associated with model 1.
    EXEC dbo.CalculateBayesianForModels
        @ModelID = 1;

    -- Recompute and upsert Bayesian relationships for another stored model.
    EXEC dbo.CalculateBayesianForModels
        @ModelID = 2;

Notes:
    • The procedure uses dbo.CaseCharacteristics(@ModelID) as its source population, so the quality and scope of the result depend on how that function represents anomaly-derived sequences and case properties for the model.
    • Case properties are represented using the property name as the EventSequence when Category = 'CaseProperty'.
    • Non-property characteristics are represented as two-step sequences in the form EventA + ',' + EventB.
    • Only pairwise combinations with a nonzero intersection are emitted in the final probability output and persisted to dbo.BayesianProbabilities.
    • New sequences discovered in the pairwise comparison set are inserted into dbo.EventSets as IsSequence = 1, with IsCaseProperty set according to whether the source characteristic came from a case property.
    • The procedure uses GroupType = 'ModelProp' for all persisted rows, indicating that the grouping context is the model-level characteristic space rather than a time bucket or raw case stream.

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, concurrency, indexing strategy, and performance tuning have been omitted or simplified.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/
CREATE PROCEDURE [dbo].[CalculateBayesianForModels]
    @ModelID INT,
    @SessionID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CaseProperty NVARCHAR(50) = 'CaseProperty';
    DECLARE @ModelProp NVARCHAR(50) = 'ModelProp';

    SET @SessionID = COALESCE(@SessionID, NEWID());

    EXEC dbo.sp_CaseCharacteristics
         @ModelID = @ModelID,
         @SessionID = @SessionID;

    -------------------------------------------------------------------------
    -- 1. Build one feature row per CaseID
    -------------------------------------------------------------------------
    DROP TABLE IF EXISTS #raw;
    CREATE TABLE #raw
    (
        ModelID INT NOT NULL,
        CaseID INT NOT NULL,
        [Category] NVARCHAR(100) NOT NULL,
        [Attribute] NVARCHAR(100) NOT NULL,
        Feature NVARCHAR(1000) NOT NULL,
        FeatureHash VARBINARY(32) NOT NULL
    );

    INSERT INTO #raw
    (
        ModelID,
        CaseID,
        [Category],
        [Attribute],
        Feature,
        FeatureHash
    )
    SELECT
        @ModelID AS ModelID,
        cc.CaseID,
        cc.[Category],
        cc.[Attribute],
        f.Feature,
        HASHBYTES('SHA2_256', f.Feature) AS FeatureHash
    FROM WORK.CaseCharacteristics cc
    CROSS APPLY
    (
        SELECT
            CASE
                WHEN cc.[Category] = @CaseProperty THEN
                    cc.[Attribute] + '=' +
                    COALESCE(
                        cc.PropertyValueAlpha,
                        CONVERT(NVARCHAR(100), cc.PropertyValueNumeric)
                    )
                ELSE
                    TRIM(cc.EventA) + ',' + TRIM(cc.EventB)
            END AS Feature
    ) f
    WHERE
        cc.SessionID = @SessionID
        AND
        (
            (cc.[Category] = @CaseProperty AND (cc.PropertyValueAlpha IS NOT NULL OR cc.PropertyValueNumeric IS NOT NULL))
            OR
            (cc.[Category] <> @CaseProperty AND cc.EventA IS NOT NULL AND cc.EventB IS NOT NULL)
        );

    DELETE FROM WORK.CaseCharacteristics
    WHERE SessionID = @SessionID;

    CREATE CLUSTERED INDEX IX_raw_CaseID
        ON #raw (CaseID, ModelID);

    CREATE NONCLUSTERED INDEX IX_raw_Feature
        ON #raw (ModelID, [Category], [Attribute], FeatureHash, CaseID);

    -------------------------------------------------------------------------
    -- Optional debug
    -------------------------------------------------------------------------
    SELECT * FROM #raw ORDER BY CaseID, [Category], [Attribute], Feature;

    -------------------------------------------------------------------------
    -- 2. Count how many distinct cases contain each feature
    -------------------------------------------------------------------------
    DROP TABLE IF EXISTS #FeatureCounts;
    CREATE TABLE #FeatureCounts
    (
        ModelID INT NOT NULL,
        [Category] NVARCHAR(100) NOT NULL,
        [Attribute] NVARCHAR(100) NOT NULL,
        Feature NVARCHAR(1000) NOT NULL,
        FeatureHash VARBINARY(32) NOT NULL,
        [Count] INT NOT NULL
    );

    INSERT INTO #FeatureCounts
    (
        ModelID,
        [Category],
        [Attribute],
        Feature,
        FeatureHash,
        [Count]
    )
    SELECT
        r.ModelID,
        r.[Category],
        r.[Attribute],
        r.Feature,
        r.FeatureHash,
        COUNT(DISTINCT r.CaseID) AS [Count]
    FROM #raw r
    GROUP BY
        r.ModelID,
        r.[Category],
        r.[Attribute],
        r.Feature,
        r.FeatureHash;

    CREATE CLUSTERED INDEX IX_FeatureCounts_Main
        ON #FeatureCounts (ModelID, [Category], [Attribute], FeatureHash);

    SELECT * FROM #FeatureCounts ORDER BY [Count] DESC, [Category], [Attribute], Feature;

    -------------------------------------------------------------------------
    -- 3. Build unique unordered pairs of features
    -------------------------------------------------------------------------
    DROP TABLE IF EXISTS #Pairs;
    CREATE TABLE #Pairs
    (
        ModelID INT NOT NULL,
        [CategoryA] NVARCHAR(100) NOT NULL,
        [AttributeA] NVARCHAR(100) NOT NULL,
        FeatureA NVARCHAR(1000) NOT NULL,
        FeatureAHash VARBINARY(32) NOT NULL,
        ACount INT NOT NULL,
        [CategoryB] NVARCHAR(100) NOT NULL,
        [AttributeB] NVARCHAR(100) NOT NULL,
        FeatureB NVARCHAR(1000) NOT NULL,
        FeatureBHash VARBINARY(32) NOT NULL,
        BCount INT NOT NULL,
        A_Int_BCount INT NULL
    );

    INSERT INTO #Pairs
    (
        ModelID,
        [CategoryA],
        [AttributeA],
        FeatureA,
        FeatureAHash,
        ACount,
        [CategoryB],
        [AttributeB],
        FeatureB,
        FeatureBHash,
        BCount
    )
    SELECT
        fc1.ModelID,
        fc1.[Category],
        fc1.[Attribute],
        fc1.Feature,
        fc1.FeatureHash,
        fc1.[Count],
        fc2.[Category],
        fc2.[Attribute],
        fc2.Feature,
        fc2.FeatureHash,
        fc2.[Count]
    FROM #FeatureCounts fc1
    JOIN #FeatureCounts fc2
        ON fc1.ModelID = fc2.ModelID
    WHERE
        (
               fc1.[Category] < fc2.[Category]
            OR (fc1.[Category] = fc2.[Category] AND fc1.[Attribute] < fc2.[Attribute])
            OR (fc1.[Category] = fc2.[Category] AND fc1.[Attribute] = fc2.[Attribute] AND fc1.Feature < fc2.Feature)
        );

    CREATE CLUSTERED INDEX IX_Pairs_Main
        ON #Pairs (ModelID, CategoryA, AttributeA, FeatureAHash, CategoryB, AttributeB, FeatureBHash);

    SELECT * FROM #Pairs ORDER BY ACount DESC, BCount DESC, FeatureA, FeatureB;

    -------------------------------------------------------------------------
    -- 4. Seed features into EventSets if missing
    -------------------------------------------------------------------------
    INSERT INTO dbo.EventSets
    (
        EventSetKey,
        EventSet,
        IsSequence,
        IsCaseProperty
    )
    SELECT
        dbo.EventSetKey(t.EventSet, 1),
        t.EventSet,
        1 AS IsSequence,
        t.IsCaseProperty
    FROM
    (
        SELECT DISTINCT
            FeatureA AS EventSet,
            CASE WHEN CategoryA = @CaseProperty THEN 1 ELSE 0 END AS IsCaseProperty
        FROM #Pairs

        UNION

        SELECT DISTINCT
            FeatureB AS EventSet,
            CASE WHEN CategoryB = @CaseProperty THEN 1 ELSE 0 END AS IsCaseProperty
        FROM #Pairs
    ) t
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.EventSets es
        WHERE es.EventSet = t.EventSet
          AND es.IsSequence = 1
    );

    -------------------------------------------------------------------------
    -- 5. Compute pair intersections across cases
    -------------------------------------------------------------------------
    UPDATE p
    SET A_Int_BCount =
    (
        SELECT COUNT(DISTINCT r1.CaseID)
        FROM #raw r1
        JOIN #raw r2
            ON r2.ModelID = r1.ModelID
           AND r2.CaseID = r1.CaseID
        WHERE
            r1.ModelID = p.ModelID
            AND r1.[Category] = p.CategoryA
            AND r1.[Attribute] = p.AttributeA
            AND r1.FeatureHash = p.FeatureAHash
            AND r2.[Category] = p.CategoryB
            AND r2.[Attribute] = p.AttributeB
            AND r2.FeatureHash = p.FeatureBHash
    )
    FROM #Pairs p;

    DECLARE @TotalCases INT =
    (
        SELECT COUNT(DISTINCT CaseID)
        FROM #raw
    );

    -------------------------------------------------------------------------
    -- 6. Final result preview
    -------------------------------------------------------------------------
    SELECT
        @ModelID AS ModelID,
        @ModelProp AS GroupType,
        p.FeatureA,
        esA.EventSetKey AS EventSetAKey,
        p.FeatureB,
        esB.EventSetKey AS EventSetBKey,
        p.ACount,
        p.BCount,
        p.A_Int_BCount,
        CASE WHEN p.ACount = 0 THEN NULL ELSE p.A_Int_BCount / CAST(p.ACount AS FLOAT) END AS [PB|A],
        CASE WHEN p.BCount = 0 THEN NULL ELSE p.A_Int_BCount / CAST(p.BCount AS FLOAT) END AS [PA|B],
        @TotalCases AS TotalCases,
        CASE WHEN @TotalCases = 0 THEN NULL ELSE p.ACount / CAST(@TotalCases AS FLOAT) END AS PA,
        CASE WHEN @TotalCases = 0 THEN NULL ELSE p.BCount / CAST(@TotalCases AS FLOAT) END AS PB,
        (SELECT [AmomalyCategoryID] FROM dbo.DimAnomalyCategories WHERE [Code] = p.CategoryA) AS AnomalyCategoryIDA,
        (SELECT [AmomalyCategoryID] FROM dbo.DimAnomalyCategories WHERE [Code] = p.CategoryB) AS AnomalyCategoryIDB
    FROM #Pairs p
    LEFT JOIN dbo.EventSets esA
        ON esA.EventSet = p.FeatureA
    LEFT JOIN dbo.EventSets esB
        ON esB.EventSet = p.FeatureB
    WHERE COALESCE(p.A_Int_BCount, 0) > 0
    ORDER BY
        p.A_Int_BCount DESC,
        p.ACount DESC,
        p.BCount DESC,
        p.FeatureA,
        p.FeatureB;

    -------------------------------------------------------------------------
    -- 7. Persist results
    -------------------------------------------------------------------------
    MERGE dbo.BayesianProbabilities AS Target
    USING
    (
        SELECT
            @ModelID AS ModelID,
            @ModelProp AS GroupType,
            esA.EventSetKey AS EventSetAKey,
            esB.EventSetKey AS EventSetBKey,
            p.ACount,
            p.BCount,
            p.A_Int_BCount,
            CASE WHEN p.ACount = 0 THEN NULL ELSE p.A_Int_BCount / CAST(p.ACount AS FLOAT) END AS [PB|A],
            CASE WHEN p.BCount = 0 THEN NULL ELSE p.A_Int_BCount / CAST(p.BCount AS FLOAT) END AS [PA|B],
            @TotalCases AS TotalCases,
            CASE WHEN @TotalCases = 0 THEN NULL ELSE p.ACount / CAST(@TotalCases AS FLOAT) END AS PA,
            CASE WHEN @TotalCases = 0 THEN NULL ELSE p.BCount / CAST(@TotalCases AS FLOAT) END AS PB,
            (SELECT [AmomalyCategoryID] FROM dbo.DimAnomalyCategories WHERE [Code] = p.CategoryA) AS AnomalyCategoryIDA,
            (SELECT [AmomalyCategoryID] FROM dbo.DimAnomalyCategories WHERE [Code] = p.CategoryB) AS AnomalyCategoryIDB
        FROM #Pairs p
        LEFT JOIN dbo.EventSets esA
            ON esA.EventSet = p.FeatureA
        LEFT JOIN dbo.EventSets esB
            ON esB.EventSet = p.FeatureB
        WHERE COALESCE(p.A_Int_BCount, 0) > 0
    ) AS Source
    ON  Target.ModelID = Source.ModelID
    AND Target.GroupType = Source.GroupType
    AND Target.EventSetAKey = Source.EventSetAKey
    AND Target.EventSetBKey = Source.EventSetBKey
    AND Target.AnomalyCategoryIDA = Source.AnomalyCategoryIDA
    AND Target.AnomalyCategoryIDB = Source.AnomalyCategoryIDB
    WHEN MATCHED THEN
        UPDATE SET
            Target.ACount = Source.ACount,
            Target.BCount = Source.BCount,
            Target.A_Int_BCount = Source.A_Int_BCount,
            Target.[PB|A] = Source.[PB|A],
            Target.[PA|B] = Source.[PA|B],
            Target.TotalCases = Source.TotalCases,
            Target.PA = Source.PA,
            Target.PB = Source.PB,
            Target.LastUpdate = GETDATE()
    WHEN NOT MATCHED THEN
        INSERT
        (
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
            AnomalyCategoryIDA,
            AnomalyCategoryIDB
        )
        VALUES
        (
            Source.ModelID,
            Source.GroupType,
            Source.EventSetAKey,
            Source.EventSetBKey,
            Source.ACount,
            Source.BCount,
            Source.A_Int_BCount,
            Source.[PB|A],
            Source.[PA|B],
            Source.TotalCases,
            Source.PA,
            Source.PB,
            Source.AnomalyCategoryIDA,
            Source.AnomalyCategoryIDB
        );
END
GO
/****** Object:  StoredProcedure [dbo].[CauseAndEffectModel]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*

Stored Procedure: [dbo].[CauseAndEffectModel]
Author: Eugene Asahara
Description:
    For each pairing of “trigger” events (EventBList) and subsequent “effect” events (EventAList), 
    joined by a case-level property (e.g. Player), computes P(A | B) per property value.  
    Optionally persists the raw detail rows to a work table.

Sample utilization:

    EXEC dbo.CauseAndEffectModel
        @EventBList = 'raises,folds,calls,bets,checks',
        @EventAList = 'pokergamestates',
        @EventAProperty = 'Player',
        @SaveDetailsTableName = 1;

Input Notes:

    • @EventBList NVARCHAR(MAX)
        – CSV of events to treat as “cause” (B) events.
    • @EventAList NVARCHAR(MAX)
        – CSV of events to treat as “effect” (A) events.
    • @EventAProperty NVARCHAR(1000)
        – Name of the event-level property (in EventPropertiesParsed.PropertyName)
          used to group/join on A events (e.g. ‘Player’).
    • @SaveDetailsTableName BIT
        – 1 to persist the intermediate A–B matches into [WORK].causeandeffectdetails; 
          0 to skip saving details.

Output Notes:

    • Returns a result set with columns:
        – Player        NVARCHAR(1000)
        – EventB        NVARCHAR(20)
        – EventA        NVARCHAR(20)
        – [PB|A]        FLOAT    -- Percentage P(A|B) = count(A∩B)/count(B)
        – A_Int_BCount  BIGINT   -- Number of A-B pair occurrences
        – BCount        FLOAT    -- Total count of B events per Player
    • Side effects:
        – Optionally creates/overwrites [WORK].causeandeffectdetails with raw matches.
        – Uses temp tables #b, #a, #c—ensure no name collisions.
        – Creates clustered indexes on the temp tables for performance.

Context:
    Part of the TimeSolution code supplementing the book
    “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/

CREATE PROCEDURE [dbo].[CauseAndEffectModel]
@EventBList NVARCHAR(MAX),
@EventAList NVARCHAR(MAX),
@EventAProperty NVARCHAR(1000),
@SaveDetailsTableName BIT=1

AS
BEGIN

	DECLARE @alst dbo.[EventSet]
	INSERT INTO @alst ([Event])
		SELECT [event] FROM dbo.ParseEventSet(@EventAList, 0) --@EventSet could reference a code (IncludedEvents.Code). IsSequence=0, it's a set.


	DECLARE @blst dbo.[EventSet]
	INSERT INTO @blst ([Event])
		SELECT [event] FROM dbo.ParseEventSet(@EventBList, 0) --@EventSet could reference a code (IncludedEvents.Code). IsSequence=0, it's a set.


	DROP TABLE IF EXISTS #b

	CREATE TABLE #b (CaseID INT ,EventB NVARCHAR(50),EventBID BIGINT, CaseOrdinal BIGINT,[Row] BIGINT)
	INSERT INTO #b
		SELECT
			b.CaseID,
			b.[Event] AS EventB,
			b.[EventID] AS EventBID,
			b.CaseOrdinal,
			ROW_NUMBER() OVER (ORDER BY CaseID,b.CaseOrdinal) AS [Row]
		FROM
			[dbo].[EventsFact] b 
			JOIN @blst blst on blst.[Event]=b.[Event]
	CREATE CLUSTERED INDEX #b_idx ON #b(CaseID,[Row])

	DROP TABLE IF EXISTS #a
	CREATE TABLE #a (EventB  NVARCHAR(50), EventA  NVARCHAR(50), Player NVARCHAR(1000),EventBID BIGINT, EventAID BIGINT)
	INSERT INTO #a
		SELECT
			b.EventB,
			a.[Event] AS EventA,
			ap.PropertyValueAlpha AS [Player],
			b.EventBID AS EventBID,
			a.EventID AS EventAID
		FROM
			[dbo].[EventsFact] a 
			JOIN @alst alst on alst.[Event]=a.[Event]
			JOIN [dbo].[EventPropertiesParsed] ap ON ap.EventID=a.EventID AND ap.PropertyName=@EventAProperty AND ap.PropertySource=0 -- This is an input property of the game state.
			JOIN #b b ON b.CaseID=a.CaseID AND a.CaseOrdinal>b.CaseOrdinal
			JOIN #b b1 ON b1.CaseID=a.CaseID AND b1.[Row]=b.[Row]+1 AND a.CaseOrdinal<b1.CaseOrdinal

	IF @SaveDetailsTableName=1
	BEGIN
		DROP TABLE IF EXISTS [WORK].causeandeffectdetails
		SELECT * INTO [WORK].causeandeffectdetails FROM #a
	END

	DROP TABLE IF EXISTS #c
	CREATE TABLE #c ([EventB] NVARCHAR(50),[Player] NVARCHAR(50),[Count] FLOAT) 
	INSERT INTO #c
		SELECT
			[EventB],
			[Player],
			CAST(COuNT(*) AS FLOAT) [Count]
		FROM
			#a
		GROUP BY
			[EventB],
			[Player]
	CREATE CLUSTERED INDEX #c_idx ON #c(EventB,Player)

	SELECT
		a.[Player],
		a.[EventB],
		a.[EventA],
		ROUND((COUNT(*)/c.[Count])*100,3) AS [PA|B],
		COUNT(*) AS [A_Int_BCount],
		c.[Count] AS BCount
	FROM
		#a a
		JOIN #c c ON a.EventB=c.EventB AND c.Player=a.Player
	GROUP BY
		a.[EventB],
		a.[EventA],
		a.Player,
		c.[Count]
	ORDER BY
		a.[Player],
		a.[EventB],
		a.[EventA]
END
GO
/****** Object:  StoredProcedure [dbo].[CreateUpdateBayesianProbabilities]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Stored Procedure": "CreateUpdateBayesianProbabilities",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-14",
  "Description": "Creates or refreshes Bayesian probability records by finding or inserting the appropriate model, invoking BayesianProbability2 to compute joint and conditional counts and probabilities for two sequences, and upserting the results into the BayesianProbabilities table.",
  "Utilization": "Use when you want to build or refresh stored Bayesian probability results rather than calculating them ad hoc every time. Helpful for caching, scheduled refresh, and downstream reporting.",
  "Input Parameters": [
    { "name": "@SeqA",                   "type": "NVARCHAR(MAX)", "default": null, "description": "CSV defining sequence A." },
    { "name": "@SeqB",                   "type": "NVARCHAR(MAX)", "default": null, "description": "CSV defining sequence B." },
    { "name": "@EventSet",               "type": "NVARCHAR(MAX)", "default": null, "description": "Optional CSV of all events; if NULL, union of SeqA and SeqB." },
    { "name": "@StartDateTime",          "type": "DATETIME",       "default": "NULL", "description": "Lower bound of event dates (defaults to 1900-01-01)." },
    { "name": "@EndDateTime",            "type": "DATETIME",       "default": "NULL", "description": "Upper bound of event dates (defaults to 2050-12-31)." },
    { "name": "@transforms",             "type": "NVARCHAR(MAX)", "default": null, "description": "Optional event-mapping JSON." },
    { "name": "@CaseFilterProperties",   "type": "NVARCHAR(MAX)", "default": null, "description": "JSON of case-level filter properties." },
    { "name": "@EventFilterProperties",  "type": "NVARCHAR(MAX)", "default": null, "description": "JSON of event-level filter properties." },
    { "name": "@GroupType",              "type": "NVARCHAR(10)",  "default": null, "description": "Grouping dimension: 'CASEID','DAY','MONTH','YEAR'." }
  ],
  "Output Notes": [
    { "name": "BayesianProbabilities table", "type": "Table", "description": "Upserted row containing ModelID, GroupType, EventSetAKey, EventSetBKey, counts and conditional probabilities." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelsByParameters",      "type": "Table-Valued Function", "description": "Resolves or inserts a Models row and returns keys." },
    { "name": "dbo.InsertModel",             "type": "Stored Procedure",       "description": "Inserts a Models record when no existing model matches." },
    { "name": "dbo.BayesianProbability2",    "type": "Stored Procedure",       "description": "Computes ACount, BCount, A_Int_BCount, PB|A, PA|B, TotalCases, PA, PB." },
    { "name": "dbo.InsertEventSets",         "type": "Stored Procedure",       "description": "Inserts or retrieves keys for event-set definitions." },
    { "name": "dbo.BayesianProbabilities",   "type": "Table",                  "description": "Destination table for joint and conditional probability metrics." }
  ]
}

Sample utilization:

	EXEC dbo.CreateUpdateBayesianProbabilities
		@SeqA = 'arrive,greeted',
		@SeqB = 'intro,order',
		@EventSet = 'restaurantguest',
		@StartDateTime = '19000101',
		@EndDateTime = '20501231',
		@transforms = NULL,
		@CaseFilterProperties = NULL,
		@EventFilterProperties = NULL,
		@GroupType = 'CASEID';

    -- Cardiology example for TIA → Holter Pos:
    EXEC dbo.CreateUpdateBayesianProbabilities
        @SeqA = 'TIA',
        @SeqB = 'Holter Pos',
        @EventSet = 'cardiology',
        @StartDateTime = NULL,
        @EndDateTime = NULL,
        @transforms = NULL,
        @CaseFilterProperties = NULL,
        @EventFilterProperties = NULL,
        @GroupType = NULL;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security, concurrency, indexing, and other operational considerations have been simplified or omitted.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/



CREATE PROCEDURE [dbo].[CreateUpdateBayesianProbabilities]
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
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DisplayResult BIT = 0;
    IF @SessionID IS NULL
    BEGIN
        SET @SessionID = NEWID();
        SET @DisplayResult = 1;
    END

    SET @CreatedBy_AccessBitmap =
        COALESCE(@CreatedBy_AccessBitmap, CAST(dbo.UserAccessBitmap() AS BIGINT));

    SET @AccessBitmap =
        COALESCE(@AccessBitmap, @CreatedBy_AccessBitmap);

    DECLARE @transformkey VARBINARY(16) = NULL;
    DECLARE @EventSetAKey VARBINARY(16) = NULL;
    DECLARE @EventSetBKey VARBINARY(16) = NULL;
    DECLARE @ModelType NVARCHAR(50) = 'BayesianProbability';
    DECLARE @EventSetKey VARBINARY(16);
    DECLARE @ModelID INT;
    DECLARE @enumerate_multiple_events INT = 1;

    SET @StartDateTime = COALESCE(@StartDateTime, '19000101');
    SET @EndDateTime = COALESCE(@EndDateTime, '20501231');

    DECLARE @ExactCaseProperties BIT = 1;

    SET @GroupType = dbo.DefaultGroupType(@GroupType);

    SELECT
        @ModelID = ModelID,
        @transformkey = transformskey,
        @EventSetKey = EventSetKey
    FROM dbo.ModelsByParameters
    (
        @EventSet,
        @enumerate_multiple_events,
        @StartDateTime,
        @EndDateTime,
        @transforms,
        NULL,
        NULL,
        @CaseFilterProperties,
        @EventFilterProperties,
        @ModelType,
        @ExactCaseProperties,
        @CreatedBy_AccessBitmap   -- FIXED
    );

    IF @ModelID IS NULL
    BEGIN
        EXEC dbo.InsertModel
             @ModelID = @ModelID OUTPUT,
             @enumerate_multiple_events = @enumerate_multiple_events,
             @EventSet = @EventSet,
             @StartDateTime = @StartDateTime,
             @EndDateTime = @EndDateTime,
             @transforms = @transforms,
             @CaseFilterProperties = @CaseFilterProperties,
             @EventFilterProperties = @EventFilterProperties,
             @transformkey = @transformkey OUTPUT,
             @EventSetKey = @EventSetKey OUTPUT,
             @ModelType = @ModelType,
             @CreatedBy_AccessBitmap = @CreatedBy_AccessBitmap, -- FIXED
             @AccessBitmap = @AccessBitmap;                     -- FIXED
    END

    DECLARE @ACount INT;
    DECLARE @BCount INT;
    DECLARE @A_Int_BCount INT;
    DECLARE @PBA FLOAT;
    DECLARE @PAB FLOAT;
    DECLARE @TotalCases INT;
    DECLARE @PA FLOAT;
    DECLARE @PB FLOAT;

    EXEC dbo.BayesianProbability2
         @SeqA,
         @SeqB,
         @EventSet,
         @StartDateTime,
         @EndDateTime,
         @transforms,
         @CaseFilterProperties,
         @EventFilterProperties,
         @GroupType,
         @SessionID;

    SELECT
        @ACount = [ACount],
        @BCount = [BCount],
        @A_Int_BCount = [A_Int_BCount],
        @PBA = [PB|A],
        @PAB = [PA|B],
        @TotalCases = [TotalCases],
        @PA = [PA],
        @PB = [PB]
    FROM WORK.BayesianProbability
    WHERE SessionID = @SessionID;

    DECLARE @EventSetIsSequence BIT = 1;

    EXEC dbo.InsertEventSets @SeqA, NULL, @EventSetAKey OUTPUT, @EventSetIsSequence;
    EXEC dbo.InsertEventSets @SeqB, NULL, @EventSetBKey OUTPUT, @EventSetIsSequence;

    MERGE dbo.BayesianProbabilities AS Target
    USING
    (
        SELECT
            @ModelID AS ModelID,
            @GroupType AS GroupType,
            @EventSetAKey AS EventSetAKey,
            @EventSetBKey AS EventSetBKey
    ) AS Source
    ON Target.ModelID = Source.ModelID
       AND Target.GroupType = Source.GroupType
       AND Target.EventSetAKey = Source.EventSetAKey
       AND Target.EventSetBKey = Source.EventSetBKey
    WHEN MATCHED THEN
        UPDATE SET
            ACount = @ACount,
            BCount = @BCount,
            A_Int_BCount = @A_Int_BCount,
            [PB|A] = @PBA,
            [PA|B] = @PAB,
            TotalCases = @TotalCases,
            PA = @PA,
            PB = @PB
    WHEN NOT MATCHED THEN
        INSERT
        (
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
            PB
        )
        VALUES
        (
            @ModelID,
            @GroupType,
            @EventSetAKey,
            @EventSetBKey,
            @ACount,
            @BCount,
            @A_Int_BCount,
            @PBA,
            @PAB,
            @TotalCases,
            @PA,
            @PB
        );

    IF @DisplayResult = 1
    BEGIN
        SELECT *
        FROM dbo.BayesianProbabilities
        WHERE ModelID = @ModelID
          AND GroupType = @GroupType
          AND EventSetAKey = @EventSetAKey
          AND EventSetBKey = @EventSetBKey;
    END
END
GO
/****** Object:  StoredProcedure [dbo].[CreateUpdateMarkovProcess]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "CreateUpdateMarkovProcess",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": [
    "Creates or refreshes a Markov process model for a given event set.",
    "Calls InsertModel to upsert Models, clears ModelEvents, invokes MarkovProcess2 to compute transition metrics into a temp table, populates ModelEvents, updates Models.DistinctCases, and—if requested—inserts detailed sequences into ModelSequences.",
    "Returns the final ModelID as a single-row result for downstream callers (e.g., pyodbc)."
  ],
  "Utilization": "Use when you want to create or refresh a stored Markov process model from current event data, especially for repeatable analysis and cacheable model generation.",
  "Input Parameters": [
    {"name":"@ModelID","type":"INT","default":"NULL","description":"OUTPUT. If NULL a new model is created; otherwise refreshes the existing ModelID."},
    {"name":"@EventSet","type":"NVARCHAR(MAX)","default":null,"description":"CSV or code defining which events to include in the model."},
    {"name":"@enumerate_multiple_events","type":"INT","default":"0","description":"0 to collapse duplicate events within a case; 1 to treat each occurrence separately; ≥2 to append occurrence counts (e.g., served1, served2)."},
    {"name":"@StartDateTime","type":"DATETIME","default":"NULL","description":"Lower date bound (defaults to 1900-01-01)."},
    {"name":"@EndDateTime","type":"DATETIME","default":"NULL","description":"Upper date bound (defaults to 2050-12-31)."},
    {"name":"@transforms","type":"NVARCHAR(MAX)","default":"NULL","description":"Optional JSON or code mapping for normalizing event names."},
    {"name":"@ByCase","type":"BIT","default":"1","description":"1 to group by CaseID; 0 to treat all events as one continuous sequence."},
    {"name":"@metric","type":"NVARCHAR(20)","default":"NULL","description":"Metric for transitions (defaults to “Time Between”)."},
    {"name":"@CaseFilterProperties","type":"NVARCHAR(MAX)","default":"NULL","description":"JSON of case-level filter key/value pairs."},
    {"name":"@EventFilterProperties","type":"NVARCHAR(MAX)","default":"NULL","description":"JSON of event-level filter key/value pairs."},
    {"name":"@InsertSequences","type":"BIT","default":"NULL","description":"1 to load detailed sequences into ModelSequences; 0 to skip (defaults to 1)."}
  ],
  "Output Notes": [
    {"name":"ModelID","type":"INT","description":"Returned as a single-row result for callers."},
    {"name":"Models","type":"Table","description":"Upserted model metadata (DistinctCases updated)."},
    {"name":"ModelEvents","type":"Table","description":"First-order transition records (EventA→EventB metrics)."},
    {"name":"ModelSequences","type":"Table","description":"Optional detailed sequence metrics when @InsertSequences=1."}
  ],
  "Referenced objects": [
    {"name":"dbo.InsertModel","type":"Stored Procedure","description":"Upserts a Models record and outputs ModelID, MetricID, transformkey, EventSetKey."},
    {"name":"dbo.MarkovProcess2","type":"Stored Procedure","description":"Computes first-order Markov transition statistics and returns them plus DistinctCases."},
    {"name":"dbo.SequenceKey","type":"Scalar Function","description":"Produces a unique key for each sequence and nextEvent pair."},
    {"name":"dbo.Sequences","type":"Table-Valued Function","description":"Generates detailed multi-event sequence metrics."},
    {"name":"dbo.Models","type":"Table","description":"Stores model metadata, including DistinctCases count."},
    {"name":"dbo.ModelEvents","type":"Table","description":"Holds computed first-order transition metrics."},
    {"name":"dbo.ModelSequences","type":"Table","description":"Holds detailed sequence records when enabled."}
  ]
}

Sample utilization:

    EXEC dbo.CreateUpdateMarkovProcess
       @ModelID = NULL OUTPUT,
       @EventSet = 'restaurantguest',
       @enumerate_multiple_events = 0,
       @StartDateTime = '19000101',
       @EndDateTime = '20501231',
       @transforms = NULL,
       @ByCase = 1,
       @metric = NULL,
       @CaseFilterProperties = NULL,
       @EventFilterProperties = NULL,
       @InsertSequences = 1;

Context:
    • Provided as-is for teaching and demonstration of Time Molecules concepts.
    • **Not** production-hardened: error handling, security, concurrency, indexing, partitioning, etc., are simplified or omitted.
    • Performance and scale tuning are out of scope—use at your own risk.
    • Accompanies “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/




CREATE PROCEDURE [dbo].[CreateUpdateMarkovProcess]
	@ModelID INT=NULL OUTPUT, -- NULL=Add new model
	@EventSet NVARCHAR(MAX),
	@enumerate_multiple_events INT=0, --2 and above - enumerate the same events, three occurances of served should be served, served1,served2
	@StartDateTime DATETIME=NULL,
	@EndDateTime DATETIME=NULL,
	@transforms NVARCHAR(MAX)=NULL,
	@ByCase BIT=1,
	@metric NVARCHAR(20)=NULL,
	@CaseFilterProperties NVARCHAR(MAX)=NULL, --key/value json of filter property values.
	@EventFilterProperties NVARCHAR(MAX)=NULL, --key/value json of filter property values.
	@InsertSequences BIT=NULL, --Sequences take time and it takes a lot of rows, so turn off if you need it fast.
	@SessionID UNIQUEIDENTIFIER=NULL,
    @CreatedBy_AccessBitmap BIGINT = NULL,
    @AccessBitmap BIGINT = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SET @CreatedBy_AccessBitmap =
        COALESCE(@CreatedBy_AccessBitmap, CAST(dbo.UserAccessBitmap() AS BIGINT));

    SET @AccessBitmap =
        COALESCE(@AccessBitmap, @CreatedBy_AccessBitmap);

	SET @ModelID=NULL
	SET @metric=COALESCE(@metric,'Time Between')
	DECLARE @MetricID INT
	DECLARE @transformkey VARBINARY(16)=NULL
	DECLARE @EventSetKey VARBINARY(16)=NULL
	DECLARE @Order INT=1 --Save 1st order markovchain into dbo.MarkovEvents
	DECLARE @ForceRefresh BIT=1
	DECLARE @ModelType NVARCHAR(50)='MarkovChain'
	SET @StartDateTime=COALESCE(@StartDateTime,'01/01/1900')
	SET @EndDateTime=COALESCE(@EndDateTime,'12/31/2050')
	SET @InsertSequences=COALESCE(@InsertSequences,1)
	DECLARE @ModelHighlights INT=1 --We CANNOT let MarkovProcess2 return more than one result set.
	SET @SessionID=COALESCE(@SessionID,NEWID())

	--The created model will have this access, and it is a property of the model.
    DECLARE @CreatedWith_AccessBitmap BIGINT=(SELECT CAST(dbo.UserAccessBitmap() AS BIGINT) AS UserAccessBitmap)


    EXEC dbo.InsertModel
         @ModelID = @ModelID OUTPUT,
         @EventSet = @EventSet,
         @enumerate_multiple_events = @enumerate_multiple_events,
         @StartDateTime = @StartDateTime,
         @EndDateTime = @EndDateTime,
         @transforms = @transforms,
         @ByCase = @ByCase,
         @metric = @metric,
         @CaseFilterProperties = @CaseFilterProperties,
         @EventFilterProperties = @EventFilterProperties,
         @MetricID = @MetricID OUTPUT,
         @transformkey = @transformkey OUTPUT,
         @eventsetkey = @eventsetkey OUTPUT,
         @order = @order,
         @ModelType = 'MarkovChain',
         @CreatedBy_AccessBitmap = @CreatedBy_AccessBitmap,
         @AccessBitmap = @AccessBitmap;

	IF @ModelID IS NOT NULL
	BEGIN
		DELETE FROM [dbo].[ModelEvents] WHERE ModelID=@ModelID
	END



	-- Execute the stored procedure
	DECLARE @DistinctCases INT
	
	EXEC dbo.MarkovProcess2 
		@Order, 
		@EventSet, 
		@enumerate_multiple_events, 
		@StartDateTime, 
		@EndDateTime, 
		@transforms, 
		@ByCase, 
		@metric, 
		@CaseFilterProperties, 
		@EventFilterProperties, 
		@DistinctCases OUTPUT,
		@ModelHighlights,
		@ModelID OUTPUT,
		@SessionID
	
	
	INSERT INTO dbo.ModelEvents
	(
		[ModelID]
		,[EventA]
		,[EventB]
		,[Max]
		,[Avg]
		,[Min]
		,[StDev]
		,[CoefVar]
		,[Rows]
		,[Prob]
		,[IsEntry]
		,[Sum]
		,[IsExit]
		,[Event2A]
		,[Event3A]
		,[OrdinalMean]
		,[OrdinalStDev]
	 )
		SELECT
			@ModelID,
			Event1A,
			EventB,
			[Max],
			[Avg],
			[Min],
			[StDev],
			[CoefVar], --Coefficient of Variation.
			[Rows],
			Prob,
			IsEntry,
			[Sum],
			IsExit,
			Event2A,
			Event3A,
			[OrdinalMean],
			[OrdinalStDev]
		FROM 
			WORK.MarkovProcess
		WHERE
			SessionId=@SessionID

	DELETE FROM WORK.MarkovProcess WHERE SessionID=@SessionID

	UPDATE dbo.Models SET
		DistinctCases=@DistinctCases
	WHERE
		ModelID=@ModelID


	--This can take a while with a large data set.
	IF @InsertSequences=1
	BEGIN

		EXEC dbo.[sp_Sequences]
			@EventSet=@EventSet,
			@enumerate_multiple_events=@enumerate_multiple_events,
			@StartDateTime=@StartDateTime,
			@EndDateTime=@EndDateTime,
			@transforms=@transforms,
			@ByCase=@ByCase,
			@metric=@metric,
			@CaseFilterProperties=@CaseFilterProperties,
			@EventFilterProperties=@EventFilterProperties,
			@ForceRefresh=@ForceRefresh,
			@SessionID=@SessionID

		INSERT INTO [dbo].[ModelSequences]
		(
			[Seq]
			,[lastEvent]
			,[nextEvent]
			,[SeqStDev]
			,[SeqMax]
			,[SeqAvg]
			,[SeqMin]
			,[SeqSum]
			,[HopStDev]
			,[HopMax]
			,[HopAvg]
			,[HopMin]
			,[TotalRows]
			,[Rows]
			,[Prob]
			,[TermRows]
			,[Cases]
			,[ModelID]
			,[SeqKey]
			,[length]
		  )
			SELECT
				[Seq]
				,[lastEvent]
				,[nextEvent]
				,[SeqStDev]
				,[SeqMax]
				,[SeqAvg]
				,[SeqMin]
				,[SeqSum]
				,[HopStDev]
				,[HopMax]
				,[HopAvg]
				,[HopMin]
				,[TotalRows]
				,[Rows]
				,[Prob]
				,[ExitRows]
				,[Cases]
				,[ModelID]
				,[dbo].[SequenceKey]([Seq],[nextEvent]) AS [SeqKey]
				,[length]
			FROM
				WORK.[Sequences] t
			WHERE
				t.SessioniD=@SessionID AND
				NOT EXISTS (SELECT ModelID,Seq FROM dbo.ModelSequences ms WHERE ms.ModelID=t.ModelID AND ms.Seq=t.Seq)

			DELETE FROM WORK.[Sequences] WHERE SessionID=@SessionID
	END

	SELECT @ModelID AS ModelID -- This is so pyodbc can get the modelid. See tm_create_model_async.py.


END
GO
/****** Object:  StoredProcedure [dbo].[DefaultModelParameters]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "dbo.DefaultModelParameters",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Initializes or returns default model parameters (date range, event enumeration, metric, and ordering) via OUTPUT parameters.",
  "Utilization": "Use when you want to populate or maintain the system’s default modeling parameters so downstream procedures behave consistently when callers omit optional settings.", 
  "Input Parameters": [
    { "name": "@StartDateTime",             "type": "DATETIME",  "default": "NULL", "description": "Lower bound of the model’s time range; defaults to 1900-01-01 if NULL." },
    { "name": "@EndDateTime",               "type": "DATETIME",  "default": "NULL", "description": "Upper bound of the model’s time range; defaults to 2050-12-31 if NULL." },
    { "name": "@Order",                     "type": "INT",       "default": "NULL", "description": "Event order (1, 2, or 3); defaults to 1 if NULL or ≤0." },
    { "name": "@enumerate_multiple_events", "type": "INT",       "default": "NULL", "description": "0 to collapse duplicate events; >0 to enumerate; defaults to 0 if NULL." },
    { "name": "@metric",                    "type": "NVARCHAR(20)","default": "NULL", "description": "Name of the metric (e.g., 'Time Between'); defaults to 'Time Between' if NULL." }
  ],
  "Output Notes": [
    { "name": "@StartDateTime",             "type": "DATETIME",  "description": "Initialized lower bound date." },
    { "name": "@EndDateTime",               "type": "DATETIME",  "description": "Initialized upper bound date." },
    { "name": "@Order",                     "type": "INT",       "description": "Validated order value." },
    { "name": "@enumerate_multiple_events", "type": "INT",       "description": "Validated enumeration flag." },
    { "name": "@metric",                    "type": "NVARCHAR(20)","description": "Validated metric name." }
  ],
  "Referenced objects": []
}


Sample utilization:
    DECLARE 
      @Start DATETIME, 
      @End DATETIME, 
      @Ord INT, 
      @Enum INT, 
      @Met NVARCHAR(20);
    EXEC dbo.DefaultModelParameters 
      @StartDateTime=@Start OUTPUT,
      @EndDateTime=@End OUTPUT,
      @Order=@Ord OUTPUT,
      @enumerate_multiple_events=@Enum OUTPUT,
      @metric=@Met OUTPUT;
    SELECT @Start, @End, @Ord, @Enum, @Met;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE PROCEDURE [dbo].[DefaultModelParameters]
@StartDateTime DATETIME OUTPUT,
@EndDateTime DATETIME OUTPUT,
@Order INT=NULL OUTPUT, -- 1, 2 or 3
@enumerate_multiple_events INT  OUTPUT,
@metric NVARCHAR(20) OUTPUT

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SET @Order=CASE WHEN COALESCE(@Order,0)<=0 THEN 1 ELSE @Order END
	SET @metric=COALESCE(@metric,'Time Between')
	SET @StartDateTime=COALESCE(@StartDateTime,'01/01/1900')
	SET @EndDateTime=COALESCE(@EndDateTime,'12/31/2050')
	SET @enumerate_multiple_events=COALESCE(@enumerate_multiple_events,0)

END
GO
/****** Object:  StoredProcedure [dbo].[DeleteCase]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "DeleteCase",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": [
    "Deletes all data associated with a given CaseID, including event facts, parsed and raw properties, case properties, and the case record itself."
  ],
  "Utilization": "Use when you need to remove a case and its related dependent data in a controlled way rather than manually deleting from multiple tables.",
  "Input Parameters": [
    {"name":"@CaseID","type":"INT","default":null,"description":"Identifier of the case to delete along with all related data."}
  ],
  "Output Notes": [
    {"name":"Affected Rows","type":"N/A","description":"Rows removed from EventPropertiesParsed, EventProperties, EventsFact, CaseProperties, CasePropertiesParsed, and Cases tables."}
  ],
  "Referenced objects": [
    {"name":"dbo.EventPropertiesParsed","type":"Table","description":"Parsed event-level properties to delete."},
    {"name":"dbo.EventProperties","type":"Table","description":"Raw event-level properties to delete."},
    {"name":"dbo.EventsFact","type":"Table","description":"Event fact records to delete."},
    {"name":"dbo.CaseProperties","type":"Table","description":"Raw case-level properties to delete."},
    {"name":"dbo.CasePropertiesParsed","type":"Table","description":"Parsed case-level properties to delete."},
    {"name":"dbo.Cases","type":"Table","description":"Case record to delete."}
  ]
}

Sample utilization:

    EXEC dbo.DeleteCase @CaseID = xxxx;

Context:
    • This procedure is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, transactions, security, and performance tuning have been simplified or omitted.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/


CREATE PROCEDURE [dbo].[DeleteCase]
@CaseID INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DELETE p
	FROM
		[dbo].[EventPropertiesParsed] p
		JOIN [dbo].[EventsFact] f ON p.EventID=f.EventID
	WHERE
		f.CaseID=@CaseID

		DELETE p
	FROM
		[dbo].[EventProperties] p
		JOIN [dbo].[EventsFact] f ON p.EventID=f.EventID
	WHERE
		f.CaseID=@CaseID

	DELETE FROM [dbo].[EventsFact] WHERE CaseID=@CaseID
	DELETE FROM [dbo].[CaseProperties] WHERE CaseID=@CaseID
	DELETE FROM [dbo].[CasePropertiesParsed] WHERE CaseID=@CaseID
	DELETE FROM [dbo].[Cases] WHERE CaseID=@CaseID

	INSERT INTO dbo.ProcErrorLog
	(
	  ProcedureName,
	  EventName,
	  PropertyName,
	  ErrorMessage,
	  LoggedAt
	)
	VALUES
	(
	  'DeleteCase',               -- ProcedureName
	  'CaseDeleted',              -- EventName
	  'CaseID',                   -- PropertyName
	  CONCAT('Deleted case ', @CaseID),  -- ErrorMessage carries the CaseID
	  GETDATE()                   -- LoggedAt
	);
END
GO
/****** Object:  StoredProcedure [dbo].[DeleteEventBatch]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "DeleteEventBatch",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": [
    "Deletes all events and related properties for the given BatchID, including fact rows, raw and parsed event properties, and any cases affected by those events (case records and their properties).",
    "Should log success or failure to ProcErrorLog with BatchID context."
  ],
  "Utilization": "Use when backing out an imported batch of events and related parsed rows, cases, and properties, especially during ETL correction, reload, or bad-batch cleanup.",
  "Input Parameters": [
    {"name":"@BatchID","type":"BIGINT","default":null,"description":"Identifier of the batch of events to delete."}
  ],
  "Output Notes": [
    {"name":"Affected Rows","type":"N/A","description":"Rows removed from EventProperties, EventPropertiesParsed, EventsFact, CaseProperties, CasePropertiesParsed, and Cases tables."}
  ],
  "Referenced objects": [
    {"name":"dbo.EventsFact","type":"Table","description":"Source of EventID and CaseID pairs for deletion."},
    {"name":"dbo.EventProperties","type":"Table","description":"Raw event property rows to delete."},
    {"name":"dbo.EventPropertiesParsed","type":"Table","description":"Parsed event property rows to delete."},
    {"name":"dbo.CaseProperties","type":"Table","description":"Raw case property rows to delete when their CaseIDs are affected."},
    {"name":"dbo.CasePropertiesParsed","type":"Table","description":"Parsed case property rows to delete when their CaseIDs are affected."},
    {"name":"dbo.Cases","type":"Table","description":"Case records to delete when their CaseIDs are affected."},
    {"name":"dbo.ProcErrorLog","type":"Table","description":"Error logging table where deletion success/failure should be recorded."}
  ]
}


Sample utilization:

    EXEC dbo.DeleteEventBatch @BatchID = 987654321;

Context:
    • Provided as-is for teaching and demonstration of the Time Molecules concepts.
    • **Not** production‐hardened: add transaction scope, TRY/CATCH, and logging to ensure consistency.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/


CREATE PROCEDURE [dbo].[DeleteEventBatch]
@BatchID BIGINT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @EventCase TABLE (EventID INT, CaseID INT, UNIQUE (EventID,CaseID))

	INSERT INTO @EventCase (EventID,CaseID)
		SELECT EventID,CaseID FROM dbo.EventsFact e WHERE BatchID=@BatchID

	DELETE FROM [dbo].[EventProperties]
	WHERE EventID IN (SELECT EventID FROM @EventCase)

	DELETE FROM [dbo].[EventPropertiesParsed]
	WHERE EventID IN (SELECT EventID FROM @EventCase)

	DELETE FROM [dbo].[EventsFact] 
	WHERE EventID IN (SELECT EventID FROM @EventCase)

	DELETE FROM [dbo].[CaseProperties] 
	WHERE CaseID IN (SELECT CaseID FROM @EventCase) 

	DELETE FROM [dbo].[CasePropertiesParsed] 
	WHERE CaseID IN (SELECT CaseID FROM @EventCase) 

	DELETE FROM [dbo].[Cases] 
	WHERE CaseID IN (SELECT CaseID FROM @EventCase) 

	INSERT INTO dbo.ProcErrorLog
	(
	  ProcedureName,
	  EventName,
	  PropertyName,
	  ErrorMessage,
	  LoggedAt
	)
	VALUES
	(
	  'DeleteEventBatch',               -- ProcedureName
	  'BatchDeleted',              -- EventName
	  'BatchID',                   -- PropertyName
	  CONCAT('Deleted batch ', @BatchID),  -- ErrorMessage carries the CaseID
	  GETDATE()                   -- LoggedAt
	);
END
GO
/****** Object:  StoredProcedure [dbo].[DeleteModel]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:

{
  "Stored Procedure": "dbo.DeleteModel",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-14",
  "Description": "Deletes a Markov model and all its associated data (stationary distribution, properties, events, sequences, similarity links) and logs the deletion event.",
  "Utilization": "Use when you want to remove a model and all of its dependent stored artifacts cleanly, especially during model regeneration, cleanup, or administrative maintenance.",
  "Input Parameters": [
    { "name": "@ModelID", "type": "INT", "default": null, "description": "Identifier of the model to delete along with all related records." }
  ],
  "Output Notes": [
    { "name": "Deleted Rows", "type": "N/A", "description": "Rows removed from Model_Stationary_Distribution, ModelProperties, ModelEvents, ModelSequences, ModelSimilarity, and Models tables." },
    { "name": "ProcErrorLog Entry", "type": "Table", "description": "A record inserted indicating the model deletion event." }
  ],
  "Referenced objects": [
    { "name": "dbo.Model_Stationary_Distribution", "type": "Table", "description": "Stores stationary probabilities for models." },
    { "name": "dbo.ModelProperties",              "type": "Table", "description": "Holds model-level property records." },
    { "name": "dbo.ModelEvents",                  "type": "Table", "description": "Contains first-order transition metrics." },
    { "name": "dbo.ModelSequences",               "type": "Table", "description": "Contains detailed sequence metrics." },
    { "name": "dbo.ModelSimilarity",              "type": "Table", "description": "Stores pairwise model similarity links." },
    { "name": "dbo.Models",                       "type": "Table", "description": "Primary model metadata table." },
    { "name": "dbo.ProcErrorLog",                 "type": "Table", "description": "Procedure error/event logging table." }
  ]
}

Sample utilization:

EXEC dbo.DeleteModel @ModelID = 42;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE PROCEDURE [dbo].[DeleteModel]
@ModelID INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;



	DELETE [dbo].[Model_Stationary_Distribution] WHERE ModelID=@ModelID
	DELETE [dbo].[ModelProperties] WHERE ModelID=@ModelID
	DELETE [dbo].[ModelEvents] WHERE ModelID=@ModelID
	DELETE [dbo].[ModelSequences] WHERE ModelID=@ModelID
	DELETE [dbo].[ModelSimilarity] WHERE ModelID1=@ModelID OR ModelID2=@ModelID
	DELETE [dbo].[Models] WHERE ModelID=@ModelID 

	INSERT INTO dbo.ProcErrorLog
	(
	  ProcedureName,
	  EventName,
	  PropertyName,
	  ErrorMessage,
	  LoggedAt
	)
	VALUES
	(
	  'DeleteModel',               -- ProcedureName
	  'ModelDeleted',              -- EventName
	  'ModeID',                   -- PropertyName
	  CONCAT('Deleted model ', @ModelID),  -- ErrorMessage carries the CaseID
	  GETDATE()  
	 )

END
GO
/****** Object:  StoredProcedure [dbo].[Generate_LLM_Description_Prompts]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "dbo.Generate_LLM_Description_Prompts",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Builds a set of natural-language prompts for various metadata objects (EventSets, Transforms, Metrics, Sources, Models, CaseTypes) to feed into an LLM for generating vector embeddings or descriptions.",
  "Utilization": "Use when you want to generate prompt text for metadata objects so they can be described, embedded, or indexed for semantic search and LLM-assisted navigation.",
  "Input Parameters": [
    { "name": "@Table", "type": "NVARCHAR(1000)", "default": null, "description": "Optional filter: only generate prompts for the specified table name." }
  ],
  "Output Notes": [
    { "name": "ID",        "type": "BIGINT",      "description": "Primary key of the source object (if applicable)." },
    { "name": "HashKey",   "type": "VARBINARY(16)", "description": "Binary key for objects keyed by hash (EventSets, Transforms)." },
    { "name": "Table",     "type": "NVARCHAR(128)", "description": "Name of the metadata table being described." },
    { "name": "Caption",   "type": "NVARCHAR(128)", "description": "Short code or caption for the object." },
    { "name": "Prompt",    "type": "NVARCHAR(2000)","description": "Generated LLM prompt text." },
    { "name": "CurrDesc",  "type": "NVARCHAR(500)", "description": "Existing description from metadata to compare or augment." }
  ],
  "Referenced objects": [
    { "name": "dbo.EventSets",                     "type": "Table",                  "description": "Defines named event-sets and their raw SQL code." },
    { "name": "dbo.CaseTypeListForEventSets",      "type": "Table-Valued Function",  "description": "Lists case types associated with each EventSet." },
    { "name": "dbo.Transforms",                    "type": "Table",                  "description": "Stores JSON transforms definitions." },
    { "name": "dbo.Metrics",                       "type": "Table",                  "description": "Lookup of metric definitions and units." },
    { "name": "dbo.Sources",                       "type": "Table",                  "description": "Registered external data sources." },
    { "name": "dbo.SourceColumns",                 "type": "Table",                  "description": "Columns metadata for each source." },
    { "name": "dbo.Models",                        "type": "Table",                  "description": "Stored Markov/Bayesian model definitions." },
    { "name": "dbo.GetModelPropertyString",        "type": "Scalar Function",        "description": "Concatenates model properties for display." },
    { "name": "dbo.GetModelEventString",           "type": "Scalar Function",        "description": "Concatenates model transitions into a single string." },
    { "name": "dbo.CaseTypes",                     "type": "Table",                  "description": "Master list of case-type names." },
    { "name": "dbo.EventsFact",                    "type": "Table",                  "description": "Fact table of event occurrences." },
    { "name": "dbo.Cases",                         "type": "Table",                  "description": "Master list of cases." }
  ]
}
Sample utilization:

    EXEC dbo.Generate_LLM_Description_Prompts;            -- Generate prompts for all metadata tables
    EXEC dbo.Generate_LLM_Description_Prompts @Table='Models';  -- Only for Models table

Context:
    • This procedure is intended to automate prompt creation for LLM-based embedding generation.
    • It pulls captions, descriptions, and key values from core metadata tables.
    • Not production-hardened: no paging, error handling, or schema-change resilience has been added.
    • Use at your own risk and adjust prompt templates to suit your LLM’s token limits and style.

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/



CREATE PROCEDURE [dbo].[Generate_LLM_Description_Prompts]

@Table NVARCHAR(1000)=NULL
AS
BEGIN
	SET NOCOUNT ON 

	DECLARE @Prompts TABLE (
		[ID] BIGINT NULL,
		[HashKey] VARBINARY(16),
		[Table] NVARCHAR(128),
		[Caption] NVARCHAR(128),
		[Prompt] NVARCHAR(2000),
		[CurrDesc] NVARCHAR(500)
	)
	DECLARE @EmbeddingLength VARCHAR(10)='150' --The perfect length for embeddings can vary. 100-200 is usual.
	DECLARE @OneHundredWords NVARCHAR(100)='In '+@EmbeddingLength+' words or less, summarize for the purpose of generating useful vector embeddings: '
	DECLARE @LeaveOutWarnings NVARCHAR(100)=' Please omit any alternatives and cautionary advice.'


	INSERT INTO @Prompts ([ID],[HashKey],[Caption],[Table],[Prompt],[CurrDesc])
		SELECT
			NULL AS [ID],
			es.EventSetKey AS [HashKey],
			es.[EventSetCode] AS [Caption],
			'EventSets' AS [Table],
			@OneHundredWords+
			'Event Set: '+es.EventSet+
			CASE WHEN es.EventSetCode IS NULL THEN '' ELSE ', Code: '+es.EventSetCode END+
			', Used for these Case Type: {'+ct.CaseTypeList+'}'+
			@LeaveOutWarnings AS [Prompt],
			es.[Description]
		FROM
			[dbo].[EventSets] es
			JOIN dbo.CaseTypeListForEventSets() ct ON ct.EventSetKey=es.EventSetKey

	INSERT INTO @Prompts ([ID],[HashKey],[Caption],[Table],[Prompt],[CurrDesc])
		SELECT
			NULL AS [ID],
			[transformskey] AS [HashKey],
			[Code] AS [Caption],
			'Transforms' AS [Table],
			@OneHundredWords+'these event mappings: '+[transforms]+@LeaveOutWarnings AS [Prompt],
			[Description]
		FROM
			[dbo].[Transforms]

	INSERT INTO @Prompts ([ID],[HashKey],[Caption],[Table],[Prompt],[CurrDesc])
		SELECT
			MetricID AS [ID],
			NULL AS [HashKey],
			[Metric] AS Caption,
			'Metrics' AS [Table],
			@OneHundredWords+' metric named '+Metric+' with unit of measurement '+ Uom+@LeaveOutWarnings AS [Prompt],
			[Description]
		FROM
			[dbo].[Metrics]

	INSERT INTO @Prompts ([ID],[HashKey],[Caption],[Table],[Prompt],[CurrDesc])
		SELECT
			s.SourceID AS [ID],
			NULL AS [HashKey],
			[Name] AS Caption,
			'Sources' AS [Table],
			@OneHundredWords+
			' of this source named '+[Name]+
			(CASE WHEN SourceProperties IS NOT NULL THEN ' with these properties'+SourceProperties ELSE '' END)+
			', with these columns: {'+STRING_AGG(sc.ColumnName,',')+'}'+
			@LeaveOutWarnings AS [Prompt],
			s.[Description]
		FROM
			[dbo].[Sources] s
			JOIN [dbo].[SourceColumns] sc ON sc.SourceID=s.SourceID
		GROUP BY
			s.SourceID,
			[Name],SourceProperties,
			s.[Description]

	INSERT INTO @Prompts ([ID],[HashKey],[Caption],[Table],[Prompt],[CurrDesc])
		SELECT
			sc.SourceColumnID AS [ID],
			NULL AS [HashKey],
			CASE WHEN sc.TableName IS NOT NULL THEN +sc.TableName+'.' ELSE '' END +sc.ColumnName AS Caption,
			'SourceColumns' AS [Table],
			@OneHundredWords+
			' of this source column named '+CASE WHEN sc.TableName IS NOT NULL THEN +sc.TableName+'.' ELSE '' END +sc.ColumnName +
			', '+CASE WHEN sc.DataType IS NOT NULL THEN 'Data Type: '+sc.DataType ELSE '' END+
			', '+CASE WHEN sc.IsKey=1 THEN 'It is the Table Key ' ELSE '' END+
			@LeaveOutWarnings AS [Prompt],
			sc.[Description]
		FROM
			[dbo].[Sources] s
			JOIN [dbo].[SourceColumns] sc ON sc.SourceID=s.SourceID


	INSERT INTO @Prompts ([ID],[HashKey],[Caption],[Table],[Prompt],[CurrDesc])
		SELECT
			m.Modelid AS [ID],
			NULL AS [HashKey],
			NULL AS [Caption],
			'Models' AS [Table],
			'In '+@EmbeddingLength+' words or less, for the purpose of creating useful embeddings, what is this Markov model, properties ('+
			COALESCE(dbo.GetModelPropertyString(m.ModelID),'')+
			') about: '+dbo.GetModelEventString(m.ModelID) 
			AS [Prompt],
			m.[Description]
		FROM
			[dbo].[Models] m


	INSERT INTO @Prompts ([ID],[HashKey],[Caption],[Table],[Prompt],[CurrDesc])
		SELECT
			ct.CaseTypeID AS [ID],
			NULL AS [HashKey],
			ct.[Name] AS [Caption],
			'CaseTypes' AS [Table],
			@OneHundredWords+', CaseType: '+ct.[Name]+' associated with these events: {'+STRING_AGG([Event],',')+'}'+@LeaveOutWarnings AS [Prompt],
			ct.[Description]
		FROM
			[dbo].[CaseTypes] ct
			JOIN (
				SELECT DISTINCT
					CaseTypeID,
					[Event],
					COUNT(*) AS [Count]
				FROM
					[dbo].[EventsFact] f
					JOIN [dbo].[Cases] c ON c.CaseID=f.CaseID
				GROUP BY
					CaseTypeID,
					[Event]
			) e ON e.CaseTypeID=ct.CaseTypeID
		GROUP BY
			ct.CaseTypeID,
			ct.[Name],
			ct.[Description]



	SELECT * FROM @Prompts ORDER BY [Table],[HashKey],[ID]


END


GO
/****** Object:  StoredProcedure [dbo].[get_semantic_web_llm_values]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "dbo.get_semantic_web_llm_values",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Dynamically discovers all tables with Description and IRI columns (plus optional EventsFact entries), and returns a unified result set of object name, type, description, IRI, code column name, and code value for semantic-web and LLM embedding purposes. Usefull for setting up 'Time Molecules skills'. See dbo.getTimeMoleculesObjectMetadata() for sprocs, tvf, and udfs.",
  "Utilization": "Use when exporting or preparing Time Molecules metadata values for embeddings, semantic search, or LLM-oriented catalog generation.",
  "Input Parameters": [
    { "name": "@IncludeEventsAndCases", "type": "BIT", "default": "0", "description": "1 to include EventsFact rows with their properties as additional entries; 0 to skip them." }
  ],
  "Output Notes": [
    { "name": "ObjectName",  "type": "NVARCHAR(500)", "description": "Schema-qualified table, view, procedure, function, or dimension object name." },
    { "name": "Type",        "type": "NVARCHAR(50)",  "description": "Object category: Table, Column, View, or Table Row for dynamic entries." },
    { "name": "Description", "type": "NVARCHAR(MAX)", "description": "Text description or embedding-prompt fragment." },
    { "name": "IRI",         "type": "NVARCHAR(1000)","description": "Linked data IRI, if present." },
    { "name": "CodeColumn",  "type": "NVARCHAR(128)", "description": "Name of the column holding the code/key." },
    { "name": "Code",        "type": "NVARCHAR(50)",  "description": "Value of the code/key for the row." }
  ],
  "Referenced objects": [
    { "name": "sys.tables",                   "type": "System View",               "description": "Catalog of user tables." },
    { "name": "sys.columns",                  "type": "System View",               "description": "Catalog of table and view columns." },
    { "name": "sys.extended_properties",      "type": "System View",               "description": "Stores MS_Description and other metadata." },
    { "name": "sys.views",                    "type": "System View",               "description": "Catalog of view definitions." },
    { "name": "sys.objects",                  "type": "System View",               "description": "Catalog of all schema-scoped objects." },
    { "name": "sys.sql_modules",              "type": "System View",               "description": "Definition text of programmable objects." },
    { "name": "EventsFact",                   "type": "User Table",                "description": "Fact table of event occurrences." },
    { "name": "EventProperties",              "type": "User Table",                "description": "Raw event-level properties." },
    { "name": "EventSets",                    "type": "User Table",                "description": "Defines named event-set codes and descriptions." },
    { "name": "Sources",                      "type": "User Table",                "description": "Registered external data sources and metadata." },
    { "name": "SourceColumns",                "type": "User Table",                "description": "Columns metadata for each source." }
  ]
}
Sample utilization:

    EXEC dbo.get_semantic_web_llm_values;          -- default, hides EventsFact
    EXEC dbo.get_semantic_web_llm_values 1;        -- include EventsFact entries

Context:
    • Builds a uniform metadata extract for generating LLM prompts or semantic-web feeds.
    • Not production-hardened: dynamic SQL, cursor usage, and missing error handling.
    • Use at your own risk and adjust object filters or schema-specific cases as needed.

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/





CREATE PROCEDURE [dbo].[get_semantic_web_llm_values] 
@IncludeEventsAndCases BIT=0,
@FilterBlankDescriptions BIT=1

AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @AllAccess BIGINT=-1

	DROP TABLE IF EXISTS #tmp
	CREATE TABLE #tmp
	(
		ObjectName NVARCHAR(500),
		[ObjectType] NVARCHAR(50),
		[Description] NVARCHAR(MAX),
		[Utilization] NVARCHAR(MAX) NULL,
		[IRI] NVARCHAR(1000) NULL,
		[CodeColumn] NVARCHAR(128) NULL,
		[Code] NVARCHAR(50) NULL,
		[AccessBitmap] BIGINT
	)
	DECLARE @sql NVARCHAR(MAX) = N'';  -- To hold the dynamic SQL statement

	IF @IncludeEventsAndCases=1
	BEGIN
		SET @sql = 
		'SELECT ''EventsFact'' AS TableName, ''EventID'' AS CodeColumn,CAST(f.EventID AS NVARCHAR(20)) AS Code, ep.ActualProperties AS [Description], NULL AS [IRI] 
		 FROM EventsFact f LEFT JOIN [dbo].[EventProperties] ep ON ep.EventID=f.EventID WHERE ep.ActualProperties IS NOT NULL UNION ALL '

	END

	-- Declare cursor to iterate through tables with Description and IRI columns
	--Some dimensions might be parent-child, in which case we can get taxonomies.
	DECLARE table_cursor CURSOR FOR
	SELECT s.name+'.'+ t.name AS TableName, c.name AS CodeColumn, p.[name] AS ParentID
	FROM 
		sys.tables t
		JOIN sys.columns c ON t.object_id = c.object_id	-- "Code" column.
		JOIN sys.columns d ON t.object_id = d.object_id	-- "Description" column.
		JOIN sys.columns i ON t.object_id = i.object_id	-- IRI column.
		LEFT JOIN sys.schemas s ON t.schema_id=s.schema_id
		LEFT JOIN sys.columns p ON t.object_id = p.object_id AND p.[name] LIKE 'Parent%'
	WHERE 
		(d.[name] = 'Description' AND d.system_type_id IN (231,167))
		AND i.name = 'IRI'
		AND (c.max_length IN (20,40,50) or c.max_length=100)
		AND t.[name] NOT IN ('Transforms','Models','DimEvents','SourceColumns','Sources','TimeSolutionsMetadata','Users') --These are handled separately below. 
		AND s.name NOT IN ('WORK','STAGE')

	-- Iterate over the cursor and build dynamic SQL for each table
	OPEN table_cursor;
	DECLARE @TableName NVARCHAR(128), @CodeColumn NVARCHAR(128), @ParentColumn NVARCHAR(128)
	DECLARE @Description NVARCHAR(200)
	DECLARE @FromClause NVARCHAR(200)

	FETCH NEXT FROM table_cursor INTO @TableName, @CodeColumn, @ParentColumn

	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- Build dynamic SQL for each table
		SET @Description=
			CASE
				WHEN @TableName='EventSets' THEN 'COALESCE(t.[Description],'''')+ '' Events: ''+t.[EventSet]'
				WHEN @TableName='SourceColumns' THEN 'COALESCE(t.[Description],'''')+ '' Source: ''+COALESCE(s.ServerName,'''')+''.''+COALESCE(s.DatabaseName,'''')'
			ELSE 't.[Description]'
		END
		SET @FromClause=
			@TableName+' t '+
			CASE 
				WHEN @TableName='SourceColumns' THEN 'JOIN Sources s ON s.SourceID=t.SourceID'
				ELSE ''
		END

		SET @sql = @sql + 
		'SELECT ' +
			'''' + @TableName + ''' + 
				CASE 
					WHEN t.' + QUOTENAME(@CodeColumn) + ' IS NOT NULL 
					THEN ''.'' + CAST(t.' + QUOTENAME(@CodeColumn) + ' AS NVARCHAR(4000))
					ELSE ''''
				END AS ObjectName,
			''Instance'' AS [ObjectType], ' +
			@Description + ',
			t.[IRI], ' +
			'''' + @CodeColumn + ''' AS CodeColumn,
			t.' + QUOTENAME(@CodeColumn) + ' AS Code
		 FROM ' + @FromClause + ' UNION ALL ';

		FETCH NEXT FROM table_cursor INTO @TableName, @CodeColumn, @ParentColumn;
	END;

	-- Close and deallocate cursor
	CLOSE table_cursor;
	DEALLOCATE table_cursor;

	IF LEN(COALESCE(@SQL, '')) > 0
	BEGIN
		SET @sql = LEFT(@sql, LEN(@sql) - LEN(' UNION ALL'));  -- Removing trailing 'UNION ALL'

		-- Insert results of the dynamic SQL into #tmp
		INSERT INTO #tmp (ObjectName, [ObjectType], [Description], IRI, CodeColumn, Code)
		EXEC sp_executesql @sql;
	END

	-- Retrieve table descriptions
	INSERT INTO #tmp (ObjectName,[ObjectType],[Description])
		SELECT 
			s.name+'.'+obj.name AS ObjectName,
			'Table' AS [ObjectType],
			s.name+'.'+obj.name+'.'+
			COALESCE(CAST(ep.value AS NVARCHAR(MAX)),'') + ' Columns: '+
			ISNULL(
				'[' + STRING_AGG( c.name , ',') + ']',
				'[]'
			)
			AS [Description]
		FROM 
			sys.tables AS obj
			JOIN sys.schemas s ON s.schema_id=obj.schema_id
			INNER JOIN  sys.columns c ON obj.object_id = c.object_id
		LEFT JOIN sys.extended_properties AS ep ON 
				ep.major_id = obj.object_id 
				AND ep.minor_id = 0 
				AND ep.name = 'MS_Description'
				AND ep.class=1
		GROUP BY
			s.[name],
			obj.[name],
			ep.[value]

	-- Retrieve column descriptions
	INSERT INTO #tmp (ObjectName,[ObjectType],[Description])
		SELECT 
			tbl.name+'.'+col.[name] AS ObjectName,
			'Column' AS [ObjectType],
			tbl.name+'.'+col.[name]+'. '+
			CAST(ep.value AS NVARCHAR(MAX))  AS Description
		FROM 
			sys.columns AS col
		INNER JOIN 
			sys.tables AS tbl ON col.object_id = tbl.object_id
		LEFT JOIN 
			sys.extended_properties AS ep 
		ON 
			ep.major_id = col.object_id 
			AND ep.minor_id = col.column_id 
			AND ep.name = 'MS_Description'
			AND ep.class = 1  -- class=1 refers to tables




	IF NOT EXISTS (SELECT * FROM #tmp WHERE ObjectName='Models' AND [ObjectType]='Table')
	BEGIN
	INSERT INTO #tmp (ObjectName,[ObjectType],[Description],AccessBitmap)
		SELECT 
			'Model.'+CAST(m.ModelID AS VARCHAR(10)) AS ObjectName,
			'Instance' AS [ObjectType],
			LEFT(
				'Cached Markov Model'+
				CASE
					WHEN m.[Description] IS NULL THEN 
						'--Metric: '+met.Metric+
						'--Event Set: '+COALESCE(es.EventSet,'None')
					ELSE
						'--'+m.[Description]
				END+
				'--Transforms: '+COALESCE(t.transforms,'None')+
				'--Case Filters: '+COALESCE(m.CaseFilterProperties,'None')
				,4000
			) AS [Description],
			m.AccessBitmap
		FROM
			[dbo].[Models] m
			JOIN [dbo].[Metrics] met ON met.MetricID=m.MetricID
			LEFT JOIN [dbo].[Transforms] t ON t.transformskey=m.transformskey
			LEFT JOIN EventSets es ON es.EventSetKey=m.EventSetKey
	END

	IF NOT EXISTS (SELECT * FROM #tmp WHERE ObjectName='DimEvents' AND [ObjectType]='Table')
	BEGIN
	INSERT INTO #tmp (ObjectName,[ObjectType],[Description],[IRI],[CodeColumn],[Code])
		SELECT 
			'EventType.'+e.[Event] AS ObjectName,
			'Instance' AS [ObjectType],
			LEFT(
				COALESCE(e.[Description],'Event Set')+
				'--Code:'+COALESCE(e.[Event],'None')
				,4000
			) AS [Description],
			e.IRI AS [IRI],
			'Event' AS [CodeColumn],
			e.[Event] AS [Code]
		FROM
			[dbo].[DimEvents] e
	END

	IF NOT EXISTS (SELECT * FROM #tmp WHERE ObjectName='EventSets' AND [ObjectType]='Table')
	BEGIN
	INSERT INTO #tmp (ObjectName,[ObjectType],[Description],[IRI],[CodeColumn],[Code])
		SELECT 
			'Event Set.'+COALESCE(es.EventSetCode,'CodeNotSet') AS ObjectName,
			'Instance' AS [ObjectType],
			LEFT(
				COALESCE(es.[Description],'Event Set')+
				'--Code:'+COALESCE(es.EventSetCode,'None')+
				'--Event Set:'+es.EventSet
				,4000
			) AS [Description],
			es.IRI AS [IRI],
			'EventSetCode',
			es.EventSetCode
		FROM
			[dbo].[EventSets] es
	END



	IF NOT EXISTS (SELECT * FROM #tmp WHERE ObjectName='Transforms' AND [ObjectType]='Table')
	BEGIN
	INSERT INTO #tmp (ObjectName,[ObjectType],[Description],[CodeColumn],[Code])
		SELECT 
			'EventTransform.'+COALESCE(t.Code,'CodeNotSet') AS ObjectName,
			'Instance' AS [ObjectType],
			COALESCE(t.[Description], 'Event from-to: '+t.transforms) AS [Description],
			'Code',
			t.Code
		FROM
			dbo.Transforms t
	END


	IF NOT EXISTS (SELECT * FROM #tmp WHERE ObjectName='SourceColumns' AND [ObjectType]='Table')
	BEGIN
	INSERT INTO #tmp (ObjectName,[ObjectType],[Description],[IRI],[CodeColumn],[Code],AccessBitmap)
		SELECT 
			'Souce Column.'+COALESCE(sc.ColumnName,'NameNotSet') AS ObjectName,
			'Instance' AS [ObjectType],
			LEFT(
				COALESCE(sc.[Description],'Source Column')
				+'--Code:'
				+COALESCE(s.DatabaseName,'UnknownDB')+'.'
				+COALESCE(sc.TableName,'UnknownTable')+'.'
				+COALESCE(sc.ColumnName,'UnknownColumn')
				,4000
			) AS [Description],
			sc.IRI AS [IRI],
			'Database.Source.Table.Column',
			LEFT(COALESCE(s.DatabaseName,'UnknownDB')+'.'+COALESCE(sc.TableName,'UnknownTable')+'.'+COALESCE(sc.ColumnName,'UnknownColumn'),50),
			s.AccessBitmap
		FROM
			[dbo].[SourceColumns] sc
			LEFT JOIN [Sources] s ON sc.SourceID=s.SourceID
	END

	truncate table WORK.semantic_web_llm_values 
	insert into WORK.semantic_web_llm_values
	(
		[ObjectName]
		,[ObjectType]
		,[Description]
		,[Utilization]
		,[IRI]
		,[CodeColumn]
		,[Code]
		,[AccessBitmap]
	 )
	select
		[ObjectName]
		,[ObjectType]
		,[Description]
		,[Utilization]
		,[IRI]
		,[CodeColumn]
		,[Code]
		,COALESCE([AccessBitmap],@AllAccess)
		from #tmp 
	WHERE 
		@FilterBlankDescriptions=0 OR [Description] IS NOT NULL 
	order by [ObjectType],[ObjectName]
END
GO
/****** Object:  StoredProcedure [dbo].[ImportEventsFromStage]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "dbo.ImportEventsFromStage",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-04-11",
  "Description": "Imports staged event rows into the TimeSolution event ensemble beginning at an optional import date threshold. Resolves source context, applies user access defaults, and loads core event-level structures used later for property parsing, process analysis, and Markov model creation.",
  "Utilization": "Use as the main ETL entry point for moving rows from STAGE into the core Time Molecules event ensemble. This is the procedure to run after stage tables have been populated and you want the imported events to become available for downstream case/event analysis, parsed properties, drill-through, and model generation.",
  "Input Parameters": [
    { "name": "@ImportFromDate", "type": "DATETIME", "default": "NULL", "description": "Optional lower-bound date for staged rows to import. NULL means import according to the procedure's normal logic without a date filter." }
  ],
  "Output Notes": [
    { "name": "Imported events", "type": "Table Update", "description": "Loads staged event rows into the core event ensemble tables." },
    { "name": "Access handling", "type": "Security Behavior", "description": "Uses the current user's access bitmap and no-access defaults during import processing." },
    { "name": "Status / diagnostics", "type": "Runtime behavior", "description": "The procedure declares message and procedure-name variables for import logging or status reporting as part of execution." }
  ],
  "Referenced objects": [
    { "name": "STAGE schema", "type": "Schema", "description": "Holds staging tables that serve as the source for event import." },
    { "name": "dbo.Users", "type": "Table", "description": "Provides user context and access bitmap information used during import security handling." },
    { "name": "dbo.UserAccessBitmap", "type": "Scalar Function", "description": "Returns the current user's access bitmap for import-time security logic." },
    { "name": "dbo.Sources", "type": "Table", "description": "Provides source-system metadata, including the Unknown source fallback used by the procedure." },
    { "name": "Event ensemble tables", "type": "Table Group", "description": "Target TimeSolution tables populated by the import process for later property parsing and model generation." }
  ]
}

Sample utilization:

    EXEC dbo.ImportEventsFromStage;

    EXEC dbo.ImportEventsFromStage
        @ImportFromDate = '2026-01-01';

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2026 Eugene Asahara. All rights reserved.

Notes:
    • This procedure is part of the ETL path from staged data into the core event ensemble.
    • Imported rows are intended to become available for downstream parsing, filtering, drill-through, and Markov model creation.
*/

CREATE PROCEDURE [dbo].[ImportEventsFromStage]
    @ImportFromDate DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ProcedureName NVARCHAR(128) = OBJECT_NAME(@@PROCID);
    DECLARE @Message NVARCHAR(4000);

    DECLARE @NoAccessDefault BIGINT = 0; --Default to noaccess.
    DECLARE @UserAccessBitmap BIGINT = (SELECT CAST(dbo.UserAccessBitmap() AS BIGINT));
    DECLARE @UnknownSourceID INT = (SELECT SourceID FROM dbo.Sources WHERE [Name] = 'Unknown');

    DECLARE @DefaultCaseTypeID INT =
    (
        SELECT ct.CaseTypeID
        FROM dbo.CaseTypes ct
        WHERE ct.[Name] = 'Unknown'
    );

    IF @DefaultCaseTypeID IS NULL
    BEGIN
        SET @Message = 'Import failed setup: CaseTypes.Name = ''Unknown'' was not found';
        EXEC dbo.utility_LogProcError
            @ProcedureName = @ProcedureName,
            @EventName = 'Import',
            @PropertyName = 'Setup Failed',
            @ErrorMessage = @Message;
        RETURN;
    END

    IF @UnknownSourceID IS NULL
    BEGIN
        SET @Message = 'Import failed setup: Sources.Name = ''Unknown'' was not found';
        EXEC dbo.utility_LogProcError
            @ProcedureName = @ProcedureName,
            @EventName = 'Import',
            @PropertyName = 'Setup Failed',
            @ErrorMessage = @Message;
        RETURN;
    END

    SET @ImportFromDate =
        COALESCE(
            @ImportFromDate,
            (SELECT MAX(EventDate) FROM dbo.EventsFact)
        );

    /*
    Start of import validation.
    */
    DECLARE @VB_EventLenOver50                    INT = 1;    -- 1
    DECLARE @VB_CasePropertiesNotJSON             INT = 2;    -- 2
    DECLARE @VB_InvalidSourceID                   INT = 4;    -- 4
    DECLARE @VB_EventActualPropertiesNotJSON      INT = 8;    -- 8
    DECLARE @VB_CaseIDLenOver200                  INT = 16;   -- 16
    DECLARE @VB_CaseTargetPropertiesNotJSON       INT = 32;   -- 32
    DECLARE @VB_EventExpectedPropertiesNotJSON    INT = 64;   -- 64
    DECLARE @VB_EventAggregationPropertiesNotJSON INT = 128;  -- 128
    DECLARE @VB_EventIntendedPropertiesNotJSON    INT = 256;  -- 256
    DECLARE @VB_EventDateNotDateTime              INT = 512;  -- 512
    DECLARE @VB_EventDescriptionLenOver200        INT = 1024; -- 1024

    ;WITH v AS
    (
        SELECT
            i.ImportEventID,
            NewValidationBitmap =
                  CASE WHEN LEN(i.[Event]) > 50 THEN @VB_EventLenOver50 ELSE 0 END
                | CASE WHEN i.CaseProperties IS NOT NULL AND ISJSON(i.CaseProperties) = 0 THEN @VB_CasePropertiesNotJSON ELSE 0 END
                | CASE WHEN NOT EXISTS
                    (
                        SELECT 1
                        FROM dbo.Sources s
                        WHERE s.SourceID = i.SourceID
                    )
                    THEN @VB_InvalidSourceID ELSE 0 END
                | CASE WHEN i.EventActualProperties IS NOT NULL AND ISJSON(i.EventActualProperties) = 0 THEN @VB_EventActualPropertiesNotJSON ELSE 0 END
                | CASE WHEN LEN(i.[CaseID]) > 200 THEN @VB_CaseIDLenOver200 ELSE 0 END
                | CASE WHEN i.CaseTargetProperties IS NOT NULL AND ISJSON(i.CaseTargetProperties) = 0 THEN @VB_CaseTargetPropertiesNotJSON ELSE 0 END
                | CASE WHEN i.EventExpectedProperties IS NOT NULL AND ISJSON(i.EventExpectedProperties) = 0 THEN @VB_EventExpectedPropertiesNotJSON ELSE 0 END
                | CASE WHEN i.EventAggregationProperties IS NOT NULL AND ISJSON(i.EventAggregationProperties) = 0 THEN @VB_EventAggregationPropertiesNotJSON ELSE 0 END
                | CASE WHEN i.EventIntendedProperties IS NOT NULL AND ISJSON(i.EventIntendedProperties) = 0 THEN @VB_EventIntendedPropertiesNotJSON ELSE 0 END
                | CASE WHEN TRY_CAST(i.[EventDate] AS DATETIME) IS NULL THEN @VB_EventDateNotDateTime ELSE 0 END
                | CASE WHEN i.[EventDescription] IS NOT NULL AND LEN(i.[EventDescription]) > 200 THEN @VB_EventDescriptionLenOver200 ELSE 0 END
        FROM STAGE.ImportEvents i
        WHERE i.DateAdded > @ImportFromDate
    )
    UPDATE i
    SET i.ValidationBitmap = v.NewValidationBitmap
    FROM STAGE.ImportEvents i
    JOIN v
        ON v.ImportEventID = i.ImportEventID
    WHERE ISNULL(i.ValidationBitmap, -1) <> v.NewValidationBitmap;

    IF EXISTS
    (
        SELECT 1
        FROM STAGE.ImportEvents i
        WHERE i.DateAdded > @ImportFromDate
          AND ISNULL(i.ValidationBitmap, 0) <> 0
    )
    BEGIN
        SET @Message = 'Import failed validation';
        EXEC dbo.utility_LogProcError
            @ProcedureName = @ProcedureName,
            @EventName = 'Import',
            @PropertyName = 'Validation Failed',
            @ErrorMessage = @Message;
        RETURN;
    END
    /*
    End of validation.
    */

    INSERT INTO [dbo].[DimEvents]
        ([Event],[Description])
        SELECT DISTINCT
            [Event],
            --In case any Event have multiple descriptions.
            MAX(COALESCE([EventDescription],[Event])) AS [EventDescription]
        FROM
            STAGE.ImportEvents i
        WHERE
            i.DateAdded > @ImportFromDate
            AND NOT EXISTS (SELECT * FROM [dbo].[DimEvents] d WHERE d.[Event]=i.[Event])
        GROUP BY
            i.[Event];

    SET @Message='Imported '+CAST(@@Rowcount AS VARCHAR(10))+' event types';
    EXEC dbo.utility_LogProcError
        @ProcedureName = @ProcedureName,
        @EventName = 'Import',
        @PropertyName = 'Event Types',
        @ErrorMessage = @Message;

    DECLARE @BatchID INT =
    (
        SELECT ISNULL(MAX(BatchID), 0) + 1
        FROM dbo.EventsFact
    );

    DECLARE @MaxCaseID INT =
    (
        SELECT ISNULL(MAX(CaseID), 0)
        FROM dbo.Cases
    );

	DECLARE @BatchCaseMsg NVARCHAR(100)=CONCAT('Batch: ',CAST(@BatchID AS VARCHAR(20)),', Starting CaseID: ',CAST(@MaxCaseID AS VARCHAR(20)))

    /*
        Case map:
        STAGE.ImportEvents.CaseID is treated as the natural key coming from stage.
        We create fresh numeric CaseIDs for this import batch.
    */
    DECLARE @CaseMap TABLE
    (
        NaturalKey NVARCHAR(200) NOT NULL PRIMARY KEY,
        SurrCaseID INT NOT NULL UNIQUE,
        SourceID INT NULL,
        AccessBitmap BIGINT NULL,
        CaseProperties NVARCHAR(MAX) NULL,
        CaseTargetProperties NVARCHAR(MAX) NULL,
        CaseType NVARCHAR(50)
    );

    INSERT INTO @CaseMap
    (
        NaturalKey,
        SurrCaseID,
        SourceID,
        AccessBitmap,
        CaseProperties,
        CaseTargetProperties,
        CaseType
    )
    SELECT
        CAST(x.CaseID AS NVARCHAR(200)) AS NaturalKey,
        @MaxCaseID + ROW_NUMBER() OVER (ORDER BY CAST(x.CaseID AS NVARCHAR(200))) AS SurrCaseID,
        MAX(x.SourceID) AS SourceID,
        MAX(x.AccessBitmap) AS AccessBitmap,
        MAX(x.CaseProperties) AS CaseProperties,
        MAX(x.CaseTargetProperties) AS CaseTargetProperties,
        MAX(x.CaseType) AS CaseType
    FROM STAGE.ImportEvents x
    WHERE x.DateAdded > @ImportFromDate
    GROUP BY
        CAST(x.CaseID AS NVARCHAR(200));

    INSERT INTO dbo.Cases
    (
        CaseID,
        CaseTypeID,
        SourceID,
        AccessBitmap,
        BatchID,
        NaturalKey
    )
    SELECT
        cm.SurrCaseID,
        COALESCE(ct.CaseTypeID,@DefaultCaseTypeID) AS CaseTypeID,
        COALESCE(cm.SourceID,@UnknownSourceID) AS SourceID,
        COALESCE(cm.AccessBitmap, @NoAccessDefault) AS AccessBitmap,
        @BatchID,
        cm.NaturalKey
    FROM
        @CaseMap cm
        LEFT JOIN [dbo].[CaseTypes] ct (NOLOCK) ON ct.[Name]=cm.CaseType;

    SET @Message='Imported '+CAST(@@Rowcount AS VARCHAR(10))+' cases. '+@BatchCaseMsg
    EXEC dbo.utility_LogProcError
        @ProcedureName = @ProcedureName,
        @EventName = 'Import',
        @PropertyName = 'Cases',
        @ErrorMessage = @Message;

    INSERT INTO dbo.CaseProperties
    (
        CaseID,
        Properties,
        TargetProperties
    )
    SELECT
        cm.SurrCaseID,
        cm.CaseProperties,
        cm.CaseTargetProperties
    FROM @CaseMap cm
    WHERE
        (
            cm.CaseProperties IS NOT NULL OR
            cm.CaseTargetProperties IS NOT NULL
        );

    SET @Message='Imported '+CAST(@@Rowcount AS VARCHAR(10))+' case property rows. '+@BatchCaseMsg
    EXEC dbo.utility_LogProcError
        @ProcedureName = @ProcedureName,
        @EventName = 'Import',
        @PropertyName = 'CaseProperty rows',
        @ErrorMessage = @Message;

    /*
        Insert EventsFact
        CaseOrdinal is recalculated inside each staged natural key / new CaseID.
    */
    INSERT INTO dbo.EventsFact
    (
        CaseID,
        [Event],
        [EventDate],
        [SourceID],
        [CaseOrdinal],
        [BatchID],
        AccessBitmap
    )
    SELECT
        cm.SurrCaseID,
        imp.[Event],
        CAST(imp.[EventDate] AS DATETIME) AS EventDate,
        imp.SourceID,
        ROW_NUMBER() OVER
        (
            PARTITION BY cm.SurrCaseID
            ORDER BY imp.[EventDate], imp.[Event]
        ) AS CaseOrdinal,
        @BatchID AS BatchID,
        --Default access to the user context.
        COALESCE(imp.AccessBitmap, @UserAccessBitmap) AS AccessBitmap
    FROM STAGE.ImportEvents imp
    JOIN @CaseMap cm
        ON cm.NaturalKey = CAST(imp.CaseID AS NVARCHAR(200))
    WHERE imp.DateAdded > @ImportFromDate;

    SET @Message='Imported '+CAST(@@Rowcount AS VARCHAR(10))+' events. '+@BatchCaseMsg
    EXEC dbo.utility_LogProcError
        @ProcedureName = @ProcedureName,
        @EventName = 'Import',
        @PropertyName = 'Event rows',
        @ErrorMessage = @Message;

    /*
        Insert EventProperties
        We link staged property JSON to the EventID rows we just inserted
        by joining on BatchID + remapped CaseID + event/date/source.
        This assumes staged rows are distinct enough on those fields.
    */
    INSERT INTO dbo.EventProperties
    (
        EventID,
        ActualProperties,
        ExpectedProperties,
        AggregationProperties,
        IntendedProperties,
        CreateDate,
        LastUpdated
    )
    SELECT
        ef.EventID,
        imp.EventActualProperties AS ActualProperties,
        imp.EventExpectedProperties AS ExpectedProperties,
        imp.EventAggregationProperties AS AggregationProperties,
        imp.EventIntendedProperties AS IntendedProperties,
        GETDATE(),
        GETDATE()
    FROM STAGE.ImportEvents imp
    JOIN @CaseMap cm
        ON cm.NaturalKey = CAST(imp.CaseID AS NVARCHAR(200))
    JOIN dbo.EventsFact ef
        ON ef.BatchID = @BatchID
       AND ef.CaseID = cm.SurrCaseID
       AND ef.[Event] = imp.[Event]
       AND ef.[EventDate] = CAST(imp.[EventDate] AS DATETIME)
       AND ef.SourceID = imp.SourceID
    WHERE imp.DateAdded > @ImportFromDate
      AND
      (
            imp.EventActualProperties IS NOT NULL
         OR imp.EventExpectedProperties IS NOT NULL
         OR imp.EventAggregationProperties IS NOT NULL
         OR imp.EventIntendedProperties IS NOT NULL
      );

    --[Todo] Very heavy-handed update. will fix later.
    EXEC dbo.UpdateCaseFromEvents @CaseID = NULL;
    EXEC [dbo].[InsertCaseProperties] @CompleteRefresh=1; --1 means to truncate CasePropertiesParsed
    EXEC [dbo].[InsertEventProperties] @CompleteRefresh=1;
END
GO
/****** Object:  StoredProcedure [dbo].[InsertCase]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Stored Procedure": "dbo.InsertCase",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Inserts a new case into the Cases table, auto-generating CaseID if not provided, validating CaseTypeName and SourceID, and setting date range and access bitmap.",
  "Utilization": "Use when adding a case record in a standardized way, especially when event ingestion or ETL logic needs the case created before related properties or events are inserted.",
  "Input Parameters": [
    { "name": "@CaseID",          "type": "INT",      "default": "NULL",         "description": "OUTPUT. If NULL, a new CaseID is generated; otherwise must not already exist." },
    { "name": "@CaseTypeName",    "type": "NVARCHAR(50)","default": "NULL",       "description": "Name of the case type; must exist in CaseTypes." },
    { "name": "@StartDateTime",   "type": "DATETIME",  "default": "1900-01-01",   "description": "Case start date (inclusive)." },
    { "name": "@EndDateTime",     "type": "DATETIME",  "default": "2050-12-30",   "description": "Case end date (inclusive)." },
    { "name": "@AccessBitMap",    "type": "BIGINT",    "default": "-1",           "description": "Access bitmap flags; -1 grants all by default." },
    { "name": "@SourceID",        "type": "INT",      "default": "NULL",         "description": "Identifier of the data source; must exist in Sources." }
  ],
  "Output Notes": [
    { "name": "Cases",            "type": "Table",    "description": "New row inserted into Cases with the specified values." },
    { "name": "PRINT Message",    "type": "N/A",       "description": "Confirmation message with the inserted CaseID." }
  ],
  "Referenced objects": [
    { "name": "dbo.CaseTypes",    "type": "Table",     "description": "Lookup table for validating CaseTypeName to CaseTypeID." },
    { "name": "dbo.Sources",      "type": "Table",     "description": "Lookup table for validating SourceID." },
    { "name": "dbo.Cases",        "type": "Table",     "description": "Destination table for inserting new case records." }
  ]
}

Sample utilization:

    DECLARE @NewCaseID INT;
    EXEC dbo.InsertCase 
        @CaseID = @NewCaseID OUTPUT,
        @CaseTypeName = 'ExampleCase',
        @StartDateTime = '2024-09-27',
        @EndDateTime = '2024-09-30',
        @AccessBitMap = 0,
        @SourceID = 3;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: lacks transaction handling, concurrency safeguards, and detailed error reporting.
    • Use at your own risk and adjust validations or defaults as needed.

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/


CREATE PROCEDURE [dbo].[InsertCase]
@CaseID INT OUTPUT,
@CaseTypeName NVARCHAR(50)=NULL,
@StartDateTime DATETIME='1900-01-01',
@EndDateTime DATETIME='2050-12-30',
@AccessBitMap BIGINT=-1, --This means all, but be careful!
@SourceID INT
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from interfering with SELECT statements.
    SET NOCOUNT ON;

    -- Check if CaseTypeName exists and retrieve CaseTypeID
    DECLARE @CaseTypeID INT=(SELECT CaseTypeID FROM [dbo].[CaseTypes] WHERE [Name]=@CaseTypeName)
    
    IF @CaseTypeID IS NULL
    BEGIN
        -- If the case type is not found, raise an error
        RAISERROR('Invalid CaseTypeName: %s', 16, 1, @CaseTypeName)
        RETURN
    END

    -- Check if CaseypeName exists and retrieve CaseTypeID
    IF NOT EXISTS (SELECT SourceID FROM [dbo].[Sources] WHERE [SourceID]=@SourceID)
       BEGIN
        -- If the case type is not found, raise an error
        RAISERROR('Invalid SourceID: %d', 16, 1, @SourceID)
        RETURN
    END
    IF @CaseTypeID IS NULL
    BEGIN
        -- If the case type is not found, raise an error
        RAISERROR('Invalid CaseTypeName: %s', 16, 1, @CaseTypeName)
        RETURN
    END

    -- Check if CaseID is provided
    IF @CaseID IS NULL
    BEGIN
        -- Auto-generate CaseID if not provided
        SELECT @CaseID = ISNULL(MAX(CaseID), 0) + 1 FROM [dbo].[Cases]
    END
    ELSE
    BEGIN
        -- Check if the CaseID already exists
        IF EXISTS (SELECT CaseID FROM [dbo].[Cases] WHERE CaseID=@CaseID)
        BEGIN
            -- Raise error if the CaseID already exists
            RAISERROR('CaseID %d already exists in the Cases table.', 16, 1, @CaseID)
            RETURN
        END
    END

    -- Insert the new case
    INSERT INTO [dbo].[Cases] (CaseID, CaseTypeID, StartDateTime, EndDateTime, AccessBitmap,SourceID)
    VALUES (@CaseID, @CaseTypeID, @StartDateTime, @EndDateTime, @AccessBitMap,@SourceID)

    -- Confirm successful insertion
	INSERT INTO dbo.ProcErrorLog
	(
	  ProcedureName,
	  EventName,
	  PropertyName,
	  ErrorMessage,
	  ID
	)
	VALUES
	(
	  OBJECT_NAME(@@PROCID),            -- ProcedureName
	  'CaseInserted',              
	  'CaseID',                   -- PropertyName
	  CONCAT('Case Inserted ', @CaseID), 
	  @CaseID
	 )
    PRINT 'Case inserted successfully with CaseID ' + CAST(@CaseID AS NVARCHAR)

END
GO
/****** Object:  StoredProcedure [dbo].[InsertCaseProperties]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



/*
Metadata JSON:
{
  "Stored Procedure": "dbo.InsertCaseProperties",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-03-25",
  "Description": "Parses JSON case-level properties from dbo.CaseProperties, maps them to source columns when possible, applies default MDM overrides from dbo.CasePropertiesMDM, and inserts the results into dbo.CasePropertiesParsed. Supports full refresh or selective refresh by CaseID.",
  "Utilization": "Use when case property bags are stored as JSON and need to be parsed into structured rows for filtering, joins, reporting, or downstream model logic.",
  "Input Parameters": [
    {
      "name": "@CompleteRefresh",
      "type": "BIT",
      "default": "0",
      "description": "If 1 and @CaseID is NULL, truncates dbo.CasePropertiesParsed before rebuilding. If 1 and @CaseID is provided, reprocesses that case even if parsed rows already exist."
    },
    {
      "name": "@CaseID",
      "type": "INT",
      "default": "NULL",
      "description": "Optional CaseID filter. NULL means process all eligible cases."
    }
  ],
  "Output Notes": [
    {
      "name": "CaseID",
      "type": "INT",
      "description": "Identifier of the case whose properties were parsed."
    },
    {
      "name": "PropertyName",
      "type": "NVARCHAR",
      "description": "Name of the property key extracted from the JSON in dbo.CaseProperties.Properties."
    },
    {
      "name": "PropertyValueAlpha",
      "type": "NVARCHAR",
      "description": "Text value of the property when the JSON value is not numeric, optionally overridden by dbo.CasePropertiesMDM."
    },
    {
      "name": "PropertyValueNumeric",
      "type": "FLOAT",
      "description": "Numeric value of the property when the JSON value is numeric, optionally overridden by dbo.CasePropertiesMDM."
    },
    {
      "name": "SourceColumnID",
      "type": "INT",
      "description": "SourceColumns.SourceColumnID matched by property name and the case's SourceID, if found."
    },
    {
      "name": "StartDateTime",
      "type": "DATETIME",
      "description": "Case start datetime copied from dbo.Cases."
    },
    {
      "name": "EndDateTime",
      "type": "DATETIME",
      "description": "Case end datetime copied from dbo.Cases."
    }
  ],
  "Referenced objects": [
    {
      "name": "dbo.CaseProperties",
      "type": "Table",
      "description": "Stores JSON property bags for cases."
    },
    {
      "name": "dbo.Cases",
      "type": "Table",
      "description": "Supplies SourceID, StartDateTime, and EndDateTime for each case."
    },
    {
      "name": "dbo.SourceColumns",
      "type": "Table",
      "description": "Used to map property names to SourceColumnID values for the case's source."
    },
    {
      "name": "dbo.CasePropertiesParsed",
      "type": "Table",
      "description": "Target table populated with parsed case properties."
    },
    {
      "name": "dbo.CasePropertiesMDM",
      "type": "Table",
      "description": "Provides default MDM-standardized overrides for parsed property values."
    }
  ]
}

Sample utilization:

EXEC [InsertCaseProperties] 1
*/
CREATE PROCEDURE [dbo].[InsertCaseProperties]
@CompleteRefresh BIT=0,
@CaseID INT=NULL	--NULL means do all cases.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @DefaultVersionID INT=-1

	IF @CompleteRefresh=1 AND @CaseID IS NULL
	BEGIN
		TRUNCATE TABLE [dbo].[CasePropertiesParsed]
	END
;
	WITH t AS
	(
		SELECT
			CaseID,
			p.[key] AS PropertyName,
			CASE 
				WHEN ISNUMERIC(p.[value])=0 THEN p.[value]
				ELSE NULL
			END AS PropertyValueAlpha,
			CASE
				WHEN ISNUMERIC(p.[value])=1 THEN CAST(p.[value] AS FLOAT)
				ELSE NULL
			END AS PropertyValueNumeric,
			(
				SELECT TOP 1
					sc.SourceColumnID
				FROM
					[dbo].[SourceColumns] sc
				WHERE
					sc.ColumnName COLLATE SQL_Latin1_General_CP1_CI_AS = p.[key] COLLATE SQL_Latin1_General_CP1_CI_AS  
					AND sc.SourceID=c.SourceID
			) AS SourceColumnID,
			c.StartDateTime,
			c.EndDateTime,
			c.AccessBitmap
		FROM
			(
				SELECT
					cp.CaseID,
					cp.Properties,
					c.SourceID,
					c.StartDateTime,
					c.EndDateTime,
					c.AccessBitmap
				FROM
					[dbo].[CaseProperties] cp
					JOIN dbo.[Cases] c ON c.CaseID=cp.CaseID
				WHERE
					(@CaseID IS NULL OR c.CaseID=@CaseID) AND
					(cp.Properties IS NOT NULL AND ISJSON(cp.Properties)=1)
					AND (@CompleteRefresh=1 OR NOT EXISTS (SELECT * FROM [dbo].[CasePropertiesParsed] cp1 WHERE cp.CaseID=cp1.CaseID))
			) c
		CROSS APPLY OPENJSON(c.Properties) AS p
		WHERE
			p.[value] IS NOT NULL
	)
	INSERT INTO [dbo].[CasePropertiesParsed] (CaseID, PropertyName, PropertyValueAlpha,PropertyValueNumeric,SourceColumnID,StartDateTime,EndDateTime,AccessBitmap)
	SELECT
		t.CaseID,
		t.PropertyName,
		CASE WHEN cm.PropertyValueAlpha IS NULL THEN t.PropertyValueAlpha ELSE cm.PropertyValueAlpha END,
		CASE WHEN cm.PropertyValueNumeric IS NULL THEN t.PropertyValueNumeric ELSE cm.PropertyValueNumeric END,
		t.SourceColumnID,
		t.StartDateTime,
		t.EndDateTime,
		COALESCE(sc.AccessBitmap, t.AccessBitmap) AS AccessBitmap --Favor the source column id restriction over the case's.
	FROM
		t
		LEFT JOIN SourceColumns sc oN sc.SourceColumnID=t.SourceColumnID
		LEFT JOIN [dbo].[CasePropertiesMDM] cm ON 
			cm.MDMVersionID = @DefaultVersionID AND
			cm.SourceColumnID=t.SourceColumnID AND 
			cm.PropertyName COLLATE SQL_Latin1_General_CP1_CI_AS  =t.PropertyName COLLATE SQL_Latin1_General_CP1_CI_AS 
END
GO
/****** Object:  StoredProcedure [dbo].[InsertEvent]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
"Stored Procedure": "InsertEvent",
"Author": "Eugene Asahara", 
"Contact": "eugene@softcodedlogic.com",
"Last Update": "05-28-2025",
"Description": "Adds a new event to the DimEvents table only if the event name does not already exist. This ensures that event names are unique across the dimension table, and stores optional metadata including description, JSON properties, and an IRI.",
"Utilization": "Use when inserting events through a standard database entry point rather than direct table writes, especially when you want consistent handling of event metadata and linked case information.",
"Input Parameters": [
  {"name": "@Event", "type": "NVARCHAR(20)", "default value": "NULL", "description": "The name of the event. Must be unique in DimEvents."},
  {"name": "@Description", "type": "NVARCHAR(500)", "default value": "NULL", "description": "Free-text description of the event."},
  {"name": "@Properties", "type": "NVARCHAR(MAX)", "default value": "NULL", "description": "Optional JSON-encoded string representing metadata for the event."},
  {"name": "@IRI", "type": "NVARCHAR(500)", "default value": "NULL", "description": "Optional IRI (Internationalized Resource Identifier) for semantic linkage."}
],
"Output Notes": [],
"Referenced objects": [
  {"name": "dbo.DimEvents", "type": "Table", "description": "Event dimension table holding event metadata including name, description, properties, and IRI."}
]
}

Sample utilization:

    EXEC dbo.InsertEvent 
         @Event = 'appointmentconfirmed',
         @Description = 'Customer confirmed appointment via SMS',
         @Properties = '{"channel":"sms"}',
         @IRI = 'http://example.org/event/appointmentconfirmed';

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE PROCEDURE [dbo].[InsertEvent]
@Event NVARCHAR(50),
@Description NVARCHAR(500),
@Properties NVARCHAR(MAX),
@IRI NVARCHAR(500)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	IF NOT EXISTS (SELECT [Event] fROM [dbo].[DimEvents] WHERE [Event]=@Event)
	BEGIN
		INSERT INTO DimEvents ([Event], [Description], [Properties],IRI)
			VALUES (@Event, @Description, @Properties, @IRI)
	END
END
GO
/****** Object:  StoredProcedure [dbo].[InsertEventProperties]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
"Stored Procedure": "InsertEventProperties",
"Author": "Eugene Asahara", 
"Contact": "eugene@softcodedlogic.com",
"Last Update": "05-28-2025",
"Description": "Parses and extracts key-value property pairs from JSON-formatted ActualProperties and ExpectedProperties in the EventProperties table and inserts them into EventPropertiesParsed, mapping to SourceColumns when possible. If @CompleteRefresh is 1, the table is truncated before insert.",
"Utilization": "Use when raw event property payloads need to be parsed and materialized into structured event-property rows for downstream filtering and analysis.",
"Input Parameters": [
  {"name": "@CompleteRefresh", "type": "BIT", "default value": "0", "description": "Set to 1 to clear EventPropertiesParsed before repopulating. Defaults to 0 for incremental insert."}
],
"Output Notes": [],
"Referenced objects": [
  {"name": "dbo.EventProperties", "type": "Table", "description": "Source of JSON-formatted property data per event."},
  {"name": "dbo.EventPropertiesParsed", "type": "Table", "description": "Stores parsed and typed property data by event and source column."},
  {"name": "dbo.EventsFact", "type": "Table", "description": "Fact table that links EventID to SourceID."},
  {"name": "dbo.SourceColumns", "type": "Table", "description": "Metadata table describing columns by SourceID for property linkage."}
]
}

Sample utilization:

    EXEC dbo.InsertEventProperties @CompleteRefresh = 1;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE PROCEDURE [dbo].[InsertEventProperties]
@CompleteRefresh BIT=0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @ActualProperties TINYINT=0
	DECLARE @ExpectedProperties TINYINT=1
	DECLARE @AggregationProperties TINYINT=2
	IF @CompleteRefresh=1
	BEGIN
		TRUNCATE TABLE [dbo].[EventPropertiesParsed]
	END

	INSERT INTO [dbo].[EventPropertiesParsed] (EventID, PropertyName, PropertyValueAlpha,PropertyValueNumeric,[IsJSON],PropertySource, SourceColumnID,EventPropertyCountAllocation,EventDate,[Event],CaseID,AccessBitmap)
		SELECT
			EventID,
			p.[key] AS PropertyName,
			CASE 
				WHEN ISNUMERIC(p.[value])=0 THEN CAST(p.[value] AS NVARCHAR(1000))
				ELSE NULL
			END AS PropertyValueAlpha,
			CASE
				WHEN ISNUMERIC(p.[value])=1 THEN CAST(p.[value] AS FLOAT)
				ELSE NULL
			END AS PropertyValueNumeric,
			IsJSON(p.[value]) AS [IsJSON],
			@ActualProperties,
			(
				SELECT TOP 1
					sc.SourceColumnID
				FROM
					[dbo].[SourceColumns] sc
				WHERE
					sc.ColumnName COLLATE Latin1_General_BIN2 = p.[key] COLLATE Latin1_General_BIN2
					AND sc.SourceID=e.SourceID
			) AS SourceColumnID,
			--EventPropertyCountAllocation and EventDate are added so we could avoid query-time join
			--between EventPropertiesParsed and EventFacts.
			1.0/(COUNT(*) OVER (PARTITION BY e.EventID)) AS EventPropertyCountAllocation,
			e.EventDate,
			e.[Event],
			e.CaseID,
			e.AccessBitmap	--EventsFact should have inherited from Cases table.
		FROM
			(
				SELECT
					e.EventID,
					ef.EventDate,
					ef.[Event],
					e.ActualProperties,
					ef.SourceID,
					ef.CaseID,
					ef.AccessBitmap
				FROM
					[dbo].[EventProperties] e
					JOIN dbo.EventsFact ef ON ef.EventID=e.EventID
				WHERE
					(e.ActualProperties IS NOT NULL AND ISJSON(e.ActualProperties)=1)
					AND (@CompleteRefresh=1 OR NOT EXISTS (SELECT ep.EventID FROM [dbo].[EventPropertiesParsed] ep WHERE ep.EventID=e.EventID))
					AND len(e.ActualProperties)<=1000 -- PropertyValueAlpha NVARCHAR(1000)
			) e
			CROSS APPLY OPENJSON(e.ActualProperties) p 
		WHERE
			p.[value] IS NOT NULL

	INSERT INTO [dbo].[EventPropertiesParsed] (EventID, PropertyName, PropertyValueAlpha,PropertyValueNumeric,[IsJSON],PropertySource, SourceColumnID,EventPropertyCountAllocation,EventDate,[Event],CaseID,AccessBitmap)
		SELECT
			EventID,
			p.[key] AS PropertyName,
			CASE 
				WHEN ISNUMERIC(p.[value])=0 THEN p.[value]
				ELSE NULL
			END AS PropertyValueAlpha,
			CASE
				WHEN ISNUMERIC(p.[value])=1 THEN CAST(p.[value] AS FLOAT)
				ELSE NULL
			END AS PropertyValueNumeric,
			IsJSON(p.[value]) AS [IsJSON],
			@ExpectedProperties,
			(
				SELECT TOP 1
					sc.SourceColumnID
				FROM
					[dbo].[SourceColumns] sc
				WHERE
					sc.ColumnName COLLATE Latin1_General_BIN2 = p.[key] COLLATE Latin1_General_BIN2
					AND sc.SourceID=e.SourceID
			) AS SourceColumnID,
			--EventPropertyCountAllocation and EventDate are added so we could avoid query-time join
			--between EventPropertiesParsed and EventFacts.
			1.0/(COUNT(*) OVER (PARTITION BY e.EventID)) AS EventPropertyCountAllocation,
			e.EventDate,
			e.[Event],
			e.CaseID,
			e.AccessBitmap
		FROM
			(
				SELECT
					e.EventID,
					ef.EventDate,
					ef.[Event],
					e.ExpectedProperties,
					ef.SourceID,
					ef.CaseID,
					ef.AccessBitmap
				FROM
					[dbo].[EventProperties] e
					JOIN dbo.EventsFact ef ON ef.EventID=e.EventID
				WHERE
					(e.ExpectedProperties IS NOT NULL AND ISJSON(e.ExpectedProperties)=1)
					AND (@CompleteRefresh=1 OR NOT EXISTS (SELECT ep.EventID FROM [dbo].[EventPropertiesParsed] ep WHERE ep.EventID=e.EventID))
					AND len(e.ExpectedProperties)<=1000 -- PropertyValueAlpha NVARCHAR(1000)
			) e
			CROSS APPLY OPENJSON(e.ExpectedProperties) p 
		WHERE
			p.[value] IS NOT NULL

END
GO
/****** Object:  StoredProcedure [dbo].[InsertEventSets]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
	"Stored Procedure": "InsertEventSets",
	"Author": "Eugene Asahara", 
	"Contact": "eugene@softcodedlogic.com",
	"Last Update": "05-28-2025",
	"Description": "Creates or updates an event set in the EventSets table. An event set is a comma-delimited list of events, which can optionally represent a sequence. If an EventSetCode exists, the set is updated; otherwise, a new row is inserted, using a hashed EventSetKey. Handles deduplication logic based on EventSetKey and optional sequence mode.",
    "Utilization": "Use when loading or registering named event sets and sequences so they can be reused consistently across models, filters, and analytical functions.",
	"Input Parameters": [
	  {"name": "@EventSet", "type": "NVARCHAR(MAX)", "default value": "NULL", "description": "Comma-delimited string of event names."},
	  {"name": "@EventSetCode", "type": "NVARCHAR(20)", "default value": "NULL", "description": "Optional user-friendly identifier for the event set."},
	  {"name": "@EventSetKey", "type": "VARBINARY(16)", "default value": "NULL", "description": "Output key derived from hashing the event set and sequence flag."},
	  {"name": "@IsSequence", "type": "BIT", "default value": "NULL", "description": "Indicates whether the event set should be treated as a sequence (1) or a set (0). Defaults to 0."}
	],
	"Output Notes": [
	  {"name": "@EventSetKey", "type": "VARBINARY(16)", "description": "Hashed representation of the event set and sequence mode, used as a key for uniqueness."}
	],
	"Referenced objects": [
	  {"name": "dbo.EventSets", "type": "Table", "description": "Stores all defined event sets or sequences with metadata like key, code, type, and length."},
	  {"name": "dbo.EventSetKey", "type": "Scalar Function", "description": "Generates a unique key from an event set string and IsSequence flag."},
	  {"name": "dbo.UserID", "type": "Scalar Function", "description": "Returns the UserID of the caller; defaults to a system user if NULL."}
	]
}


Notes:
    EventSetCode should be unique. But I didn't place a unique index on it because it might not have a code at the beginning.

Sample utilization:

    DECLARE @EventSetKey VARBINARY(16);
    EXEC dbo.InsertEventSets 
         @EventSet = 'walkin,seated,order,served,paid',
         @EventSetCode = 'mealproc',
         @EventSetKey = @EventSetKey OUTPUT,
         @IsSequence = 1;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE PROCEDURE [dbo].[InsertEventSets]
    @EventSet NVARCHAR(MAX),
    @EventSetCode NVARCHAR(20),
    @EventSetKey VARBINARY(16) OUTPUT,
    @IsSequence BIT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @IsSequence = COALESCE(@IsSequence, 0); -- Default to 0 (set)

    IF @EventSet IS NOT NULL
    BEGIN
        -- Calculate EventSetKey
        SET @EventSetKey = [dbo].[EventSetKey](@EventSet, @IsSequence);
        DECLARE @length INT = (SELECT COUNT(*) FROM STRING_SPLIT(@EventSet, ','));

        IF @EventSetCode IS NOT NULL AND EXISTS (
            SELECT 1
            FROM [dbo].[EventSets]
            WHERE EventSetCode = @EventSetCode AND IsSequence = @IsSequence
        )
        BEGIN
            -- Update existing EventSet (EventSetKey match)
            UPDATE [dbo].[EventSets]
            SET EventSet = @EventSet,
                EventSetKey = @EventSetKey,
                [Length] = @length,
				LastUpdate=GETDATE()
            WHERE EventSetCode = @EventSetCode AND IsSequence = @IsSequence;
			RETURN
        END

        IF NOT EXISTS (
            SELECT 1
            FROM [dbo].[EventSets]
            WHERE EventSetKey = @EventSetKey AND IsSequence = @IsSequence
        )
        BEGIN
            -- Insert new row
            INSERT INTO [dbo].[EventSets]
            (EventSetKey, EventSet, EventSetCode, IsSequence, CreatedByUserID, [Length])
            VALUES
            (@EventSetKey, @EventSet, @EventSetCode, @IsSequence, dbo.UserID(NULL), @length);
        END
    END
END
GO
/****** Object:  StoredProcedure [dbo].[InsertModel]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
	"Stored Procedure": "InsertModel",
	"Author": "Eugene Asahara", 
	"Contact": "eugene@softcodedlogic.com",
	"Last Update": "05-28-2025",
	"Description": "Inserts or updates a model definition in the Models table based on parameters including event set, metric, case/event filters, and transformations. Generates a unique ParamHash to identify distinct model configurations, handles model deduplication, and populates ModelProperties with parsed case- and event-level properties.",
    "Utilization": "Use when persisting a newly defined model and its associated metadata rather than leaving the model as a purely ad hoc query result.",
	"Input Parameters": [
	  {"name": "@ModelID", "type": "INT", "default value": "NULL", "description": "Optional input/output parameter. If NULL, a new model is created. If provided, updates the model with the given ID."},
	  {"name": "@EventSet", "type": "NVARCHAR(MAX)", "default value": "NULL", "description": "Comma-delimited list of events for the model definition."},
	  {"name": "@enumerate_multiple_events", "type": "INT", "default value": "0", "description": "Specifies whether to allow multiple events per time unit."},
	  {"name": "@StartDateTime", "type": "DATETIME", "default value": "NULL", "description": "Inclusive start of the modeling time window."},
	  {"name": "@EndDateTime", "type": "DATETIME", "default value": "NULL", "description": "Inclusive end of the modeling time window."},
	  {"name": "@transforms", "type": "NVARCHAR(MAX)", "default value": "NULL", "description": "Optional JSON string describing event transformations."},
	  {"name": "@ByCase", "type": "BIT", "default value": "NULL", "description": "Whether the model operates on a per-case basis. Defaults to 1."},
	  {"name": "@metric", "type": "NVARCHAR(20)", "default value": "NULL", "description": "The name of the metric to use, defaulting to 'Time Between'."},
	  {"name": "@CaseFilterProperties", "type": "NVARCHAR(MAX)", "default value": "NULL", "description": "Optional JSON string defining filters applied at the case level."},
	  {"name": "@EventFilterProperties", "type": "NVARCHAR(MAX)", "default value": "NULL", "description": "Optional JSON string defining filters applied at the event level."},
	  {"name": "@MetricID", "type": "INT", "default value": "NULL", "description": "Output parameter set to the ID of the specified metric."},
	  {"name": "@transformkey", "type": "VARBINARY(16)", "default value": "NULL", "description": "Output parameter returning the MD5 key of the transforms JSON."},
	  {"name": "@eventsetkey", "type": "VARBINARY(16)", "default value": "NULL", "description": "Output parameter returning the MD5 key of the event set."},
	  {"name": "@order", "type": "INT", "default value": "NULL", "description": "Order of the Markov model (e.g., 1 for first order). Defaults to 1."},
	  {"name": "@ModelType", "type": "NVARCHAR(50)", "default value": "NULL", "description": "Type of model being defined, defaulting to 'MarkovChain'."}
	],
	"Output Notes": [
	  {"name": "@ModelID", "type": "INT", "description": "Returns the ModelID of the newly inserted or updated model."},
	  {"name": "@MetricID", "type": "INT", "description": "Returns the ID of the selected metric."},
	  {"name": "@transformkey", "type": "VARBINARY(16)", "description": "Hashed key generated from transforms JSON."},
	  {"name": "@eventsetkey", "type": "VARBINARY(16)", "description": "Hashed key generated from the event set."}
	],
	"Referenced objects": [
	  {"name": "dbo.Metrics", "type": "Table", "description": "Maps metric names to MetricIDs."},
	  {"name": "dbo.Transforms", "type": "Table", "description": "Stores unique sets of event transforms keyed by MD5 hash."},
	  {"name": "dbo.EventSets", "type": "Table", "description": "Stores defined sets of events for use in models."},
	  {"name": "dbo.Models", "type": "Table", "description": "Holds metadata defining each model configuration."},
	  {"name": "dbo.ModelProperties", "type": "Table", "description": "Stores parsed filter properties for each model, either at case or event level."},
	  {"name": "dbo.UserAccessBitmap", "type": "Scalar Function", "description": "Returns the access bitmap for the current user context."},
	  {"name": "dbo.UserID", "type": "Scalar Function", "description": "Returns the user ID of the caller or default if NULL."},
	  {"name": "dbo.TransformsKey", "type": "Scalar Function", "description": "Computes a hash key from a transforms JSON string."},
	  {"name": "dbo.SortKeyValueJSON", "type": "Scalar Function", "description": "Sorts a JSON object by key to ensure stable hashing."},
	  {"name": "dbo.InsertEventSets", "type": "Stored Procedure", "description": "Creates or updates a row in EventSets and outputs the corresponding key."},
	  {"name": "dbo.ModelsByParameters", "type": "Table-Valued Function", "description": "Returns existing models matching specified parameters to avoid duplicates."}
	]
}

Sample utilization:

    DECLARE @ModelID INT;
    DECLARE @EventSetKey VARBINARY(16), @TransformKey VARBINARY(16), @MetricID INT;
    EXEC dbo.InsertModel 
        @ModelID = @ModelID OUTPUT,
        @EventSet = 'walkin,seated,order,paid',
        @enumerate_multiple_events = 0,
        @StartDateTime = '2022-01-01',
        @EndDateTime = '2022-12-31',
        @transforms = NULL,
        @ByCase = 1,
        @metric = 'Time Between',
        @CaseFilterProperties = '{"location":"store123"}',
        @EventFilterProperties = NULL,
        @MetricID = @MetricID OUTPUT,
        @transformkey = @TransformKey OUTPUT,
        @eventsetkey = @EventSetKey OUTPUT,
        @order = 1,
        @ModelType = 'MarkovChain';

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/


CREATE PROCEDURE [dbo].[InsertModel]
    @ModelID INT OUTPUT, -- NULL=Add new model
    @EventSet NVARCHAR(MAX),
    @enumerate_multiple_events INT = 0,
    @StartDateTime DATETIME,
    @EndDateTime DATETIME,
    @transforms NVARCHAR(MAX),
    @ByCase BIT = NULL,
    @metric NVARCHAR(20) = NULL,
    @CaseFilterProperties NVARCHAR(MAX),
    @EventFilterProperties NVARCHAR(MAX),
    @MetricID INT = NULL OUTPUT,
    @transformkey VARBINARY(16) OUTPUT,
    @eventsetkey VARBINARY(16) OUTPUT,
    @order INT = NULL,
    @ModelType NVARCHAR(50),
    @CreatedBy_AccessBitmap BIGINT = NULL,
    @AccessBitmap BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @metric = COALESCE(@metric, 'Time Between');
    SET @MetricID = (SELECT MetricID FROM dbo.Metrics WHERE Metric = @metric);
    SET @order = COALESCE(@order, 1);
    SET @ModelType = COALESCE(@ModelType, 'MarkovChain');
    SET @ByCase = COALESCE(@ByCase, 1);

    SET @CreatedBy_AccessBitmap =
        COALESCE(@CreatedBy_AccessBitmap, CAST(dbo.UserAccessBitmap() AS BIGINT));

    SET @AccessBitmap =
        COALESCE(@AccessBitmap, @CreatedBy_AccessBitmap);

    DECLARE @EventSetIsSequence BIT = 0;

    IF @transforms IS NOT NULL
    BEGIN
        SET @transformkey = dbo.TransformsKey(@transforms);

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Transforms
            WHERE transformskey = @transformkey
        )
        BEGIN
            INSERT INTO dbo.Transforms (transformskey, transforms)
            VALUES (@transformkey, @transforms);
        END
    END

    EXEC dbo.InsertEventSets
         @EventSet,
         NULL,
         @eventsetkey OUTPUT,
         @EventSetIsSequence;

    DECLARE @ExactCasePropertiesMatch BIT = 1;

    DECLARE @ExistsModelID INT =
    (
        SELECT TOP 1 ModelID
        FROM dbo.ModelsByParameters
        (
            @EventSet,
            @enumerate_multiple_events,
            @StartDateTime,
            @EndDateTime,
            @transforms,
            @ByCase,
            @metric,
            @CaseFilterProperties,
            @EventFilterProperties,
            @ModelType,
            @ExactCasePropertiesMatch,
            @CreatedBy_AccessBitmap
        )
    );

    IF COALESCE(@ExistsModelID, -999) <> COALESCE(@ModelID, -999)
    BEGIN
        SET @ModelID = @ExistsModelID;
        RETURN;
    END

    DECLARE @sortedTransforms NVARCHAR(MAX) = dbo.SortKeyValueJSON(@transforms);
    DECLARE @sortedCaseFilter NVARCHAR(MAX) = dbo.SortKeyValueJSON(@CaseFilterProperties);
    DECLARE @sortedEventFilter NVARCHAR(MAX) = dbo.SortKeyValueJSON(@EventFilterProperties);

    DECLARE @ParamHash VARBINARY(16) = HASHBYTES
    (
        'MD5',
        CONVERT(NVARCHAR(8), @StartDateTime, 112) +
        CONVERT(NVARCHAR(8), @EndDateTime, 112) +
        CAST(@enumerate_multiple_events AS NVARCHAR(1)) +
        ISNULL(@sortedTransforms, '') +
        CAST(@ByCase AS NVARCHAR(1)) +
        ISNULL(@metric, '') +
        ISNULL(@sortedCaseFilter, '') +
        ISNULL(@sortedEventFilter, '') +
        ISNULL(CAST(@CreatedBy_AccessBitmap AS VARCHAR(100)), '')
    );

    IF @ModelID IS NULL
    BEGIN
        DECLARE @ModelDescription NVARCHAR(500) =
            'Event Set: ' + @EventSet +
            ',StartDateTime: ' + CONVERT(VARCHAR, @StartDateTime, 23) +
            ',EndDateTime: ' + CONVERT(VARCHAR, @EndDateTime, 23);

        INSERT INTO dbo.Models
        (
            EventSetKey,
            enumerate_multiple_events,
            StartDateTime,
            EndDateTime,
            transformskey,
            ByCase,
            MetricID,
            CaseFilterProperties,
            EventFilterProperties,
            AccessBitmap,
            ModelType,
            [Description],
            ParamHash,
            CreatedBy_AccessBitmap
        )
        VALUES
        (
            @eventsetkey,
            @enumerate_multiple_events,
            @StartDateTime,
            @EndDateTime,
            @transformkey,
            @ByCase,
            @MetricID,
            @CaseFilterProperties,
            @EventFilterProperties,
            @AccessBitmap,                -- FIXED
            @ModelType,
            @ModelDescription,
            @ParamHash,
            @CreatedBy_AccessBitmap
        );

        SET @ModelID = @@IDENTITY;
    END
    ELSE
    BEGIN
        UPDATE dbo.Models
        SET
            enumerate_multiple_events = @enumerate_multiple_events,
            EventSetKey = @eventsetkey,
            StartDateTime = @StartDateTime,
            EndDateTime = @EndDateTime,
            transformskey = @transformkey,
            ByCase = @ByCase,
            MetricID = @MetricID,
            CaseFilterProperties = @CaseFilterProperties,
            EventFilterProperties = @EventFilterProperties,
            ModelType = @ModelType,
            CreatedBy_AccessBitmap = @CreatedBy_AccessBitmap,
            AccessBitmap = @AccessBitmap
        WHERE
            ModelID = @ModelID;

        DELETE FROM dbo.ModelProperties
        WHERE ModelID = @ModelID;
    END

    IF @CaseFilterProperties IS NOT NULL AND ISJSON(@CaseFilterProperties) = 1
    BEGIN
        INSERT INTO dbo.ModelProperties
        (
            ModelID,
            PropertyName,
            PropertyValueNumeric,
            CaseLevel,
            PropertyValueAlpha
        )
        SELECT
            @ModelID,
            [key],
            CASE WHEN ISNUMERIC([value]) = 1 THEN CAST([value] AS INT) ELSE NULL END,
            1,
            CASE WHEN ISNUMERIC([value]) <> 1 THEN [value] ELSE NULL END
        FROM OPENJSON(@CaseFilterProperties);
    END

    IF @EventFilterProperties IS NOT NULL AND ISJSON(@EventFilterProperties) = 1
    BEGIN
        INSERT INTO dbo.ModelProperties
        (
            ModelID,
            PropertyName,
            PropertyValueNumeric,
            CaseLevel,
            PropertyValueAlpha
        )
        SELECT
            @ModelID,
            [key],
            CASE WHEN ISNUMERIC([value]) = 1 THEN CAST([value] AS INT) ELSE NULL END,
            0,
            CASE WHEN ISNUMERIC([value]) <> 1 THEN [value] ELSE NULL END
        FROM OPENJSON(@EventFilterProperties);
    END
END
GO
/****** Object:  StoredProcedure [dbo].[InsertModelSimilarities]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
	"Stored Procedure": "InsertModelSimilarities",
	"Author": "Eugene Asahara", 
	"Contact": "eugene@softcodedlogic.com",
	"Last Update": "05-28-2025",
	"Description": "Compares two Markov models based on their event transition segments, calculating Jaccard-style overlap, cosine similarity of transition probabilities, and t-test for average transition times. Stores the similarity metrics in the ModelSimilarity table. Optionally outputs segment-level comparison details.",
    "Utilization": "Use when you want to compute and store similarities between models so related models can be compared, grouped, or recommended later.",
	"Input Parameters": [
	  {"name": "@ModelID1", "type": "INT", "default value": "NULL", "description": "ID of the first model to compare. Must exist in ModelEvents."},
	  {"name": "@ModelID2", "type": "INT", "default value": "NULL", "description": "ID of the second model to compare. Must exist in ModelEvents."},
	  {"name": "@DisplaySegments", "type": "BIT", "default value": "1", "description": "If set to 1, displays segment-by-segment comparison between the models."}
	],
	"Output Notes": [],
	"Referenced objects": [
	  {"name": "dbo.ModelEvents", "type": "Table", "description": "Stores segments of each model including transition pairs, statistics, and probabilities."},
	  {"name": "dbo.ModelSimilarity", "type": "Table", "description": "Holds precomputed similarity metrics between pairs of models for analysis or recommendation."}
	]
}

Sample utilization:

    EXEC dbo.InsertModelSimilarities 
         @ModelID1 = 1, 
         @ModelID2 = 8, 
         @DisplaySegments = 1;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE PROCEDURE [dbo].[InsertModelSimilarities]
@ModelID1 INT,
@ModelID2 INT,
@DisplaySegments BIT=1
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--Sort the ModelID order.
	IF @ModelID1>@ModelID2
	BEGIN
		DECLARE @TempModelID INT=@ModelID1
		SET @ModelID1=@ModelID2
		SET @ModelID2=@TempModelID
	END

	DECLARE @M1 TABLE (EventA NVARCHAR(50),EventB NVARCHAR(50),[Avg] FLOAT,[Var] FLOAT,[Rows] INT,[Prob] FLOAT)
	INSERT INTO @M1
		SELECT
			EventA,
			EventB,
			[Avg],
			POWER([StDev],2) AS [Var],
			[Rows],
			[Prob]
		FROM
			[dbo].[ModelEvents]
		WHERE
			ModelID=@ModelID1
	DECLARE @Model1Segments INT=@@ROWCOUNT

	-- Error if no segments found for ModelID1
	IF @Model1Segments = 0
	BEGIN
		RAISERROR('No segments found for ModelID1: %d', 16, 1, @ModelID1)
		RETURN
	END

	DECLARE @M2 TABLE (EventA NVARCHAR(50),EventB NVARCHAR(50),[Avg] FLOAT,[Var] FLOAT,[Rows] INT,[Prob] FLOAT)
	INSERT INTO @M2
		SELECT
			EventA,
			EventB,
			[Avg],
			POWER([StDev],2) AS [Var],
			[Rows],
			[Prob]
		FROM
			[dbo].[ModelEvents]
		WHERE
			ModelID=@ModelID2
	DECLARE @Model2Segments INT=@@ROWCOUNT

	-- Error if no segments found for ModelID1
	IF @Model2Segments = 0
	BEGIN
		RAISERROR('No segments found for ModelID2: %d', 16, 1, @ModelID2)
		RETURN
	END

	DECLARE @Segments TABLE (EventA NVARCHAR(50),EventB NVARCHAR(50),[Count] INT)
	INSERT INTO @Segments
	SELECT
		EventA,
		EventB,
		COUNT(*)
	FROM
	(
	SELECT 
		EventA,
		EventB
	FROM
		@M1
	UNION ALL
	SELECT 
		EventA,
		EventB
	FROM
		@M2
	) t
	GROUP BY 
		EventA,
		EventB

	IF @DisplaySegments=1
	BEGIN
		SELECT
			m1.EventA AS [m1_EventA],
			m2.EventA AS [m2_EventA],
			m1.EventB AS [m1_EventB],
			m2.EventB AS [m2_EventB],
			m1.[Avg] AS [m1_Avg],
			m2.[Avg] AS m2_Avg,
			m1.[Rows] AS m1_Rows,
			m2.[Rows] AS m2_Rows,
			m1.[Prob] AS m1_Prob,
			m2.[Prob] AS m2_Prob
		from 
			@M1 m1
			FULL OUTER JOIN @M2 m2 ON m1.EventA=m2.EventA and m1.EventB=m2.EventB
		WHERE
			m1.EventA IS NOT NULL AND m2.EventA IS NOT NULL
	END

	DECLARE @SegmentCount INT=@@ROWCOUNT 
	DECLARE @PercentSameSegments FLOAT=
		CASE
			WHEN @SegmentCount=0 THEN 0
			ELSE (SELECT COUNT(*) FROM @Segments WHERE [Count]=2)/CAST(@SegmentCount AS FLOAT)
		END

	-- Declare variables to store cosine similarity components
	DECLARE @DotProduct FLOAT = 0;
	DECLARE @MagnitudeM1 FLOAT = 0;
	DECLARE @MagnitudeM2 FLOAT = 0;

	-- Calculate the dot product and magnitudes for the corresponding event pairs
	SELECT 
		@DotProduct = SUM(m1.[Prob] * m2.[Prob]),  -- Dot product of Avg values
		@MagnitudeM1 = SQRT(SUM(POWER(m1.[Prob], 2))),  -- Magnitude of M1 Avg values
		@MagnitudeM2 = SQRT(SUM(POWER(m2.[Prob], 2)))  -- Magnitude of M2 Avg values
	FROM
		@M1 m1
		JOIN @M2 m2 ON m1.EventA = m2.EventA AND m1.EventB = m2.EventB;

	-- Calculate cosine similarity
	DECLARE @CosineSimilarity FLOAT = @DotProduct / (@MagnitudeM1 * @MagnitudeM2);




	DECLARE @ttest FLOAT=0
	IF @PercentSameSegments !=0
	BEGIN
		SET @ttest=
			(
				SELECT
					AVG(ttest)
				FROM
				(
					SELECT 
						(m1.[Avg]-m2.[Avg])/SQRT( (m1.[Var]/m1.[Rows])+(m2.[Var]/m2.[Rows])) AS ttest
					FROM
						@M1 m1
						JOIN @M2 m2 ON m1.EventA=m2.EventA and m1.EventB=m2.EventB
					WHERE
						COALESCE(m1.[Var],0)>0 AND COALESCE(m2.[Var],0)>0
				) t

			)
		-- (m1-m2)/sqrt(v1/n1)+(v2/n2))
	END

	IF EXISTS (SELECT * FROM  [dbo].[ModelSimilarity] WHERE ModelID1=@ModelID1 AND ModelID2=@ModelID2)
	BEGIN
		UPDATE [dbo].[ModelSimilarity]
		SET
			[CombinedUniqueSegments]=@SegmentCount,
			[PercentSameSegments]=@PercentSameSegments, --Similar to jaccard.
			[Model1Segments]=@Model1Segments,
			[Model2Segments]=@Model2Segments,
			[SameSegments_ttest]=@ttest,
			CosineSimilarity=@CosineSimilarity
		WHERE ModelID1=@ModelID1 AND ModelID2=@ModelID2			
	END
	ELSE
	BEGIN
		INSERT INTO [dbo].[ModelSimilarity]
			([ModelID1],[ModelID2],[CombinedUniqueSegments],[PercentSameSegments],[Model1Segments],[Model2Segments],[SameSegments_ttest],[CosineSimilarity])
			SELECT
				@ModelID1,
				@ModelID2,
				@SegmentCount,
				@PercentSameSegments,
				@Model1Segments,
				@Model2Segments,
				@ttest,
				@CosineSimilarity
	END

END
GO
/****** Object:  StoredProcedure [dbo].[InsertSource]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "InsertSource",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": [
    "Inserts a new source definition if one with the given Name does not already exist.",
    "If the source exists, returns its existing SourceID; otherwise creates a new row in Sources and outputs the new SourceID.",
    "Logs the insertion event to ProcErrorLog with EventName='New Source' on success."
  ],
  "Utilization": "Use when registering a new data source in the metadata layer so events, properties, and source columns can be linked to it consistently.",
  "Input Parameters": [
    {"name":"@Name","type":"NVARCHAR(50)","default":null,"description":"Unique name of the data source."},
    {"name":"@Description","type":"NVARCHAR(500)","default":"NULL","description":"Optional descriptive text for the source."},
    {"name":"@SourceProperties","type":"NVARCHAR(MAX)","default":"NULL","description":"JSON of additional source metadata."},
    {"name":"@DefaultTableName","type":"NVARCHAR(128)","default":"NULL","description":"Default table to query within the source."},
    {"name":"@IRI","type":"NVARCHAR(500)","default":"NULL","description":"Optional external identifier (IRI) for the source."},
    {"name":"@DatabaseName","type":"NVARCHAR(500)","default":"NULL","description":"Database name; defaults to current DB_NAME()."},
    {"name":"@ServerName","type":"NVARCHAR(500)","default":"NULL","description":"Server name; defaults to @@SERVERNAME."},
    {"name":"@SourceID","type":"INT","default":"NULL","description":"OUTPUT. Returns existing or newly created SourceID."}
  ],
  "Output Notes": [
    {"name":"@SourceID","type":"INT","description":"Existing or newly assigned SourceID."}
  ],
  "Referenced objects": [
    {"name":"dbo.Sources","type":"Table","description":"Table of registered data sources."},
    {"name":"dbo.ProcErrorLog","type":"Table","description":"Logs procedure events and errors, used here to record successful insertions."}
  ]
}


Sample utilization:

    DECLARE @NewID INT;
    EXEC dbo.InsertSource
      @Name = 'AdventureWorksDW2017',
      @DefaultTableName = 'FactInternetSales',
      @SourceID = @NewID OUTPUT;
    SELECT @NewID AS SourceID;

Context:
    • Provided as-is for teaching and demonstration of Time Molecules concepts.
    • **Not** production‐hardened: transactional safety, concurrency control, duplicate-name checks, and error handling beyond logging have been simplified or omitted.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/


CREATE PROCEDURE [dbo].[InsertSource]
@Name NVARCHAR(50),
@Description NVARCHAR(500)=NULL,
@SourceProperties NVARCHAR(MAX)=NULL,
@DefaultTableName NVARCHAR(128)=NULL,
@IRI NVARCHAR(500)=NULL,
@DatabaseName NVARCHAR(500)=NULL,
@ServerName NVARCHAR(500)=NULL,
@SourceID INT=NULL OUTPUT 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET @SourceID=(SELECT SourceID fROM dbo.Sources  WHERE [Name]=@Name)
	IF @SourceID IS NULL
	BEGIN
		-- Use COALESCE to assign default values if the variables are NULL
		SET @DatabaseName = COALESCE(@DatabaseName, DB_NAME());
		SET @ServerName = COALESCE(@ServerName, @@ServerNAME); -- You need a default value here

		-- Insert into Sources table
		INSERT INTO [dbo].[Sources]
				   ([Description]
				   ,[SourceProperties]
				   ,[Name]
				   ,[DefaultTableName]
				   ,[IRI]
				   ,[DatabaseName]
				   ,[ServerName])
		VALUES
				   (@Description, @SourceProperties, @Name, @DefaultTableName, @IRI, @DatabaseName, @ServerName);

		SET @SourceID=SCOPE_IDENTITY()

		INSERT INTO dbo.ProcErrorLog
		(
		  ProcedureName,
		  EventName,
		  PropertyName,
		  ErrorMessage,
		  LoggedAt
		)
		VALUES
		(
		  'InsertSource',               -- ProcedureName
		  'New Source',              -- EventName
		  'Source.SourceID',                   -- PropertyName
		  CONCAT('Inserted Source ', @SourceID),  -- ErrorMessage carries the CaseID
		  GETDATE()                   -- LoggedAt
		);
	END


END
GO
/****** Object:  StoredProcedure [dbo].[InsertSourceColumn]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Stored Procedure": "InsertSourceColumn",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": "Registers a new column for a given SourceID in the SourceColumns table. If a matching SourceColumnID or (SourceID + ColumnName + TableName) already exists, returns the existing ID and exits.",
  "Utilization": "Use when registering source-column metadata so parsed event or case properties can be mapped back to their originating fields.",
  "Input Parameters": [
    {"name":"@SourceColumnID","type":"INT","default":"NULL","description":"OUTPUT. Returns existing or newly created SourceColumnID."},
    {"name":"@SourceID","type":"INT","default":null,"description":"Identifier of the data source (must exist in Sources)."},
    {"name":"@ColumnName","type":"NVARCHAR(128)","default":null,"description":"Name of the column to register."},
    {"name":"@Description","type":"NVARCHAR(500)","default":"NULL","description":"Optional descriptive text for the column."},
    {"name":"@TableName","type":"NVARCHAR(150)","default":"NULL","description":"Name of the table where the column resides."},
    {"name":"@IRI","type":"NVARCHAR(500)","default":"NULL","description":"Optional external identifier (IRI) for the column."},
    {"name":"@DataType","type":"NCHAR(10)","default":"NULL","description":"Data type of the column (e.g., 'INT', 'NVARCHAR')."},
    {"name":"@IsKey","type":"BIT","default":"0","description":"1 if this column is part of the key; otherwise 0."},
    {"name":"@IsOrdinal","type":"BIT","default":"0","description":"1 if this column defines ordinal ordering; otherwise 0."}
  ],
  "Output Notes": [
    {"name":"@SourceColumnID","type":"INT","description":"Existing or newly generated SourceColumnID."}
  ],
  "Referenced objects": [
    {"name":"dbo.Sources","type":"Table","description":"Validated for existence of @SourceID."},
    {"name":"dbo.SourceColumns","type":"Table","description":"Target table for inserting or looking up SourceColumnID."}
  ]
}

Sample utilization:

    DECLARE @NewColID INT;
    EXEC dbo.InsertSourceColumn
      @SourceID = 1,
      @ColumnName = 'OrderDate',
      @TableName = 'FactInternetSales',
      @SourceColumnID = @NewColID OUTPUT;
    SELECT @NewColID AS SourceColumnID;

Context:
    • Provided as-is for teaching and demonstration of the Time Molecules concepts.
    • **Not** production‐hardened: no transaction scope, error logging, or concurrency safeguards.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/


CREATE PROCEDURE [dbo].[InsertSourceColumn]
@SourceColumnID INT=NULL OUTPUT,
@SourceID INT,
@ColumnName NVARCHAR(128),
@Description NVARCHAR(500)=NULL,
@TableName NVARCHAR(150)=NULL,
@IRI NVARCHAR(500)=NULL,
@DataType NCHAR(10)=NULL,
@IsKey BIT=0,
@IsOrdinal BIT=0

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Check if SourceID exists in dbo.Sources table
	IF NOT EXISTS (SELECT SourceID FROM dbo.Sources WHERE SourceID=@SourceID)
	BEGIN
		--RAISERROR ('SourceID does not exist', 16, 1);
		PRINT 'SourceID does not exist'
		RETURN;
	END

	-- Check if SourceColumnID already exists or if the same column exists for the given SourceID and TableName
	DECLARE @Test_SourceColumnID INT= (SELECT SourceColumnID FROM dbo.SourceColumns 
			   WHERE SourceColumnID=@SourceColumnID 
			   OR (SourceID=@SourceID AND ColumnName=@ColumnName AND COALESCE(@TableName, '') = COALESCE(TableName, '')))
	IF @Test_SourceColumnID IS NOT NULL
	BEGIN
		SET @SourceColumnID=@Test_SourceColumnID
		--RAISERROR ('SourceColumnID already exists or duplicate column name in the same table', 16, 1);
		PRINT 'SourceColumnID already exists or duplicate column name in the same table'
		RETURN;
	END

	-- Insert new SourceColumn
	INSERT INTO [dbo].[SourceColumns]
			   ([SourceID]
			   ,[TableName]
			   ,[ColumnName]
			   ,[IsKey]
			   ,[IsOrdinal]
			   ,[DataType]
			   ,[Description]
			   ,[IRI])
	VALUES
			   (@SourceID
			   ,@TableName
			   ,@ColumnName
			   ,@IsKey
			   ,@IsOrdinal
			   ,@DataType
			   ,@Description
			   ,@IRI)

	-- Return the newly inserted SourceColumnID
	SET @SourceColumnID = SCOPE_IDENTITY()

END
GO
/****** Object:  StoredProcedure [dbo].[InsertTransforms]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "InsertTransforms",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": [
    "Computes the canonical key for a transforms JSON payload and inserts it into the Transforms table if not already present.",
    "Returns the binary TransformsKey for downstream use."
  ],
  "Utilization": "Use when storing transform definitions that normalize or remap event names before modeling and analysis.",
  "Input Parameters": [
    {"name":"@Transforms","type":"NVARCHAR(MAX)","default":null,"description":"JSON mapping definitions for event name transformations."},
    {"name":"@Code","type":"NVARCHAR(20)","default":null,"description":"Short code or identifier for this transforms set."},
    {"name":"@Transformskey","type":"VARBINARY(16)","default":"NULL","description":"OUTPUT. The MD5/SHA2_256 key computed for the transforms JSON."}
  ],
  "Output Notes": [
    {"name":"@Transformskey","type":"VARBINARY(16)","description":"Computed transforms key for the input JSON."}
  ],
  "Referenced objects": [
    {"name":"dbo.TransformsKey","type":"Scalar Function","description":"Generates a canonical VARBINARY key for the transforms JSON."},
    {"name":"dbo.Transforms","type":"Table","description":"Stores distinct transforms JSON payloads keyed by TransformsKey, with an associated Code."}
  ]
}

Sample utilization:

    DECLARE @tkey VARBINARY(16);
    EXEC dbo.InsertTransforms
      @Transforms = N'{"old":"new","foo":"bar"}',
      @Code = N'MYTRANS',
      @Transformskey = @tkey OUTPUT;
    SELECT @tkey AS TransformsKey;

Context:
    • Provided as-is for teaching and demonstration of the Time Molecules concepts.
    • **Not** production-hardened: no transaction scope, error logging, or concurrency safeguards.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/


CREATE PROCEDURE [dbo].[InsertTransforms]
@Transforms NVARCHAR(MAX),
@Code NVARCHAR(20),
@Transformskey VARBINARY(16) OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF @Transforms IS NOT NULL
	BEGIN
		SET @Transformskey=[dbo].[TransformsKey](@Transforms)

		IF @TransformsKey IS NOT NULL AND NOT EXISTS (SELECT TransformsKey FROM [dbo].[Transforms] WHERE TransformsKey=@Transformskey)
		BEGIN
			INSERT INTO Transforms (TransformsKey,Transforms,[Code]) VALUES (@Transformskey,@Transforms,@Code)
		END
	END
END
GO
/****** Object:  StoredProcedure [dbo].[Markov_Model_Confidence_Support]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "dbo.Markov_Model_Confidence_Support",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Computes support (total transition count) and a confidence score (weighted by coefficient of variation) for one or all Markov models, returning per-model metrics and segment counts.",
  "Utilization": "Use when you want supporting statistics around model confidence, stability, or support levels for a Markov model, especially for judging whether a model is analytically trustworthy.",
  "Input Parameters": [
    { "name": "@ModelID", "type": "INT", "default": "NULL", "description": "Identifier of the model to analyze; if NULL, includes all models." }
  ],
  "Output Notes": [
    { "name": "ModelID",    "type": "INT",   "description": "Identifier of the Markov model." },
    { "name": "TotalRows",  "type": "INT",   "description": "Total number of transition rows (support) for the model." },
    { "name": "Score",      "type": "FLOAT", "description": "Confidence score computed as sum of (rows/TotalRows) × CoefVar for segments with CoefVar > 0." },
    { "name": "Segments",   "type": "INT",   "description": "Count of transition segments contributing to the confidence score." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelEvents", "type": "Table", "description": "Stores first-order transition metrics including Rows and CoefVar." }
  ]
}


Sample utilization:

    EXEC dbo.Markov_Model_Confidence_Support @ModelID = 2;
    EXEC dbo.Markov_Model_Confidence_Support;  -- all models

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, concurrency, indexing, etc., have been omitted or simplified.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE PROCEDURE [dbo].[Markov_Model_Confidence_Support]
@ModelID INT=NULL
AS
BEGIN
;
WITH m (ModelID, TotalRows,StDevRows) AS
(
    SELECT
        me.ModelID,
        SUM(me.[Rows]) AS TotalRows,
		SUM(CASE WHEN me.[CoefVar] IS NULL THEN 0 ELSE 1 END) AS [StDevRows]
    FROM
        ModelEvents me
	WHERE
		me.ModelID=@ModelID OR @ModelID IS NULL
    GROUP BY
        me.ModelID
),
ms (ModelID, TotalRows, Score, Segments) AS
(
    SELECT
        me.ModelID,
		m.TotalRows, -- "Support" metric for the model.
        SUM((me.[Rows]/CAST(m.TotalRows AS FLOAT)) * me.[CoefVar]) AS Score, -- Confidence score for the model.
        COUNT(*) AS Segments
    FROM
        ModelEvents me
		JOIN m ON m.ModelID=me.ModelID
	WHERE
		COALESCE(me.CoefVar,0)>0
    GROUP BY
        me.ModelID,
		m.TotalRows
)
SELECT 
    m.ModelID,
    m.TotalRows,
    ms.Score,
    ms.Segments
FROM 
    m
JOIN 
    ms 
ON 
    m.ModelID = ms.ModelID;

END
GO
/****** Object:  StoredProcedure [dbo].[MarkovProcess2]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*
Metadata JSON:
{
  "Stored Procedure": "dbo.MarkovProcess2",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Computes a first-, second-, or third-order Markov model from the selected events, calculating per-segment statistics such as count, probability, aggregate metric values, entry/exit flags, and ordinal measures, and writing the computed rows to WORK.MarkovProcess for the current session. This is the central object of the Markov Model Ensemble.",
  "Utilization": "Use when you want to compute a Markov model from filtered event data and return its segment statistics in procedure form, especially when temp-table logic is preferable to the TVF implementation. Helpful for generating first-, second-, or third-order model segments, comparing process behavior under different filters or transforms, and feeding the results into another procedure such as CreateUpdateMarkovProcess that is responsible for storing or updating the model.",
  "Input Parameters": [
    { "name": "@Order",                     "type": "INT",          "default": "NULL", "description": "Markov order (1–3); defaults to 1." },
    { "name": "@EventSet",                  "type": "NVARCHAR(MAX)", "default": "NULL", "description": "CSV or code defining events to include." },
    { "name": "@enumerate_multiple_events", "type": "INT",          "default": "NULL", "description": "0 to collapse duplicates; >0 to enumerate them." },
    { "name": "@StartDateTime",             "type": "DATETIME",     "default": "NULL", "description": "Lower bound of event date range." },
    { "name": "@EndDateTime",               "type": "DATETIME",     "default": "NULL", "description": "Upper bound of event date range." },
    { "name": "@transforms",                "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON mapping for event name transforms." },
    { "name": "@ByCase",                    "type": "BIT",          "default": "1",    "description": "1 to partition by CaseID; 0 to treat all as one sequence." },
    { "name": "@metric",                    "type": "NVARCHAR(20)", "default": "NULL", "description": "Metric for inter-event value (e.g., 'Time Between')." },
    { "name": "@CaseFilterProperties",      "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON of case-level filter properties." },
    { "name": "@EventFilterProperties",     "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON of event-level filter properties." },
    { "name": "@DistinctCases",             "type": "INT",          "default": "NULL", "description": "OUTPUT. Number of distinct cases processed." },
    { "name": "@ModelHighlights",           "type": "INT",          "default": "0",    "description": "Bitmap: 1 to save highlights; 2 to return highlights." },
    { "name": "@ModelID",                   "type": "INT",          "default": "NULL", "description": "OUTPUT. ModelID created or refreshed." }
  ],
  "Output Notes": [
    { "name": "Resultset 1", "type": "Table", "description": "ModelEvents rows: Event1A→EventB stats (Max, Avg, Min, StDev, CoefVar, Rows, Prob, etc.)." },
    { "name": "Resultset 2", "type": "Table", "description": "Anomaly highlights (if requested) with metric_zscore or low-prob flags per case." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelsByParameters",           "type": "Table-Valued Function", "description": "Resolves or creates a ModelID by parameters." },
    { "name": "dbo.InsertModel",                  "type": "Stored Procedure",        "description": "Upserts into Models and returns keys." },
    { "name": "dbo.sp_SelectedEvents",               "type": "Stored Procedure",   "description": "Returns filtered, ordered event stream per case." },
    { "name": "dbo.MetricValue",                  "type": "Scalar Function",         "description": "Computes a numeric metric per method." },
    { "name": "dbo.DefaultGroupType",             "type": "Scalar Function",         "description": "Normalizes grouping to CASEID/DAY/MONTH/YEAR." },
    { "name": "dbo.Model_Stationary_Distribution","type": "Table-Valued Function",   "description": "Provides stationary probabilities for initial event." },
    { "name": "dbo.EventPairAnomalies",           "type": "Table",                   "description": "Stores computed anomaly highlights." }
  ]
}

Sample utilization:

	DECLARE @ModelID INT=NULL
	DECLARE @DistinctCases INT=NULL
    EXEC dbo.MarkovProcess2 
      @Order=1,
      @EventSet='arrive,greeted,seated',
      @enumerate_multiple_events=0,
      @StartDateTime='2025-01-01',
      @EndDateTime='2025-12-31',
      @ByCase=1,
      @ModelHighlights=3,
      @DistinctCases=@DistinctCases OUTPUT,
      @ModelID=@ModelID OUTPUT;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.


DO NOT Return any result sets because this sproc is used in CreateUpdateMarkovProcess as INSERT EXEC.
This sproc only returns Markov Model info. Use CreateUpdateMarkovProcess to store one.

USE CreateUpdateMarkovProcess to add models. This just computes the model. It's the stored proc version of the TVF, it's faster.

Compare the 1st order and 2nd order

BE WARY THAT the TVF MarkovProcess also that code to generate Markov models. The reason is that there
are advantages between stored procedures and TVF. We need the TVF for convenience of calling through a TVF and
stored procedure for better ways to implement algorithms (like temp tables, and other "side-effect" stuff
not allowed by functions.

ReturnHighlights will only work for Order=1 and ReturnHighlights=1

SELECT * FROM [dbo].[MarkovProcess1](0,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL,NULL)
SELECT * FROM [dbo].[MarkovProcess](1,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL,NULL)
SELECT * FROM [dbo].[MarkovProcess](2,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL,NULL)
SELECT * FROM [dbo].[MarkovProcess](3,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL,NULL)

EXEC dbo.[MarkovProcess2] 1,'NEW_GAME,collected,GameState-0,GameState-1,GameState-2,GameState-3,GameState-4,calls,bets,raises,folds,checks',0,'01/01/2000','01/04/2050',NULL,1,NULL,'{"TournamentNumber":206815194}','{"Player":"RaminWho"}'

DECLARE @DistinctCases INT
DECLARE @ModelHighlights INT=1 --Create and Save
EXEC dbo.[MarkovProcess2] 0,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL,NULL,@DistinctCases OUTPUT,@ModelHighlights
PRINT @DistinctCases

EXEC dbo.[MarkovProcess2] 0, 'restaurantguest',0,'01/01/1900','12/31/2050',null,1,NULL,'{"EmployeeID":1,"CustomerID":2}',NULL

EXEC dbo.[MarkovProcess2] 1,'SaleOrder,SaleShip',0,NULL,NULL,NULL,1,NULL,NULL,NULL

SELECT ModelID,Event1A,EventB,[Max],[Avg],[Min],[StDev],CoefVar,[Sum],[Rows],Prob
FROM dbo.[MarkovProcess](1,'SaleOrder,SaleShip',0,NULL,NULL,NULL,1,NULL,NULL,NULL,0) 
*/

CREATE   PROCEDURE [dbo].[MarkovProcess2]
(
    @Order INT = NULL, -- 1, 2 or 3
    @EventSet NVARCHAR(MAX) = NULL,
    @enumerate_multiple_events INT = NULL,
    @StartDateTime DATETIME = NULL,
    @EndDateTime DATETIME = NULL,
    @transforms NVARCHAR(MAX) = NULL,
    @ByCase BIT = 1,
    @metric NVARCHAR(20) = NULL,
    @CaseFilterProperties NVARCHAR(MAX) = NULL,
    @EventFilterProperties NVARCHAR(MAX) = NULL,
    @DistinctCases INT = NULL OUTPUT,
    @ModelHighlights INT = 0, -- Bitmap: 0=No ModelHighlights, Bit 1=Create and Save ModelHighlights, Bit 2=Return ModelHighlights
    @ModelID INT = NULL OUTPUT,
	@SessionID UNIQUEIDENTIFIER=NULL, --If NULL, will display results and clean up WORK.MarkovProcess
    @CreatedBy_AccessBitmap BIGINT = NULL,
    @AccessBitmap BIGINT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE @DefaultCreatedBy_AccessBitmap BIGINT;

	SELECT
		@StartDateTime = StartDateTime,
		@EndDateTime = EndDateTime,
		@Order = [Order],
		@metric = [metric],
		@enumerate_multiple_events = enumerate_multiple_events,
		@DefaultCreatedBy_AccessBitmap = AccessBitmap
	FROM dbo.SetDefaultModelParameters
	(
		@StartDateTime,
		@EndDateTime,
		@Order,
		@enumerate_multiple_events,
		@metric
	);

	SET @CreatedBy_AccessBitmap =
		COALESCE(@CreatedBy_AccessBitmap, @DefaultCreatedBy_AccessBitmap);

	SET @AccessBitmap =
		COALESCE(@AccessBitmap, @CreatedBy_AccessBitmap);

	DECLARE @DisplayResult BIT=0
	IF @SessionID IS NULL
	BEGIN
		SET @SessionID=neWID() --Get SessionID is one wasn't supplied.
		SET @DisplayResult=1
	END


    DECLARE @metricMethod INT =
    (
        SELECT [Method]
        FROM dbo.Metrics
        WHERE [Metric] = @metric
    );

    DECLARE @EventBIncrement INT =
        CASE WHEN @Order BETWEEN 1 AND 3 THEN @Order ELSE 1 END;

    IF @ModelID IS NULL
    BEGIN
        SET @ModelID = dbo.ModelID
        (
            @EventSet,
            @enumerate_multiple_events,
            @StartDateTime,
            @EndDateTime,
            @transforms,
            @ByCase,
            @metric,
            @CaseFilterProperties,
            @EventFilterProperties,
            'MarkovChain',
			@CreatedBy_AccessBitmap
        );
    END;

    DECLARE @StartCreate DATETIME = GETDATE();

    DROP TABLE IF EXISTS #raw;
    CREATE TABLE #raw
    (
        CaseID INT NOT NULL,
        [Event] NVARCHAR(50) NOT NULL,
        EventDate DATETIME2 NOT NULL,
        [Rank] INT NOT NULL,
        EventOccurence INT NOT NULL,
        MetricInputValue FLOAT NULL,
        MetricOutputValue FLOAT NULL,
        EventID INT NOT NULL,
        CONSTRAINT PK_raw PRIMARY KEY CLUSTERED (CaseID, [Rank], EventID)
    );

	EXEC dbo.sp_SelectedEvents
		 @EventSet = @EventSet,
		 @enumerate_multiple_events = @enumerate_multiple_events,
		 @StartDateTime = @StartDateTime,
		 @EndDateTime = @EndDateTime,
		 @transforms = @transforms,
		 @ByCase = @ByCase,
		 @metric = @metric,
		 @CaseFilterProperties = @CaseFilterProperties,
		 @EventFilterProperties = @EventFilterProperties,
		 @SessionID=@SessionID,
	     @CreatedBy_AccessBitmap = @CreatedBy_AccessBitmap;

	INSERT INTO #raw
	(
		CaseID,
		[Event],
		EventDate,
		[Rank],
		EventOccurence,
		MetricInputValue,
		MetricOutputValue,
		EventID
	)
	SELECT
		CaseID,
		[Event],
		EventDate,
		[Rank],
		EventOccurence,
		MetricInputValue,
		MetricOutputValue,
		EventID
	FROM
		WORK.SelectedEvents
	WHERE
		SessionID=@SessionID

    DECLARE @EventFactRows BIGINT = @@ROWCOUNT;

	DELETE FROM WORK.SelectedEvents
	WHERE
		SessionID=@SessionID

    SELECT @DistinctCases = COUNT(*)
    FROM
    (
        SELECT r.CaseID
        FROM #raw r
        GROUP BY r.CaseID
    ) d;

    DROP TABLE IF EXISTS #t0;
    CREATE TABLE #t0
    (
        Event1A NVARCHAR(50) NOT NULL,
        Event2A NVARCHAR(50) NOT NULL,
        Event3A NVARCHAR(50) NOT NULL,
        EventB NVARCHAR(50) NOT NULL,
        [value] FLOAT NULL,
        IsEntry INT NOT NULL,
        EventBIsExit INT NOT NULL,
        [Rank] FLOAT NOT NULL,
        EventIDA INT NOT NULL,
        EventIDB INT NOT NULL,
        CaseID INT NOT NULL
    );

    INSERT INTO #t0
    (
        Event1A,
        Event2A,
        Event3A,
        EventB,
        [value],
        IsEntry,
        EventBIsExit,
        [Rank],
        EventIDA,
        EventIDB,
        CaseID
    )
    SELECT
        t1a.[Event] AS Event1A,
        CASE WHEN @EventBIncrement < 2 OR t1b.[Event] IS NULL THEN '------' ELSE t1b.[Event] END AS Event2A,
        CASE WHEN @EventBIncrement < 3 OR t1c.[Event] IS NULL THEN '------' ELSE t1c.[Event] END AS Event3A,
        t2.[Event] AS EventB,
        CASE
            WHEN @metric = 'Time Between' THEN
                DATEDIFF
                (
                    SECOND,
                    CASE
                        WHEN @EventBIncrement = 1 THEN t1a.EventDate
                        WHEN @EventBIncrement = 2 THEN t1b.EventDate
                        WHEN @EventBIncrement = 3 THEN t1c.EventDate
                    END,
                    t2.EventDate
                ) / 60.0
            ELSE
                CASE
                    WHEN @EventBIncrement = 1 THEN dbo.MetricValue(@metricMethod, t1a.MetricInputValue, t1a.MetricOutputValue, t2.MetricInputValue, t2.MetricOutputValue)
                    WHEN @EventBIncrement = 2 THEN dbo.MetricValue(@metricMethod, t1b.MetricInputValue, t1b.MetricOutputValue, t2.MetricInputValue, t2.MetricOutputValue)
                    WHEN @EventBIncrement = 3 THEN dbo.MetricValue(@metricMethod, t1c.MetricInputValue, t1c.MetricOutputValue, t2.MetricInputValue, t2.MetricOutputValue)
                END
        END AS [value],
        CASE WHEN t1a.[Rank] = 1 THEN 1 ELSE 0 END AS IsEntry,
        CASE WHEN t2a.[Rank] IS NULL THEN 1 ELSE 0 END AS EventBIsExit,
        CAST(t1a.[Rank] AS FLOAT) AS [Rank],
        t1a.EventID AS EventIDA,
        t2.EventID AS EventIDB,
        t1a.CaseID
    FROM #raw AS t1a
    JOIN #raw AS t2
      ON t2.CaseID = t1a.CaseID
     AND t2.[Rank] = t1a.[Rank] + @EventBIncrement
    LEFT JOIN #raw AS t2a
      ON t2a.CaseID = t2.CaseID
     AND t2a.[Rank] = t2.[Rank] + 1
    LEFT JOIN #raw AS t1b
      ON t1b.CaseID = t1a.CaseID
     AND t1b.[Rank] = t1a.[Rank] + 1
    LEFT JOIN #raw AS t1c
      ON t1c.CaseID = t1a.CaseID
     AND t1c.[Rank] = t1a.[Rank] + 2;

    CREATE INDEX IX_t0_EventA_EventB
        ON #t0 (Event1A, EventB)
        INCLUDE ([value], CaseID, EventIDA, EventIDB, IsEntry, EventBIsExit, [Rank], Event2A, Event3A);

	IF @SessionID IS NULL
	BEGIN
		SET @SessionID=NEWID()
	END

    ;WITH Agg AS
    (
        SELECT
            t.Event1A,
            t.Event2A,
            t.Event3A,
            t.EventB,
            COUNT(*) AS [Rows],
            CAST(AVG(t.[value]) AS FLOAT) AS [Avg],
            STDEV(t.[value]) AS [StDev],
            MAX(t.[value]) AS [Max],
            MIN(t.[value]) AS [Min],
            SUM(t.IsEntry) AS IsEntry,
            SUM(t.EventBIsExit) AS IsExit,
            SUM(t.[value]) AS [Sum],
            AVG(t.[Rank]) AS OrdinalMean,
            STDEV(t.[Rank]) AS OrdinalStDev
        FROM #t0 AS t
        GROUP BY
            t.Event1A,
            t.Event2A,
            t.Event3A,
            t.EventB
    ),
    FinalAgg AS
    (
        SELECT
            a.*,
            SUM(a.[Rows]) OVER (PARTITION BY a.Event1A, a.Event2A, a.Event3A) AS TotalRowsForPrefix
        FROM Agg a
    )


    INSERT INTO WORK.MarkovProcess
    (
        ModelID,
        Event1A,
        Event2A,
        Event3A,
        EventB,
        [Max],
        [Avg],
        [Min],
        [StDev],
        [CoefVar],
        [Sum],
        [Rows],
        Prob,
        IsEntry,
        IsExit,
        FromCache,
        OrdinalMean,
        OrdinalStDev,
		SessionID
    )
    SELECT
        @ModelID,
        f.Event1A,
        f.Event2A,
        f.Event3A,
        f.EventB,
        f.[Max],
        ROUND(f.[Avg], 4),
        f.[Min],
        ROUND(f.[StDev], 4),
        CASE
            WHEN f.[Avg] = 0 OR f.[Avg] IS NULL OR f.[StDev] IS NULL THEN NULL
            ELSE ROUND(f.[StDev] / f.[Avg], 3)
        END AS CoefVar,
        f.[Sum],
        f.[Rows],
        CASE
            WHEN f.TotalRowsForPrefix = 0 THEN NULL
            ELSE ROUND(f.[Rows] / CAST(f.TotalRowsForPrefix AS FLOAT), 4)
        END AS Prob,
        f.IsEntry,
        f.IsExit,
        0,
        f.OrdinalMean,
        f.OrdinalStDev,
		@SessionID
    FROM FinalAgg f
    ORDER BY
        f.Event1A, f.Event2A, f.Event3A, f.EventB;

    DECLARE @EndCreate DATETIME = GETDATE();

    UPDATE dbo.Models
       SET EventFactRows     = @EventFactRows,
           CreationDuration  = DATEDIFF(SECOND, @StartCreate, @EndCreate),
           LastUpdate        = GETDATE()
     WHERE ModelID = @ModelID;


	--Create Model Highlights, if that option is selected.
    IF @Order = 1 AND (@ModelHighlights & 1) = 1
    BEGIN
        DECLARE @MH TABLE
        (
            ModelID INT,
            CaseID INT,
            EventIDA INT,
            EventIDB INT,
            EventA NVARCHAR(50),
            EventB NVARCHAR(50),
            AnomalyCode NVARCHAR(50),
            metric_zscore FLOAT,
            metric_value FLOAT,
            transistion_prob FLOAT,
            EventAIsEntry BIT,
            EventBIsExit BIT
        );

        DECLARE @CoefVAR FLOAT = 1.5;

        ;WITH CTE AS
        (
            SELECT
                ROW_NUMBER() OVER (PARTITION BY @ModelID, s.CaseID, m.Event1A, m.EventB, 'Metric Outlier' ORDER BY s.[value]) AS RowNum,
                @ModelID AS ModelID,
                s.CaseID,
                s.EventIDA,
                s.EventIDB,
                m.Event1A AS EventA,
                m.EventB,
                'Metric Outlier' AS Highlight,
                CASE
                    WHEN COALESCE(m.[StDev], 0) <> 0 THEN ROUND((s.[value] - m.[Avg]) / m.[StDev], 4)
                    ELSE NULL
                END AS metric_zscore,
                s.[value] AS metric_value,
                NULL AS transistion_prob,
                s.IsEntry AS EventAIsEntry,
                s.EventBIsExit AS EventBIsExit
            FROM #t0 s
            JOIN WORK.MarkovProcess m
              ON m.Event1A = s.Event1A
             AND m.EventB = s.EventB
			 AND m.SessionID=@SessionID
            WHERE
                CASE
                    WHEN COALESCE(m.[StDev], 0) <> 0 THEN ROUND((s.[value] - m.[Avg]) / m.[StDev], 4)
                    ELSE NULL
                END > @CoefVAR

            UNION ALL

            SELECT
                ROW_NUMBER() OVER (PARTITION BY @ModelID, s.CaseID, m.Event1A, m.EventB, 'Low Prob' ORDER BY s.[value]) AS RowNum,
                @ModelID AS ModelID,
                s.CaseID,
                s.EventIDA,
                s.EventIDB,
                m.Event1A AS EventA,
                m.EventB,
                'Low Prob' AS Highlight,
                NULL AS metric_zscore,
                s.[value] AS metric_value,
                m.Prob AS transistion_prob,
                s.IsEntry AS EventAIsEntry,
                s.EventBIsExit AS EventBIsExit
            FROM #t0 s
            JOIN WORK.MarkovProcess m
              ON m.Event1A = s.Event1A
             AND m.EventB = s.EventB
			 AND m.SessionID=@SessionID
            WHERE m.Prob <= 0.10
        )
        INSERT INTO @MH
        SELECT
            ModelID,
            CaseID,
            EventIDA,
            EventIDB,
            EventA,
            EventB,
            Highlight,
            metric_zscore,
            metric_value,
            transistion_prob,
            EventAIsEntry,
            EventBIsExit
        FROM CTE
        WHERE RowNum = 1;

        MERGE INTO dbo.EventPairAnomalies AS Target
        USING @MH AS Source
           ON Target.ModelID = Source.ModelID
          AND Target.CaseID = Source.CaseID
          AND Target.EventA = Source.EventA
          AND Target.EventB = Source.EventB
          AND Target.AnomalyCode = Source.AnomalyCode
        WHEN MATCHED THEN
            UPDATE SET
                Target.metric_zscore   = Source.metric_zscore,
                Target.metric_value    = Source.metric_value,
                Target.transistion_prob = Source.transistion_prob,
                Target.EventAIsEntry   = Source.EventAIsEntry,
                Target.EventBIsExit    = Source.EventBIsExit
        WHEN NOT MATCHED THEN
            INSERT
            (
                ModelID,
                CaseID,
                EventIDA,
                EventIDB,
                EventA,
                EventB,
                AnomalyCode,
                metric_zscore,
                metric_value,
                transistion_prob,
                EventAIsEntry,
                EventBIsExit
            )
            VALUES
            (
                Source.ModelID,
                Source.CaseID,
                Source.EventIDA,
                Source.EventIDB,
                Source.EventA,
                Source.EventB,
                Source.AnomalyCode,
                Source.metric_zscore,
                Source.metric_value,
                Source.transistion_prob,
                Source.EventAIsEntry,
                Source.EventBIsExit
            );

        IF (@ModelHighlights & 2) = 2
        BEGIN
            SELECT *
            FROM @MH
            ORDER BY CaseID, EventA, EventB, AnomalyCode;
        END
    END

	--If @SessionID came in NULL, will display result and remove the WORK.MarkovProcess temp rows.
	IF @DisplayResult=1
	BEGIN
		SELECT 
			[ModelID]
			,[Event1A]
			,[Event2A]
			,[Event3A]
			,[EventB]
			,[Max]
			,[Avg]
			,[Min]
			,[StDev]
			,[CoefVar]
			,[Sum]
			,[Rows]
			,[Prob]
			,[IsEntry]
			,[IsExit]
			,[FromCache]
			,[OrdinalMean]
			,[OrdinalStDev]
		FROM Work.MarkovProcess WHERE SessionID=@SessionID;

		DELETE FROM Work.MarkovProcess WHERE SessionID=@SessionID;
	END

END;
GO
/****** Object:  StoredProcedure [dbo].[RefreshUserAccessBitmaps]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Stored Procedure": "dbo.RefreshUserAccessBitmaps",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-04-11",
  "Description": "Rebuilds dbo.Users.AccessBitmap from granted rows in dbo.UserAccessRole by summing the corresponding bit value for each AccessID. Optionally limits the refresh to one user.",
  "Utilization": "Use after inserting, updating, or deleting rows in dbo.UserAccessRole so dbo.Users.AccessBitmap stays synchronized for fast bitmap-based access checks throughout TimeSolution.",
  "Input Parameters": [
    { "name": "@UserID", "type": "INT", "default": "NULL", "description": "Optional UserID to refresh. NULL refreshes all users." },
    { "name": "@SUSER_NAME", "type": "NVARCHAR(50)", "default": "NULL", "description": "Optional login name to refresh. Used only if @UserID is NULL." },
    { "name": "@DisplayResults", "type": "BIT", "default": "0", "description": "1 to return refreshed users and their AccessBitmap values." }
  ],
  "Output Notes": [
    { "name": "dbo.Users.AccessBitmap", "type": "Table Update", "description": "Updated to reflect the sum of granted role bits from dbo.UserAccessRole." },
    { "name": "Return Resultset", "type": "Table", "description": "When @DisplayResults=1, returns UserID, SUSER_NAME, SQLLoginName, and AccessBitmap for refreshed rows." }
  ],
  "Referenced objects": [
    { "name": "dbo.Users", "type": "Table", "description": "Stores the materialized AccessBitmap per user." },
    { "name": "dbo.UserAccessRole", "type": "Table", "description": "Normalized user-to-access-role bridge table." },
    { "name": "dbo.Access", "type": "Table", "description": "Lookup table of access roles and AccessID values." }
  ]
}

Sample utilization:

    EXEC dbo.RefreshUserAccessBitmaps;

    EXEC dbo.RefreshUserAccessBitmaps
        @UserID = 5,
        @DisplayResults = 1;

    EXEC dbo.RefreshUserAccessBitmaps
        @SUSER_NAME = SUSER_NAME(),
        @DisplayResults = 1;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2026 Eugene Asahara. All rights reserved.
*/
CREATE   PROCEDURE [dbo].[RefreshUserAccessBitmaps]
(
    @UserID INT = NULL,
    @SUSER_NAME NVARCHAR(50) = NULL,
    @DisplayResults BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @UserID IS NULL AND @SUSER_NAME IS NOT NULL
    BEGIN
        SELECT @UserID = u.UserID
        FROM dbo.Users u
        WHERE u.SUSER_NAME = @SUSER_NAME;
    END;

    ;WITH BitValues AS
    (
        SELECT
            uar.UserID,
            SUM(
                CASE
                    WHEN COALESCE(uar.Granted, 1) = 1
                         AND COALESCE(a.IsActive, 1) = 1
                         AND a.AccessID BETWEEN 1 AND 62
                    THEN POWER(CAST(2 AS BIGINT), a.AccessID - 1)
                    ELSE CAST(0 AS BIGINT)
                END
            ) AS AccessBitmap
        FROM
            dbo.UserAccessRole uar
            JOIN dbo.Access a
                ON a.AccessID = uar.AccessID
        WHERE
            (@UserID IS NULL OR uar.UserID = @UserID)
        GROUP BY
            uar.UserID
    )
    UPDATE u
       SET
           u.AccessBitmap = COALESCE(bv.AccessBitmap, 0),
           u.LastUpdate = GETDATE()
    FROM
        dbo.Users u
        LEFT JOIN BitValues bv
            ON bv.UserID = u.UserID
    WHERE
        (@UserID IS NULL OR u.UserID = @UserID);

    IF @DisplayResults = 1
    BEGIN
        SELECT
            u.UserID,
            u.SUSER_NAME,
            u.SQLLoginName,
            u.AccessBitmap,
            u.LastUpdate
        FROM
            dbo.Users u
        WHERE
            (@UserID IS NULL OR u.UserID = @UserID)
        ORDER BY
            u.UserID;
    END
END
GO
/****** Object:  StoredProcedure [dbo].[SetUserAccessBitmap]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "dbo.SetUserAccessBitmap",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Inserts or updates a user’s AccessBitmap in the Users table based on login name, and optionally returns the detailed granted permissions.",
  "Utilization": "Use when assigning or updating bitmap-based access permissions for a user so model and metadata visibility can be enforced consistently.",
  "Input Parameters": [
    { "name": "@SUSER_NAME",           "type": "NVARCHAR(50)", "default": "NULL", "description": "Login name; defaults to current SUSER_NAME()." },
    { "name": "@AccessBitmap",         "type": "BIGINT",        "default": "NULL", "description": "Bitmap value representing the user’s permissions." },
    { "name": "@DisplayAccessDetail",  "type": "BIT",           "default": "0",    "description": "1 to return detailed granted permissions via DecodeAccessBitmap; 0 to suppress." },
    { "name": "@UserID",               "type": "INT",           "default": "NULL", "description": "OUTPUT. The UserID of the inserted or updated user." }
  ],
  "Output Notes": [
    { "name": "Return Resultset", "type": "Table", "description": "When @DisplayAccessDetail=1, returns rows of AccessID, Description, Granted (bit)." }
  ],
  "Referenced objects": [
    { "name": "dbo.UserID",               "type": "Scalar Function",        "description": "Looks up or creates a UserID based on login name." },
    { "name": "dbo.Users",                "type": "Table",                  "description": "Stores user login names and their AccessBitmap." },
    { "name": "dbo.DecodeAccessBitmap",   "type": "Table-Valued Function",  "description": "Decodes a bitmap into individual permission flags." }
  ]
}
Sample utilization:
	DECLARE @UID INT
    EXEC dbo.SetUserAccessBitmap 
      @SUSER_NAME = NULL, 
      @AccessBitmap = 12345, 
      @DisplayAccessDetail = 1, 
      @UserID = @UID OUTPUT;
	PRINT @UID

	DECLARE @UID INT
	EXEC dbo.SetUserAccessBitmap 'TestUser', 1, @UserID = @UID OUTPUT;
	PRINT @UID

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE PROCEDURE [dbo].[SetUserAccessBitmap]
@SUSER_NAME NVARCHAR(50)=NULL,
@AccessBitmap BIGINT,
@DisplayAccessDetail BIT=0,
@UserID INT=NULL OUTPUT
AS
BEGIN
	SET @SUSER_NAME=COALESCE(@SUSER_NAME,SUSER_NAME())
	SET @UserID=dbo.UserID(@SUSER_NAME)

	IF @UserID IS NULL
	BEGIN
		INSERT INTO [dbo].[Users] ([SUSER_NAME],AccessBitmap)
			VALUES(@SUSER_NAME,@AccessBitmap)
		SET @UserID=@@IDENTITY
	END
	ELSE
	BEGIN
		UPDATE [dbo].[Users] SET
			AccessBitmap=@AccessBitmap,
			LastUpdate=getdate()
		WHERE
			[SUSER_NAME]=@SUSER_NAME
	END

	IF @DisplayAccessDetail=1
	BEGIN
		SELECT * FROM [dbo].[DecodeAccessBitmap](@AccessBitmap) WHERE [Granted]=1
	END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_AdjacencyMatrix]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "dbo.sp_AdjacencyMatrix",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-03-31",
  "Description": "Generates an adjacency matrix from a given event set by calling dbo.MarkovProcess2 and then returning, for each EventA→EventB pair, the conditional probability P(B|A), total occurrences of EventA, and raw transition counts.",
  "Utilization": "Use when you want the stored-procedure version of dbo.AdjacencyMatrix so the logic can rely on the temp/work-table implementation path used by dbo.MarkovProcess2. This is more compatible with the newer Time Molecules stored-proc architecture and is friendlier to Azure Synapse style processing than depending on the legacy TVF chain.",
  "Input Parameters": [
    { "name": "@EventSet",                 "type": "NVARCHAR(MAX)",     "default": "NULL", "description": "Comma-separated list or code defining the set of events to include." },
    { "name": "@enumerate_multiple_events","type": "INT",               "default": "0",    "description": "1 to treat repeated events separately; 0 to collapse duplicates." },
    { "name": "@transforms",               "type": "NVARCHAR(MAX)",     "default": "NULL", "description": "Optional event-mapping JSON or code for normalizing event names." },
    { "name": "@SessionID",                "type": "UNIQUEIDENTIFIER",  "default": "NULL", "description": "Optional session identifier for WORK.MarkovProcess rows. If NULL, one is generated." }
  ],
  "Output Notes": [
    { "name": "EventA",       "type": "NVARCHAR(50)", "description": "The source event of the transition." },
    { "name": "EventB",       "type": "NVARCHAR(50)", "description": "The target event of the transition." },
    { "name": "probability",  "type": "FLOAT",        "description": "P(B|A) = count(A→B) / total count of A." },
    { "name": "Event1A_Rows", "type": "FLOAT",        "description": "Total number of occurrences of EventA across all outgoing transitions." },
    { "name": "count",        "type": "FLOAT",        "description": "Raw count of EventA→EventB transitions." }
  ],
  "Referenced objects": [
    { "name": "dbo.MarkovProcess2",   "type": "Stored Procedure", "description": "Builds Markov transition rows into WORK.MarkovProcess for a supplied SessionID." },
    { "name": "WORK.MarkovProcess",   "type": "Table",            "description": "Stores computed transition rows, including Event1A, EventB, Rows, Prob, and SessionID." }
  ]
}

Sample utilization:

    SELECT * FROM dbo.AdjacencyMatrix('poker', 1, NULL);
	EXEC dbo.sp_AdjacencyMatrix @EventSet='poker', @enumerate_multiple_events=1, @transforms=NULL;

	SELECT * FROM  [dbo].[AdjacencyMatrix]('restaurantguest',1,NULL)
    EXEC dbo.sp_AdjacencyMatrix @EventSet='restaurantguest', @enumerate_multiple_events=1, @transforms=NULL;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/
CREATE   PROCEDURE [dbo].[sp_AdjacencyMatrix]
(
    @EventSet NVARCHAR(MAX),
    @enumerate_multiple_events INT = 0,
    @transforms NVARCHAR(MAX) = NULL,
    @SessionID UNIQUEIDENTIFIER = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LocalSessionID UNIQUEIDENTIFIER = COALESCE(@SessionID, NEWID());
    DECLARE @DistinctCases INT = NULL;
    DECLARE @ModelID INT = NULL;
    DECLARE @ModelHighlights INT = 0; -- Do not create/return highlights.

    -- Make sure there are no leftover rows for this SessionID.
    DELETE FROM WORK.MarkovProcess
    WHERE SessionID = @LocalSessionID;

    -- Build first-order Markov rows into WORK.MarkovProcess.
    EXEC dbo.MarkovProcess2
         @Order = 1,
         @EventSet = @EventSet,
         @enumerate_multiple_events = @enumerate_multiple_events,
         @StartDateTime = NULL,
         @EndDateTime = NULL,
         @transforms = @transforms,
         @ByCase = 1,
         @metric = NULL,
         @CaseFilterProperties = NULL,
         @EventFilterProperties = NULL,
         @DistinctCases = @DistinctCases OUTPUT,
         @ModelHighlights = @ModelHighlights,
         @ModelID = @ModelID OUTPUT,
         @SessionID = @LocalSessionID;

    ;WITH mp AS
    (
        SELECT
            Event1A,
            EventB,
            [Rows]
        FROM WORK.MarkovProcess
        WHERE SessionID = @LocalSessionID
    )
    SELECT
        Event1A AS [EventA],
        EventB,
        CAST(SUM([Rows]) AS FLOAT) / SUM(SUM([Rows])) OVER (PARTITION BY Event1A) AS probability,
        SUM(SUM([Rows])) OVER (PARTITION BY Event1A) AS Event1A_Rows,
        CAST(SUM([Rows]) AS FLOAT) AS [count]
    FROM mp
    GROUP BY
        Event1A,
        EventB
    ORDER BY
        Event1A,
        EventB;

    DELETE FROM WORK.MarkovProcess
    WHERE SessionID = @LocalSessionID;
END
GO
/****** Object:  StoredProcedure [dbo].[sp_CaseCharacteristics]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "dbo.sp_CaseCharacteristics",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-03-31",
  "Description": "Retrieves both anomaly-derived event-pair metrics and case-level properties for a given model, consolidating them into a single result set for downstream association analysis. Stored-proc version of dbo.CaseCharacteristics using dbo.sp_ModelDrillThrough to derive the case population.",
  "Utilization": "Use when you want one result set that mixes model-derived anomaly signals with case properties for the same population of cases, while following the newer stored-procedure architecture.",
  "Input Parameters": [
    { "name": "@ModelID", "type": "INT", "default": "NULL", "description": "Identifier of the model whose characteristics are to be returned." }
  ],
  "Output Notes": [
    { "name": "ModelID",              "type": "INT",            "description": "Model identifier for anomaly rows; NULL for case properties." },
    { "name": "CaseID",               "type": "INT",            "description": "Identifier of the case." },
    { "name": "EventIDA",             "type": "INT",            "description": "Event A ID for anomaly pairs; NULL for case properties." },
    { "name": "EventIDB",             "type": "INT",            "description": "Event B ID for anomaly pairs; NULL for case properties." },
    { "name": "Category",             "type": "NVARCHAR(50)",   "description": "AnomalyCode for anomalies or CaseProperty for properties." },
    { "name": "Attribute",            "type": "NVARCHAR(50)",   "description": "Metric name for anomalies or property name for case properties." },
    { "name": "EventA",               "type": "NVARCHAR(20)",   "description": "Name of event A for anomalies; NULL for case properties." },
    { "name": "EventB",               "type": "NVARCHAR(20)",   "description": "Name of event B for anomalies; NULL for case properties." },
    { "name": "metric_zscore",        "type": "FLOAT",          "description": "Z-score of the anomaly metric; NULL for case properties." },
    { "name": "metric_value",         "type": "FLOAT",          "description": "Raw anomaly metric value; NULL for case properties." },
    { "name": "transistion_prob",     "type": "FLOAT",          "description": "Anomaly transition probability; NULL for case properties." },
    { "name": "EventAIsEntry",        "type": "BIT",            "description": "Flag if EventA is entry; NULL for case properties." },
    { "name": "EventBIsExit",         "type": "BIT",            "description": "Flag if EventB is exit; NULL for case properties." },
    { "name": "PropertyValueNumeric", "type": "FLOAT",          "description": "Numeric value of case property; NULL for anomalies." },
    { "name": "PropertyValueAlpha",   "type": "NVARCHAR(1000)", "description": "Text value of case property; NULL for anomalies." }
  ]
}
Sample utilization:

   EXEC sp_CaseCharacteristics @ModelID=1
	SELECT * FROM dbo.CaseCharacteristics(1);
*/
CREATE   PROCEDURE [dbo].[sp_CaseCharacteristics]
(
    @ModelID INT,
	@SessionID UNIQUEIDENTIFIER=NULL
)
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE @DisplayReport BIT=0
	IF @SessionID IS NULL
	BEGIN
		SET @DisplayReport=1
		SET @SessionID=NEWID()
	END


	EXEC dbo.sp_ModelDrillThrough
		 @ModelID = @ModelID,
		 @EventA = NULL,
		 @EventB = NULL,
		 @SessionID=@SessionID

	INSERT INTO WORK.CaseCharacteristics
    SELECT
        epa.[ModelID],
        epa.[CaseID],
        epa.[EventIDA],
        epa.[EventIDB],
        epa.[AnomalyCode] AS [Category],
        met.[Metric] AS [Attribute],
        epa.[EventA],
        epa.[EventB],
        epa.[metric_zscore],
        epa.[metric_value],
        epa.[transistion_prob],
        epa.[EventAIsEntry],
        epa.[EventBIsExit],
        NULL AS [PropertyValueNumeric],
        NULL AS [PropertyValueAlpha],
		@SessionID
    FROM
        [dbo].[EventPairAnomalies] epa
        JOIN [dbo].[Models] m
            ON m.[ModelID] = epa.[ModelID]
        JOIN [dbo].[Metrics] met
            ON met.[MetricID] = m.[MetricID]
    WHERE
        epa.[ModelID] = @ModelID 
    UNION
    SELECT
        NULL AS [ModelID],
        cpp.[CaseID],
        NULL AS [EventIDA],
        NULL AS [EventIDB],
        'CaseProperty' AS [Category],
        cpp.[PropertyName] AS [Attribute],
        NULL AS [EventA],
        NULL AS [EventB],
        NULL AS [metric_zscore],
        NULL AS [metric_value],
        NULL AS [transistion_prob],
        NULL AS [EventAIsEntry],
        NULL AS [EventBIsExit],
        cpp.[PropertyValueNumeric],
        cpp.[PropertyValueAlpha],
		@SessionID
    FROM
        [dbo].[CasePropertiesParsed] cpp
    WHERE
        EXISTS
        (
			SELECT DISTINCT
				mdt.CaseID
			FROM
				WORK.ModelDrillThrough mdt
			WHERE
				SessionID=@SessionID AND
				mdt.CaseID=cpp.CaseID
        );

	IF @DisplayReport=1
	BEGiN
		SELECT * FROM WORK.CaseCharacteristics WHERE SessionID=@SessionID
		DELETE FROM WORK.CaseCharacteristics WHERE SessionID=@SessionID
	END

	DELETE FROM WORK.ModelDrillThrough WHERE @SessionID=SessionID
END
GO
/****** Object:  StoredProcedure [dbo].[sp_CasePropertyProfiling]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Stored Procedure": "dbo.sp_CasePropertyProfiling",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-03-29",
  "Description": "Profiles parsed case properties by property name, case type, source, and source column mapping. Returns counts of cases and counts of distinct observed values for each grouped property context.",
  "Utilization": "Use when you want to understand how case properties are distributed across case types and sources, especially for metadata cleanup, source-column mapping, semantic profiling, and identifying which properties have high or low cardinality.",
  "Input Parameters": [],
  "Output Notes": [
    {
      "name": "PropertyName",
      "type": "NVARCHAR(20)",
      "description": "Parsed case property name from dbo.CasePropertiesParsed."
    },
    {
      "name": "CaseTypeDescription",
      "type": "NVARCHAR",
      "description": "Description of the case type associated with the cases carrying the property."
    },
    {
      "name": "SourceID",
      "type": "INT",
      "description": "Source identifier for the cases carrying the property."
    },
    {
      "name": "SourceDescription",
      "type": "NVARCHAR",
      "description": "Description of the source associated with the case."
    },
    {
      "name": "SourceName",
      "type": "NVARCHAR",
      "description": "Name of the source associated with the case."
    },
    {
      "name": "SourceColumnID",
      "type": "INT",
      "description": "Mapped SourceColumnID when the property name matches a source column."
    },
    {
      "name": "SourceColumnTable",
      "type": "NVARCHAR",
      "description": "Source table name from SourceColumns.TableName or Sources.DefaultTableName."
    },
    {
      "name": "SourceColumnName",
      "type": "NVARCHAR",
      "description": "Matched source column name when available."
    },
    {
      "name": "SourceColumnDescription",
      "type": "NVARCHAR",
      "description": "Description of the matched source column when available."
    },
    {
      "name": "Cases",
      "type": "INT",
      "description": "Number of parsed case-property rows in the grouped context."
    },
    {
      "name": "DistinctValues",
      "type": "INT",
      "description": "Count of distinct observed values for the property in the grouped context, using alpha value when present and numeric value otherwise."
    }
  ],
  "Referenced objects": [
    {
      "name": "dbo.CasePropertiesParsed",
      "type": "Table",
      "description": "Parsed case-level properties used as the primary source of profiled property data."
    },
    {
      "name": "dbo.Cases",
      "type": "Table",
      "description": "Provides CaseID, CaseTypeID, and SourceID for joining parsed properties to case metadata."
    },
    {
      "name": "dbo.CaseTypes",
      "type": "Table",
      "description": "Provides descriptive labels for case types."
    },
    {
      "name": "dbo.Sources",
      "type": "Table",
      "description": "Provides source descriptions, source names, and default table names."
    },
    {
      "name": "dbo.SourceColumns",
      "type": "Table",
      "description": "Provides optional mappings from parsed property names to source columns."
    }
  ]
}

Sample utilization:

    EXEC dbo.sp_CasePropertyProfiling;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is not production-hardened: error handling, security, concurrency, indexing, query plan tuning, partitioning, and related concerns have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara.

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE   PROCEDURE [dbo].[sp_CasePropertyProfiling]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UnknownSourceID INT=(SELECT SourceID FROM [dbo].[Sources] WHERE [Name]='Unknown')

    SELECT
    	cpp.PropertyName,
    	ct.[Description] AS [CaseTypeDescription],
    	c.SourceID,
    	s.[Description] AS SourceDescription,
    	s.[Name] AS SourceName,
    	sc.SourceColumnID,
    	COALESCE(sc.TableName,s.DefaultTableName) AS SourceColumnTable,
    	sc.ColumnName AS SourceColumnName,
    	sc.[Description] AS SourceColumnDescription,
    	COUNT(*) AS Cases,
    	COUNT(DISTINCT 
    		CASE 
    			WHEN cpp.PropertyValueAlpha IS NULL THEN CAST(cpp.PropertyValueNumeric AS VARCHAR(50)) 
    			ELSE cpp.propertyValueAlpha END) AS DistinctValues
    FROM 
    	[dbo].[CasePropertiesParsed] cpp
    	JOIN Cases c (NOLOCK) ON c.CaseID=cpp.CaseID
    	JOIN CaseTypes ct (NOLOCK) on ct.CaseTypeID=c.CaseTypeID
    	LEFT JOIN Sources s (NOLOCK) ON s.SourceID=c.SourceID
    	LEFT JOIN SourceColumns sc (NOLOCK) ON sc.SourceID=s.SourceID
    		AND sc.ColumnName=cpp.PropertyName
    GROUP BY
    	cpp.PropertyName,
    	ct.[Description],
    	c.SourceID,
    	s.[Description],
    	s.[Name],
    	sc.SourceColumnID,
    	COALESCE(sc.TableName,s.DefaultTableName),
    	sc.ColumnName,
    	sc.[Description]
    ORDER BY
    	cpp.PropertyName
END
GO
/****** Object:  StoredProcedure [dbo].[sp_CompareEventProximities]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "sp_CompareEventProximities",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-03-22",
  "Description": [
    "Compares the event footprints of two tuple-defined populations and returns the event properties found for both selections.",
    "Helps identify where two tuple-defined activity streams may intersect through shared event properties, objects, actors, or sources."
  ],
  "Utilization": "Use when you want to compare two tuple-defined populations and find event properties that appear in both selections. Helpful for exploratory root-cause work, overlap analysis, and discovering common objects, actors, sources, or other shared event-level signals that may connect two different activity streams.",
  "Input Parameters": [
    { "name": "@CaseFilterProperties1", "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON case filter for the first tuple-defined population." },
    { "name": "@CaseFilterProperties2", "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON case filter for the second tuple-defined population." },
    { "name": "@StartDateTime",         "type": "DATETIME",      "default": "NULL", "description": "Lower bound of event dates; defaults to '1900-01-01' if NULL." },
    { "name": "@EndDateTime",           "type": "DATETIME",      "default": "NULL", "description": "Upper bound of event dates; defaults to '2050-12-31' if NULL." }
  ],
  "Output Notes": [
    { "name": "CaseID",               "type": "INT",           "description": "Case identifier of the selected event." },
    { "name": "EventID",              "type": "BIGINT",        "description": "Event identifier for the selected event." },
    { "name": "Event",                "type": "NVARCHAR(20)",  "description": "Event name from WORK.SelectedEvents." },
    { "name": "PropertyName",         "type": "NVARCHAR(200)", "description": "Name of the parsed event property." },
    { "name": "EventDate",            "type": "DATETIME",      "description": "Timestamp of the selected event." },
    { "name": "PropertyValueAlpha",   "type": "NVARCHAR(MAX)", "description": "Alpha/string value of the property, if applicable." },
    { "name": "PropertyValueNumeric", "type": "FLOAT",         "description": "Numeric value of the property, if applicable." },
    { "name": "SourceServer",         "type": "NVARCHAR(200)", "description": "Source server name from metadata tables." },
    { "name": "SourceTableName",      "type": "NVARCHAR(200)", "description": "Source table name from metadata tables." },
    { "name": "SourceColumn",         "type": "NVARCHAR(200)", "description": "Source column name from metadata tables." },
    { "name": "SourceColumnIsKey",    "type": "BIT",           "description": "Indicates whether the source column is marked as a key." },
    { "name": "SessionID",            "type": "UNIQUEIDENTIFIER", "description": "Session identifier indicating which tuple-defined population the row came from." }
  ],
  "Referenced objects": [
    { "name": "[dbo].sp_SelectedEvents",      "type": "Stored Procedure", "description": "Selects events into WORK.SelectedEvents for a specific session." },
    { "name": "WORK.SelectedEvents",        "type": "Table",            "description": "Session-scoped selected event rows." },
    { "name": "[dbo].EventPropertiesParsed",  "type": "Table",            "description": "Parsed event properties joined back to selected events." },
    { "name": "[dbo].SourceColumns",          "type": "Table",            "description": "Metadata about source columns." },
    { "name": "[dbo].Sources",                "type": "Table",            "description": "Metadata about source systems." }
  ]
}

Sample utilization:

EXEC [dbo].[sp_CompareEventProximities]
    @CaseFilterProperties1 = '{"LocationID":1,"EmployeeID":1}',
    @CaseFilterProperties2 = '{"LocationID":1,"EmployeeID":4}',
    @StartDateTime = NULL,
    @EndDateTime = NULL,
	@ReturnOnlyMatchedProperties=0 --0 means return all property values, then LLM will evaluate what is similar.

EXEC [dbo].[sp_CompareEventProximities]
    @CaseFilterProperties1 = '{"LocationID":1,"CustomerID":2}',
    @CaseFilterProperties2 = '{"LocationID":1,"CustomerID":4}',
    @StartDateTime = '2020-01-01',
    @EndDateTime = '2025-12-31',
	@ReturnOnlyMatchedProperties=1

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, concurrency, indexing, query-plan tuning, partitioning, etc., have been omitted or simplified.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2026 Eugene Asahara. All rights reserved.

Purpose:
    Compare the event footprints of two tuple-defined populations and identify where
    their activities intersect through shared event properties, objects, actors, or sources.

Value:
    This helps reveal hidden relationships, common touchpoints, and possible process
    overlap between two tuples that may not be obvious from the tuples alone.

Notes:
	- This is intended to be fed to an LLM for similarity. So it returns descriptive information.
*/
CREATE PROCEDURE [dbo].[sp_CompareEventProximities]
(
	@EventSet NVARCHAR(MAX)=NULL, --NULL means ALL events. For this sproc, we don't know what events might connect the two case tuples.
    @CaseFilterProperties1 NVARCHAR(MAX), 
    @CaseFilterProperties2 NVARCHAR(MAX),
    @StartDateTime DATETIME = NULL,
    @EndDateTime DATETIME = NULL,
	@ReturnOnlyMatchedProperties BIT=0
)
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @SessionID1 UNIQUEIDENTIFIER = NEWID()
    DECLARE @SessionID2 UNIQUEIDENTIFIER = NEWID()

	DECLARE @ActualProperties INT=0	--EventProperties.ActualProperties

    SELECT
        @StartDateTime = StartDateTime,
        @EndDateTime = EndDateTime
    FROM [dbo].SetDefaultModelParameters
    (
        @StartDateTime,
        @EndDateTime,
        NULL,
        NULL,
        NULL
    );


    EXEC [dbo].sp_SelectedEvents
         @EventSet = @EventSet, --For this sproc, @EventSet should usually be NULL, for ALL events.
         @enumerate_multiple_events = 0,
         @StartDateTime = @StartDateTime,
         @EndDateTime = @EndDateTime,
         @transforms = NULL,
         @ByCase = 1,
         @metric = NULL,
         @CaseFilterProperties = @CaseFilterProperties1,
         @EventFilterProperties = NULL,
         @SessionID = @SessionID1

    EXEC [dbo].sp_SelectedEvents
         @EventSet = @EventSet,
         @enumerate_multiple_events = 0,
         @StartDateTime = @StartDateTime,
         @EndDateTime = @EndDateTime,
         @transforms = NULL,
         @ByCase = 1,
         @metric = NULL,
         @CaseFilterProperties = @CaseFilterProperties2,
         @EventFilterProperties = NULL,
         @SessionID = @SessionID2


    SELECT
		CASE WHEN se.SessionID=@SessionID1 THEN @CaseFilterProperties1 ELSE @CaseFilterProperties2 END AS [CaseProperties],
        CASE WHEN se.SessionID=@SessionID1 THEN 1 ELSE 2 END AS [CaseSet], --Is this from Case Set 1 or 2?
        se.CaseID,
		ct.[Description] AS [CaseType],
		ct.[IRI] AS [CaseTypeIRI],
        se.EventID,
		e.[Description] AS EventDescription,
		e.IRI AS [EventIRI],
        se.[Event],
        epp.PropertyName,
        se.EventDate,
        epp.PropertyValueAlpha,
        epp.PropertyValueNumeric,
        s.ServerName AS SourceServer,
        sc.TableName AS SourceTableName,
        sc.ColumnName AS SourceColumn,
        sc.IsKey AS SourceColumnIsKey,
		sc.[Description] AS [SourceColumnDescription]
    FROM 
        WORK.SelectedEvents se WITH (NOLOCK)
		JOIN Cases c (NOLOCK) ON c.CaseID=se.CaseID
		JOIN CaseTypes ct (NOLOCK) ON ct.CaseTypeID=c.CaseTypeID
		JOIN DimEvents e (NoLOCK) ON e.[Event]=se.[Event]
        JOIN dbo.EventPropertiesParsed epp WITH (NOLOCK) --Not LEFT JOIN because we're interested in property values.
            ON epp.EventID = se.EventID AND epp.PropertySource=@ActualProperties
        LEFT JOIN dbo.SourceColumns AS sc WITH (NOLOCK)
            ON sc.SourceColumnID = epp.SourceColumnID 
        LEFT JOIN dbo.Sources AS s WITH (NOLOCK)
            ON s.SourceID = sc.SourceID
    WHERE
        se.SessionID IN (@SessionID1,@SessionID2) AND
        (
            @ReturnOnlyMatchedProperties = 0
            OR
            EXISTS
            (
                SELECT 1
                FROM WORK.SelectedEvents se2 WITH (NOLOCK)
                JOIN dbo.EventPropertiesParsed epp2 WITH (NOLOCK)
                    ON epp2.EventID = se2.EventID
                WHERE
                    epp2.PropertySource = @ActualProperties
                    AND epp2.PropertyName = epp.PropertyName
                    AND se2.SessionID =
                        CASE 
                            WHEN se.SessionID = @SessionID1 THEN @SessionID2
                            ELSE @SessionID1
                        END
                    AND
                    (
                        (epp.PropertyValueAlpha IS NOT NULL 
                         AND epp2.PropertyValueAlpha = epp.PropertyValueAlpha)
                        OR
                        (epp.PropertyValueNumeric IS NOT NULL
                         AND epp2.PropertyValueNumeric = epp.PropertyValueNumeric)
                    )
            )
        );

	--Clean up.
    DELETE FROM WORK.SelectedEvents WHERE SessionID IN (@SessionID1,@SessionID2)
END

GO
/****** Object:  StoredProcedure [dbo].[sp_ConditionalProbabilityTable]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "sp_ConditionalProbabilityTable",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": "For each case or time-group (CASEID/DAY/MONTH/YEAR), counts occurrences of two event sequences A and B so you can compute conditional probabilities across cases.",
  "Utilization": "Use when you want the conditional-probability table logic exposed as a stored procedure, especially for workflows that prefer procedural invocation or writing results to work tables.",
  "Input Parameters": [
    { "name": "@SeqA",                   "type": "NVARCHAR(MAX)", "default": null, "description": "CSV list defining sequence A." },
    { "name": "@SeqB",                   "type": "NVARCHAR(MAX)", "default": null, "description": "CSV list defining sequence B." },
    { "name": "@EventSet",               "type": "NVARCHAR(MAX)", "default": null, "description": "Optional CSV of all events; if NULL, union of SeqA and SeqB." },
    { "name": "@StartDateTime",          "type": "DATETIME",       "default": null, "description": "Lower bound for event dates." },
    { "name": "@EndDateTime",            "type": "DATETIME",       "default": null, "description": "Upper bound for event dates." },
    { "name": "@transforms",             "type": "NVARCHAR(MAX)", "default": null, "description": "Optional JSON for normalizing event names." },
    { "name": "@CaseFilterProperties",   "type": "NVARCHAR(MAX)", "default": null, "description": "JSON of case-level filter properties." },
    { "name": "@EventFilterProperties",  "type": "NVARCHAR(MAX)", "default": null, "description": "JSON of event-level filter properties." },
    { "name": "@GroupType",               "type": "NVARCHAR(10)",   "default": null, "description": "Grouping key: 'CASEID','DAY','MONTH','YEAR'." }
  ],
  "Output Notes": [
    { "name": "GroupTypeKey", "type": "INT", "description": "CaseID or time bucket key per GroupType grouping." },
    { "name": "a",       "type": "INT", "description": "Count of sequence-A events per GroupTypeKey." },
    { "name": "b",       "type": "INT", "description": "Count of sequence-B events per GroupTypeKey." }
  ],
  "Referenced objects": [
    { "name": "dbo.SelectedEvents",    "type": "Table-Valued Function", "description": "Retrieves filtered events for given parameters." },
    { "name": "dbo.EventSetByCode",    "type": "Scalar Function",        "description": "Resolves EventSet code to CSV of events." },
    { "name": "STRING_SPLIT",          "type": "Built-in TVF",           "description": "Splits CSV into rows." }
  ]
}


Sample utilization:

EXEC dbo.sp_ConditionalProbabilityTable
     @SeqA = 'arrive,greeted',
     @SeqB = 'intro,order',
     @EventSet = 'restaurantguest',
     @StartDateTime = '1900-01-01',
     @EndDateTime = '2050-12-31',
     @transforms = NULL,
     @CaseFilterProperties = NULL,
     @EventFilterProperties = NULL,
     @GroupType = 'Day';

Notes:

    The Probability of B given A.
    Given 'arrive,greeted', what is the probability of 'intro,order'?
*/

CREATE PROCEDURE [dbo].[sp_ConditionalProbabilityTable]

	@SeqA NVARCHAR(MAX), --csv. 
	@SeqB NVARCHAR(MAX), --csv sequence.
	@EventSet NVARCHAR(MAX), -- IF NULL, this will be constructed from @SeA and @SeqB
	@StartDateTime DATETIME,
	@EndDateTime DATETIME,
	@transforms NVARCHAR(MAX),
	@CaseFilterProperties NVARCHAR(MAX),
	@EventFilterProperties NVARCHAR(MAX),
	@GroupType NVARCHAR(10) --NULL will default to CASEID. Values: 'CASEID','DAY','MONTH','YEAR'

AS
BEGIN
;
	--These are variables required for SelectedEvents, but not needed for this Bayesian calculation.
	DECLARE @ByCase BIT=1 --Yes.
	DECLARE @metric NVARCHAR(20)=NULL
	DECLARE @IsSequence BIT=1 --We're looking for a sequence, not a set.
	DECLARE @enumerate_multiple_events BIT=0

	SET @GroupType=dbo.DefaultGroupType(@GroupType)


	DECLARE @tempSeq NVARCHAR(MAX)= (SELECT [dbo].[EventSetByCode](@SeqA, @IsSequence))
	SET @SeqA = CASE WHEN @tempSeq IS NULL THEN @SeqA ELSE @tempSeq END

	SET @tempSeq = (SELECT [dbo].[EventSetByCode](@SeqB,@IsSequence))
	SET @SeqB = CASE WHEN @tempSeq IS NULL THEN @SeqB ELSE @tempSeq END

	-- Split the A and B sequences so we can load up the events.
	DECLARE @sqA TABLE ([Event] NVARCHAR(50),[Rank] INT, UNIQUE ([Event],[Rank])) 
	INSERT INTO @sqA
		SELECT [Value] AS [Event], ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [rank] from string_split(@SeqA,',')
	DECLARE @ArCount INT=@@ROWCOUNT
	DECLARE @Ar1 NVARCHAR(50)=(SELECT [Event] FROM @sqA WHERE [Rank]=1)

	DECLARE @sqB TABLE ([Event] NVARCHAR(50),[Rank] INT, UNIQUE ([Event],[Rank])) 
	INSERT INTO @sqB
		SELECT [Value] AS [Event], ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [rank] from string_split(@SeqB,',')
	DECLARE @BrCount INT=@@ROWCOUNT
	DECLARE @Br1 NVARCHAR(50)=(SELECT [Event] FROM @sqB WHERE [Rank]=1)

	-- If we didn't include the list of events to get with SelectedEvents, default it to the UNION of SeqA and SeqB.
	--This will make it fastest since we're returning the minimum rows required. However, if we are looking for truly
	--consecutive events, we need to get all events for the case type.
	IF @EventSet IS NULL
	BEGIN
		SET @EventSet=(SELECT STRING_AGG([Event],',') FROM (SELECT [Event] FROM @sqA UNION SELECT [Event] FROM @sqB) t) 
	END

	DECLARE @SessionID UNIQUEIDENTIFIER=NEWID()

	EXEC dbo.sp_SelectedEvents
		 @EventSet = @EventSet,
		 @enumerate_multiple_events = @enumerate_multiple_events,
		 @StartDateTime = @StartDateTime,
		 @EndDateTime = @EndDateTime,
		 @transforms = @transforms,
		 @ByCase = @ByCase,
		 @metric = @metric,
		 @CaseFilterProperties = @CaseFilterProperties,
		 @EventFilterProperties = @EventFilterProperties,
		 @SessionID=@SessionID

	SELECT	
		t.GroupTypeKey,
		SUM(CASE WHEN t.a_rank IS NULL THEN 0 ELSE 1 END) AS [a],
		SUM(CASE WHEN t.b_rank IS NULL THEN 0 ELSE 1 END) AS [b]
	FROM
	(
		SELECT 
			t.[EventID],
			t.[EventDate],
			t.[rank],
			t.CaseID,
			CASE
				WHEN @GroupType='DAY' THEN cast(convert(char(8), EventDate, 112) as int)
				WHEN @GroupType='MONTH' THEN YEAR(EventDate)*100+MONTH(EventDate)
				WHEN @GroupType='YEAR' THEN YEAR(EventDate)
				ELSE CaseID
			END AS GroupTypeKey,
			t.[Event],
			a.[Rank] AS a_rank,
			b.[Rank] As b_rank
		FROM 
			WORK.SelectedEvents t
			LEFT JOIN @sqA a ON a.[Event]=t.[Event]
			LEFT JOIN @sqB b ON b.[Event]=t.[Event]
	) t
	GROUP BY
		t.GroupTypeKey
	RETURN 
END
GO
/****** Object:  StoredProcedure [dbo].[sp_DrillThroughToModelEvents]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Table-Valued Function": "DrillThroughToModelEvents",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Retrieves all underlying events (with ordering, occurrence counts, and metric values) that made up a specified Markov model by its ModelID, leveraging the parameters stored for that model.",
  "Utilization": "Use when you want the event rows behind a stored model loaded procedurally, especially when a downstream step expects a work table or staged result rather than a TVF.",
  "Input Parameters": [
    { "name": "@ModelID", "type": "INT",   "default": null, "description": "Identifier of the model whose component events should be returned." }
  ],
  "Output Notes": [
    { "name": "CaseID",              "type": "INT",         "description": "Case identifier associated with the event." },
    { "name": "Event",               "type": "NVARCHAR(20)", "description": "Name of the event." },
    { "name": "EventDate",           "type": "DATETIME",     "description": "Timestamp when the event occurred." },
    { "name": "Rank",                "type": "INT",         "description": "Sequential position of the event within its case." },
    { "name": "EventOccurence",      "type": "BIGINT",      "description": "Count of how many times this event has occurred in the sequence." },
    { "name": "MetricActualValue",   "type": "FLOAT",       "description": "Observed metric value at the time of the event." },
    { "name": "MetricExpectedValue", "type": "FLOAT",       "description": "Expected metric value for the event based on the model." }
  ],
  "Referenced objects": [
    { "name": "dbo.Models",          "type": "Table",                "description": "Stores model configuration parameters." },
    { "name": "dbo.EventSets",       "type": "Table",                "description": "Defines which events comprise each model's event set." },
    { "name": "dbo.Transforms",      "type": "Table",                "description": "Optional event mapping transformations applied before model computation." },
    { "name": "dbo.Metrics",         "type": "Table",                "description": "Defines available metric types and methods." },
    { "name": "dbo.SelectedEvents",  "type": "Table-Valued Function", "description": "Filters and enriches raw EventsFact according to model parameters." }
  ]
}


Sample utilization:
    EXEC sp_DrillThroughToModelEvents 24

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security, concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE   PROCEDURE [dbo].[sp_DrillThroughToModelEvents]
(
    @ModelID INT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Order INT;
    DECLARE @EventSet NVARCHAR(MAX);
    DECLARE @enumerate_multiple_events INT;
    DECLARE @StartDateTime DATETIME;
    DECLARE @EndDateTime DATETIME;
    DECLARE @transforms NVARCHAR(MAX);
    DECLARE @ByCase BIT = 1;
    DECLARE @metric NVARCHAR(20);
    DECLARE @CaseFilterProperties NVARCHAR(MAX);
    DECLARE @EventFilterProperties NVARCHAR(MAX);
	DECLARE @SessionID UNIQUEIDENTIFIER=NEWID()

    IF @ModelID IS NOT NULL
    BEGIN
        SELECT
            @Order = m.[Order],
            @EventSet = es.EventSet,
            @enumerate_multiple_events = m.enumerate_multiple_events,
            @StartDateTime = m.StartDateTime,
            @EndDateTime = m.EndDateTime,
            @transforms = t.transforms,
            @ByCase = m.ByCase,
            @metric = mt.Metric,
            @CaseFilterProperties = m.CaseFilterProperties,
            @EventFilterProperties = m.EventFilterProperties
        FROM [dbo].[Models] m
        JOIN [dbo].[EventSets] es
            ON es.EventSetKey = m.EventSetKey
        LEFT JOIN [dbo].[Transforms] t
            ON t.transformskey = m.transformskey
        LEFT JOIN [dbo].[Metrics] mt
            ON mt.MetricID = m.MetricID
        WHERE m.ModelID = @ModelID;

		EXEC dbo.sp_SelectedEvents
			 @EventSet = @EventSet,
			 @enumerate_multiple_events = @enumerate_multiple_events,
			 @StartDateTime = @StartDateTime,
			 @EndDateTime = @EndDateTime,
			 @transforms = @transforms,
			 @ByCase = @ByCase,
			 @metric = @metric,
			 @CaseFilterProperties = @CaseFilterProperties,
			 @EventFilterProperties = @EventFilterProperties,
			 @SessionID=@SessionID


    END;

	INSERT INTO WORK.DrillThroughToModelEvents
		SELECT
			e.CaseID,
			e.[Event],
			e.EventDate,
			e.[Rank],
			e.[EventOccurence],
			e.MetricInputValue AS MetricActualValue,
			e.MetricOutputValue AS MetricExpectedValue,
			@SessionID
		FROM
			WORK.SelectedEvents e
		WHERE
			e.SessionID=@SessionID
		ORDER BY CaseID, [Rank];

	DELETE FROM WORK.SelectedEvents WHERE SessionID=@SessionID

END
GO
/****** Object:  StoredProcedure [dbo].[sp_IntersegmentEvents]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*
Metadata JSON:
{
  "Stored Procedure": "sp_IntersegmentEvents",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-04-21",
  "Description": "Writes to WORK.IntersegmentEvents all events that occur within the time window defined by a segment EventA → EventB for a given model or for all models containing that segment. Supports optional lag and lead minutes to widen the search window before EventA and after EventB. Uses @SessionID so the procedure can either display results directly when called independently or persist rows for a caller managing a WORK-session pipeline.",
  "Utilization": "Use when you want to inspect what else was happening during or around a segment, especially when a transition looks unusually slow or suspicious. Helpful for lateral intersegment event scans, anomaly investigation, broader contextual analysis, and identifying outside influences such as traffic, outages, maintenance, workload spikes, or unrelated operational events that occurred during the same time window.",
  "Input Parameters": [
    { "name": "@ModelID",     "type": "INT",               "default": NULL, "description": "Identifier of the model whose segment windows to inspect; NULL searches all models containing the specified EventA → EventB segment." },
    { "name": "@EventA",      "type": "NVARCHAR(50)",      "default": null, "description": "Name of the anchor start event in the segment." },
    { "name": "@EventB",      "type": "NVARCHAR(50)",      "default": null, "description": "Name of the anchor end event in the segment." },
    { "name": "@LagMinutes",  "type": "INT",               "default": NULL, "description": "Optional number of minutes to extend the search window backward before the anchor EventA time. NULL is treated as 0." },
    { "name": "@LeadMinutes", "type": "INT",               "default": NULL, "description": "Optional number of minutes to extend the search window forward after the anchor EventB time. NULL is treated as 0." },
    { "name": "@SessionID",   "type": "UNIQUEIDENTIFIER",  "default": NULL, "description": "Session identifier for WORK.IntersegmentEvents output. If NULL, the procedure generates one, displays the result set, and deletes the session rows at the end. If supplied, rows remain in WORK.IntersegmentEvents for caller-managed downstream use." }
  ],
  "Output Notes": [
    { "name": "SessionID",        "type": "UNIQUEIDENTIFIER", "description": "Session identifier used to isolate rows written by this execution." },
    { "name": "Seg_ModelID",      "type": "INT",              "description": "ModelID of the segment whose time window is being scanned." },
    { "name": "Seg_CaseID",       "type": "BIGINT",           "description": "CaseID where the anchor segment occurs." },
    { "name": "Seg_EventA",       "type": "NVARCHAR(50)",     "description": "Anchor start event name." },
    { "name": "Seg_EventA_ID",    "type": "BIGINT",           "description": "EventID of the anchor start event." },
    { "name": "Seg_EventADate",   "type": "DATETIME2",        "description": "Timestamp of the anchor start event." },
    { "name": "Seg_EventB",       "type": "NVARCHAR(50)",     "description": "Anchor end event name." },
    { "name": "Seg_EventB_ID",    "type": "BIGINT",           "description": "EventID of the anchor end event." },
    { "name": "Seg_EventBDate",   "type": "DATETIME2",        "description": "Timestamp of the anchor end event." },
    { "name": "LagMinutes",       "type": "INT",              "description": "Backward window extension in minutes applied before Seg_EventADate." },
    { "name": "LeadMinutes",      "type": "INT",              "description": "Forward window extension in minutes applied after Seg_EventBDate." },
    { "name": "WindowStartDate",  "type": "DATETIME2",        "description": "Effective start of the scan window after applying LagMinutes." },
    { "name": "WindowEndDate",    "type": "DATETIME2",        "description": "Effective end of the scan window after applying LeadMinutes." },
    { "name": "CaseID",           "type": "BIGINT",           "description": "CaseID of an event found within the scan window." },
    { "name": "EventID",          "type": "BIGINT",           "description": "EventID of an event found within the scan window." },
    { "name": "Event",            "type": "NVARCHAR(50)",     "description": "Name of an event found within the scan window." },
    { "name": "EventDate",        "type": "DATETIME2",        "description": "Timestamp of an event found within the scan window." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelEvents",            "type": "Table",               "description": "Defines first-order transition segments for each model and is used to locate matching models when @ModelID is NULL." },
    { "name": "dbo.ModelDrillThrough",      "type": "Table-Valued Function","description": "Returns the detailed EventA → EventB anchor rows for each matching model." },
    { "name": "dbo.vwEventsFact",           "type": "View",                "description": "Provides the broader event stream searched for events occurring within each intersegment window." },
    { "name": "WORK.IntersegmentEvents",    "type": "Table",               "description": "Session-backed WORK table that stores the output rows for this procedure." }
  ]
}

Sample utilization:

    This sample inspects what else happened during or around a segment that looks slow.

    -- Independent call:
    -- Returns the result set directly, then deletes the session rows.
    EXEC dbo.sp_IntersegmentEvents
        @ModelID = 24,
        @EventA = 'lv-csv1',
        @EventB = 'homedepot1',
        @LagMinutes = 15,
        @LeadMinutes = 10;

    -- Caller-managed session:
    -- Leaves rows in WORK.IntersegmentEvents for downstream processing.
    DECLARE @SessionID UNIQUEIDENTIFIER = NEWID();

    EXEC dbo.sp_IntersegmentEvents
        @ModelID = 24,
        @EventA = 'lv-csv1',
        @EventB = 'homedepot1',
        @LagMinutes = 15,
        @LeadMinutes = 10,
        @SessionID = @SessionID;

    SELECT *
    FROM WORK.IntersegmentEvents
    WHERE SessionID = @SessionID
    ORDER BY Seg_ModelID, Seg_CaseID, EventDate, EventID;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, concurrency, indexing, query plan tuning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2026 Eugene Asahara. All rights reserved.
*/



CREATE PROCEDURE [dbo].[sp_IntersegmentEvents]
    @ModelID        INT = NULL,
    @EventA         NVARCHAR(50),
    @EventB         NVARCHAR(50),
    @LagMinutes     INT = NULL,
    @LeadMinutes    INT = NULL,
    @SessionID      UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DisplayResult BIT = 0;
    IF @SessionID IS NULL
    BEGIN
        SET @SessionID = NEWID();
        SET @DisplayResult = 1;  -- Since this sproc was called independently, display the result at the end.
    END

    SET @LagMinutes = ISNULL(@LagMinutes, 0);
    SET @LeadMinutes = ISNULL(@LeadMinutes, 0);

    -- Defensive cleanup for reused SessionID
    DELETE FROM WORK.IntersegmentEvents
    WHERE SessionID = @SessionID;

    ;WITH ModelIDs AS
    (
        SELECT DISTINCT
            me.ModelID
        FROM dbo.ModelEvents me WITH (NOLOCK)
        WHERE
            @ModelID IS NULL
            AND me.EventA = @EventA
            AND me.EventB = @EventB

        UNION ALL

        SELECT @ModelID
        WHERE @ModelID IS NOT NULL
    ),
    seg AS
    (
        SELECT
            m.ModelID,
            dt.CaseID,
            dt.EventA_ID,
            dt.EventB_ID,
            dt.EventDate_A,
            dt.EventDate_B,
            DATEADD(MINUTE, -@LagMinutes,  dt.EventDate_A) AS WindowStartDate,
            DATEADD(MINUTE,  @LeadMinutes, dt.EventDate_B) AS WindowEndDate
        FROM ModelIDs m
        CROSS APPLY dbo.ModelDrillThrough(m.ModelID, @EventA, @EventB) dt
    )
    INSERT INTO WORK.IntersegmentEvents
    (
        SessionID,
        Seg_ModelID,
        Seg_CaseID,
        Seg_EventA,
        Seg_EventA_ID,
        Seg_EventADate,
        Seg_EventB,
        Seg_EventB_ID,
        Seg_EventBDate,
        LagMinutes,
        LeadMinutes,
        WindowStartDate,
        WindowEndDate,
        CaseID,
        EventID,
        [Event],
        EventDate
    )
    SELECT
        @SessionID                                  AS SessionID,
        seg.ModelID                                 AS Seg_ModelID,
        seg.CaseID                                  AS Seg_CaseID,
        @EventA                                     AS Seg_EventA,
        seg.EventA_ID                               AS Seg_EventA_ID,
        seg.EventDate_A                             AS Seg_EventADate,
        @EventB                                     AS Seg_EventB,
        seg.EventB_ID                               AS Seg_EventB_ID,
        seg.EventDate_B                             AS Seg_EventBDate,
        @LagMinutes                                 AS LagMinutes,
        @LeadMinutes                                AS LeadMinutes,
        seg.WindowStartDate                         AS WindowStartDate,
        seg.WindowEndDate                           AS WindowEndDate,
        f.CaseID,
        f.EventID,
        f.[Event],
        f.EventDate
    FROM seg
    JOIN dbo.vwEventsFact f
        ON f.EventDate BETWEEN seg.WindowStartDate AND seg.WindowEndDate
    WHERE
        f.EventID NOT IN (seg.EventA_ID, seg.EventB_ID);

    IF @DisplayResult = 1
    BEGIN
        SELECT
            SessionID,
            Seg_ModelID,
            Seg_CaseID,
            Seg_EventA,
            Seg_EventA_ID,
            Seg_EventADate,
            Seg_EventB,
            Seg_EventB_ID,
            Seg_EventBDate,
            LagMinutes,
            LeadMinutes,
            WindowStartDate,
            WindowEndDate,
            CaseID,
            EventID,
            [Event],
            EventDate
        FROM WORK.IntersegmentEvents
        WHERE SessionID = @SessionID
        ORDER BY Seg_ModelID, Seg_CaseID, EventDate, EventID;

        DELETE FROM WORK.IntersegmentEvents
        WHERE SessionID = @SessionID;
    END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_ModelDrillThrough]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "sp_ModelDrillThrough",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-16",
  "Description": "Retrieves paired events (EventA -> EventB) and their details for a specified Markov model, including elapsed minutes, rank, and occurrence counts.",
  "Utilization": "Use when you want paired EventA→EventB rows behind a specific model, especially for inspecting real case evidence behind a transition and explaining how a model behaves.",
  "Input Parameters": [
    { "name": "@ModelID",  "type": "INT",            "default": null, "description": "Identifier of the Markov model to drill through." },
    { "name": "@EventA",   "type": "NVARCHAR(20)",   "default": null, "description": "Optional filter for the first event; null returns all." },
    { "name": "@EventB",   "type": "NVARCHAR(20)",   "default": null, "description": "Optional filter for the subsequent event; null returns all." }
  ],
  "Output Notes": [
    { "name": "CaseID",         "type": "INT",         "description": "Case identifier." },
    { "name": "EventA",         "type": "NVARCHAR(20)", "description": "Name of the first event in the pair." },
    { "name": "EventB",         "type": "NVARCHAR(20)", "description": "Name of the subsequent event in the pair." },
    { "name": "EventDate_A",    "type": "DATETIME",     "description": "Timestamp of EventA." },
    { "name": "EventDate_B",    "type": "DATETIME",     "description": "Timestamp of EventB." },
    { "name": "Minutes",        "type": "FLOAT",        "description": "Elapsed time in minutes between EventA and EventB." },
    { "name": "Rank",           "type": "INT",          "description": "Sequential rank of EventB within its case." },
    { "name": "EventOccurence", "type": "INT",          "description": "Count of occurrences of EventB up to that rank." },
    { "name": "EventA_ID",      "type": "INT",          "description": "Internal EventID of EventA." },
    { "name": "EventB_ID",      "type": "INT",          "description": "Internal EventID of EventB." },
    { "name": "EventA_SourceColumnID",     "type": "INT",          "description": "ID of EventA for use in linking to semantic layer" }
  ],
  "Referenced objects": [
    { "name": "dbo.Models",            "type": "Table",                  "description": "Stores Markov model definitions and parameters." },
    { "name": "dbo.Metrics",           "type": "Table",                  "description": "Lookup of metric names and methods." },
    { "name": "dbo.Transforms",        "type": "Table",                  "description": "Optional event mapping transformations." },
    { "name": "dbo.EventSets",         "type": "Table",                  "description": "Defines event-set groupings for models." },
    { "name": "dbo.SelectedEvents",    "type": "Table-Valued Function",  "description": "Filters and enriches EventsFact per model parameters." },
    { "name": "dbo.UserAccessBitmap",  "type": "Scalar Function",        "description": "Retrieves current user access bitmap for filtering." }
  ]
}

Sample utilization:

	DECLARE @ModelID BIGINT=5
	SELECT * FROM [dbo].[ModelEvents] WHERE ModelID=@ModelID
    EXEC dbo.sp_ModelDrillThrough @ModelID,'arrive','greeted';

	DECLARE @SessionID UNIQUEIDENTIFIER=NEWID()
	EXEC dbo.sp_ModelDrillThrough @ModelID=1, @SessionID=@SessionID


Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/



CREATE PROCEDURE [dbo].[sp_ModelDrillThrough]
(
@ModelID INT,
@EventA NVARCHAR(50)=NULL,
@EventB NVARCHAR(50)=NULL,
@SessionID UNIQUEIDENTIFIER=NULL
)
AS
BEGIN

	DECLARE @CreatedBy_AccessBitmap BIGINT;

	SELECT
		@CreatedBy_AccessBitmap = m.CreatedBy_AccessBitmap
	FROM dbo.Models m
	WHERE m.ModelID = @ModelID;

	--Fill in attributes of the selected model.
	DECLARE @EventSet NVARCHAR(MAX)
	DECLARE @enumerate_multiple_events BIT
	DECLARE @StartDateTime DATETIME
	DECLARE @EndDateTime DATETIME
	DECLARE @Transforms NVARCHAR(MAX)
	DECLARE @Metric NVARCHAR(20)
	DECLARE @CaseFilterProperties NVARCHAR(MAX)
	DECLARE @EventFilterProperties NVARCHAR(MAX)

	DECLARE @DisplayReport BIT=0
	IF @SessionID IS NULL
	BEGIN
		SET @DisplayReport=1
		SET @SessionID=NEWID()
	END

	SELECT
		@EventSet=e.EventSet,
		@enumerate_multiple_events=m.enumerate_multiple_events,
		@StartDateTime=m.StartDateTime,
		@EndDateTime=m.EndDateTime,
		@Transforms=t.transforms,
		@Metric=mt.Metric,
		@EventFilterProperties=m.EventFilterProperties,
		@CaseFilterProperties=m.CaseFilterProperties
	FROM
		[dbo].[Models] m (NOLOCK)
		JOIN [dbo].[Metrics] mt (NOLOCK) ON m.Metricid=mt.MetricID
		LEFT JOIN [dbo].[Transforms] t (NOLOCK) ON m.transformskey=t.transformskey
		LEFT JOIN [dbo].[EventSets] e (NOLOCK) ON e.EventSetKey=m.EventSetKey
	WHERE
		m.modelid=@ModelID
		AND (dbo.UserAccessBitmap() & m.AccessBitmap)=m.AccessBitmap

	DECLARE @ByCase BIT=1

	EXEC dbo.sp_SelectedEvents
			@EventSet = @EventSet,
			@enumerate_multiple_events = @enumerate_multiple_events,
			@StartDateTime = @StartDateTime,
			@EndDateTime = @EndDateTime,
			@transforms = @transforms,
			@ByCase = @ByCase,
			@metric = @metric,
			@CaseFilterProperties = @CaseFilterProperties,
			@EventFilterProperties = @EventFilterProperties,
			@SessionID=@SessionID,
			@CreatedBy_AccessBitmap=@CreatedBy_AccessBitmap

	--select @SessionID,* from work.SelectedEvents  where SessionID=@SessionID

	INSERT INTO WORK.ModelDrillThrough
	(
		SessionID,
		CaseID,
		EventA,
		EventB,
		EventDate_A,
		EventDate_B,
		Minutes,
		[Rank],
		EventOccurence,
		EventA_ID,
		EventB_ID,
		EventA_SourceColumnID,
		EventB_SourceColumnID
	)
	SELECT
		@SessionID AS SessionID,
		e1.CaseID,
		e.[Event] AS EventA,
		e1.[Event] AS EventB,
		e.EventDate AS EventDate_A,
		e1.EventDate AS EventDate_B,
		DATEDIFF(ss, e.EventDate, e1.EventDate) / 60.0 AS [Minutes],
		e1.[Rank],
		e1.[EventOccurence],
		e.EventID AS EventA_ID,
		e1.EventID AS EventB_ID,
		c.Event_SourceColumnID AS EventA_SourceColumnID,
		c1.Event_SourceColumnID AS EventB_SourceColumnID
	FROM
		WORK.SelectedEvents e
		JOIN WORK.SelectedEvents e1
			ON e1.[Rank] = e.[Rank] + 1
		   AND e.CaseID = e1.CaseID
		LEFT JOIN Cases c (NOLOCK)
			ON c.CaseID = e.CaseID
		LEFT JOIN [dbo].[SourceColumns] sc (NOLOCK)
			ON sc.SourceColumnID = c.Event_SourceColumnID
		LEFT JOIN Cases c1 (NOLOCK)
			ON c1.CaseID = e1.CaseID
		LEFT JOIN [dbo].[SourceColumns] sc1 (NOLOCK)
			ON sc1.SourceColumnID = c1.Event_SourceColumnID
	WHERE
		e.SessionID = @SessionID AND e1.SessionID=@SessionID
		AND (@EventA IS NULL OR e.[Event] = @EventA)
		AND (@EventB IS NULL OR e1.[Event] = @EventB);

	DELETE FROM WORK.SelectedEvents WHERE SessionID=@SessionID

	IF @DisplayReport=1
	BEGIN
		SELECT * FROM WORK.ModelDrillThrough WHERE SessionID=@SessionID
		DELETE FROM WORK.ModelDrillThrough WHERE SessionID=@SessionID
	END

END
GO
/****** Object:  StoredProcedure [dbo].[sp_SelectedEvents]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "sp_SelectedEvents",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": [
    "Retrieves all events for a specified event set and optional filters, returning CaseID, Event name, timestamp, sequence rank, occurrence count, EventID, and metric values.",
    "Uses inline table variable (@result) to collect and return results; supports both stored-proc and TVF usage patterns."
  ],
  "Utilization": "Use when you need the SelectedEvents logic materialized procedurally, especially for work-table pipelines, scale-out rewrites, or multi-step processes that reuse the same filtered event set.",
  "Input Parameters": [
    {"name":"@EventSet","type":"NVARCHAR(MAX)","default":null,"description":"Identifier or CSV defining which events to include (required)."},
    {"name":"@enumerate_multiple_events","type":"INT","default":null,"description":"0 to collapse duplicates; >0 to enumerate each occurrence up to that count."},
    {"name":"@StartDateTime","type":"DATETIME","default":null,"description":"Lower bound of event date range (defaults to 1900-01-01)."},
    {"name":"@EndDateTime","type":"DATETIME","default":null,"description":"Upper bound of event date range (defaults to 2050-12-31)."},
    {"name":"@transforms","type":"NVARCHAR(MAX)","default":null,"description":"JSON mapping for event name transformations."},
    {"name":"@ByCase","type":"BIT","default":"1","description":"1 to partition by CaseID; 0 to treat all events as a single case."},
    {"name":"@metric","type":"NVARCHAR(20)","default":"Time Between","description":"Metric name for event-level properties (defaults to “Time Between”)."},
    {"name":"@CaseFilterProperties","type":"NVARCHAR(MAX)","default":null,"description":"JSON of case-level filter key/value pairs."},
    {"name":"@EventFilterProperties","type":"NVARCHAR(MAX)","default":null,"description":"JSON of event-level filter key/value pairs."}
  ],
  "Output Notes": [
    {"name":"CaseID","type":"INT","description":"Case identifier (or -1 when @ByCase=0)."},
    {"name":"Event","type":"NVARCHAR(20)","description":"Event name (after optional transform)."},
    {"name":"EventDate","type":"DATETIME2","description":"Event timestamp (with millisecond precision)."},
    {"name":"Rank","type":"INT","description":"Sequence order within the case."},
    {"name":"EventOccurence","type":"INT","description":"Occurrence count of this event in the case."},
    {"name":"EventID","type":"INT","description":"Surrogate key of the event instance."},
    {"name":"MetricActualValue","type":"FLOAT","description":"Actual metric value at the event (if metric ≠ 'Time Between')."},
    {"name":"MetricExpectedValue","type":"FLOAT","description":"Expected metric value at the event (if metric ≠ 'Time Between')."}
  ],
  "Referenced objects": [
    {"name":"dbo.ParseEventSet","type":"Table-Valued Function","description":"Parses @EventSet into individual event names."},
    {"name":"dbo.ParseTransforms","type":"Table-Valued Function","description":"Parses @transforms JSON into row mappings."},
    {"name":"dbo.EventsFact","type":"Table","description":"Fact table of all events with CaseID, Event, EventDate, EventID."},
    {"name":"dbo.Cases","type":"Table","description":"Case table containing CaseID and AccessBitmap."},
    {"name":"dbo.EventPropertiesParsed","type":"Table","description":"Parsed event-level properties and metrics."},
    {"name":"dbo.CasePropertiesParsed","type":"Table","description":"Parsed case-level properties for filtering."},
    {"name":"dbo.UserAccessBitmap","type":"Scalar Function","description":"Returns current user's access bitmap for row-level security."},
    {"name":"OPENJSON","type":"Built-in Function","description":"Used for JSON parsing."}
  ]
}


Sample utilization:

For short results, the TVF is often faster. For results across very many facts, the sproc is usually faster.

EXEC dbo.sp_SelectedEvents 'restaurantguest',0, NULL,NULL,NULL,1,NULL,NULL,NULL
SELECT * 
FROM dbo.SelectedEvents('restaurantguest',0, NULL,NULL,NULL,1,NULL,NULL,NULL) 
ORDER BY CaseID,[Rank]

	CHECKPOINT;
	GO
	DBCC FREEPROCCACHE;
	GO
	DBCC DROPCLEANBUFFERS;
	GO

{"Fuel":1,"Weight":1}
{"Fuel":[1,2,3],"Weight":1}
{"Fuel":{"start":1,"end":3},"Weight":1}

SELECT * FROM ParseFilterProperties('{"Fuel":{"start":1,"end":3},"Weight":1}')

EXEC dbo.sp_SelectedEvents 'pickuproute',0, NULL,NULL,NULL,1,NULL,NULL,'{"Fuel":{"start":1,"end":3000},"Weight":{"start":144,"end":147}}'
SELECT * 
FROM dbo.SelectedEvents('pickuproute',0, NULL,NULL,NULL,1,NULL,NULL,'{"Fuel":1,"Weight":1}') 
ORDER BY CaseID,[Rank]

SELECT * 
FROM dbo.SelectedEvents('cardiology',0, NULL,NULL,NULL,1,NULL,NULL,NULL) 
ORDER BY CaseID,[Rank]

--These two EXEC has @EventSet IS NULL, which means all events.
--In this case, I want all events related to CustomerID=2 and CustomerID=4, at LocationID=1.
--The purpose is to see where/when CustomerID 2 and 4 intersect.
EXEC dbo.sp_SelectedEvents NULL,0, NULL,NULL,NULL,1,NULL,'{"LocationID":1,"CustomerID":2}'
EXEC dbo.sp_SelectedEvents NULL,0, NULL,NULL,NULL,1,NULL,'{"LocationID":1,"CustomerID":4}'




Context:
    • Provided as-is for teaching and demonstration of the Time Molecules concepts.
    • **Not** production-hardened: error handling, security, concurrency, indexing, query tuning, and partitioning are simplified or omitted.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

Notes:

    • See https://github.com/MapRock/TimeMolecules/blob/main/docs/sp_SelectedEvents_MPP_refactor_20260321.md for explanation of the MPP-style of WORK tables.


*/
CREATE PROCEDURE [dbo].[sp_SelectedEvents]
(
	@EventSet NVARCHAR(MAX), --An Event Set MUST be specified. This is the primary key.
	@enumerate_multiple_events INT=0,
	@StartDateTime DATETIME=NULL,
	@EndDateTime DATETIME=NULL,
	@transforms NVARCHAR(MAX)=NULL,
	@ByCase BIT=1, -- 1 should be the Default. If 0, consider everything to be one case.
	@metric NVARCHAR(20)=NULL, -- Metric are Event-Level properties (EventPropertiesParsed).
	@CaseFilterProperties NVARCHAR(MAX)=NULL,
	@EventFilterProperties NVARCHAR(MAX)=NULL,
	@SessionID UniqueIdentifier=NULL OUTPUT, --If NULL, we will DISPLAY results at the end.
	@RowsReturned BIGINT=NULL OUTPUT,
	@CreatedBy_AccessBitmap BIGINT = NULL
) AS
BEGIN

	SET @CreatedBy_AccessBitmap =
		COALESCE(@CreatedBy_AccessBitmap, CAST(dbo.UserAccessBitmap() AS BIGINT));

	DECLARE @DisplayResult BIT=0
	IF @SessionID IS NULL
	BEGIN
		SET @SessionID=neWID() --Get SessionID is one wasn't supplied.
		SET @DisplayResult=1
	END

	DECLARE @DefaultMetric NVARCHAR(20)

    SELECT
		@StartDateTime=StartDateTime,
		@EndDateTime=EndDateTime,
		@metric=[metric],
		@DefaultMetric=DefaultMetric
     FROM dbo.SetDefaultModelParameters(
             @StartDateTime,    -- @StartDateTime
             @EndDateTime,    -- @EndDateTime
             NULL,    -- @Order
             NULL,    -- @enumerate_multiple_events
             @metric     -- @metric
           );

	SET @ByCase=COALESCE(@ByCase,1) --1 is default.

	DECLARE @IsSequence BIT=0

	DROP TABLE IF EXISTS #ex
	CREATE TABLE #ex ([event] NVARCHAR(50) NOT NULL PRIMARY KEY)
	IF @EventSet IS NOT NULL -- @EventSet IS NULL means ALL events.
	BEGIN
		INSERT INTO #ex([event])
			SELECT DISTINCT [event] FROM dbo.ParseEventSet(@EventSet, @IsSequence)  --@EventSet could reference a code (IncludedEvents.Code). IsSequence=0, it's a set.
	END
	ELSE
	BEGIN
		--Not ideal way to do "ALL events". Just for now, don't want to create bugs.
		INSERT INTO #ex([event])
			SELECT DISTINCT [Event] FROM [dbo].[DimEvents]  
	END

	CREATE TABLE #trans (fromKey NVARCHAR(50) NOT NULL PRIMARY KEY,tokey NVARCHAR(50))
	IF @transforms IS NOT NULL
	BEGIN
		INSERT INTO #trans
			SELECT [fromkey],[tokey] FROM dbo.ParseTransforms(@transforms)
	END

	DROP TABLE IF EXISTS #cases_filtered
	CREATE TABLE #cases_filtered (CaseID BIGINT NOT NULL PRIMARY KEY,PropertyCount INT)

	DROP TABLE IF EXISTS #events_filtered
	CREATE TABLE #events_filtered (EventID BIGINT NOT NULL PRIMARY KEY,PropertyCount INT)



	DECLARE @Properties TABLE
	(
		property NVARCHAR(50),
		operator_type NVARCHAR(20),   -- eq | in | between
		property_numeric FLOAT NULL,
		property_alpha NVARCHAR(1000) NULL,
		property_json NVARCHAR(MAX) NULL,
		range_start_numeric FLOAT NULL,
		range_end_numeric FLOAT NULL,
		[rank] INT,
		UNIQUE (property,[rank])
	);

	DECLARE @MaxProps INT
	IF @CaseFilterProperties IS NOT NULL
	BEGIN
		INSERT INTO @Properties
			SELECT * FROM ParseFilterProperties(@CaseFilterProperties)
		SET @MaxProps=(SELECT COUNT(*) FROM @Properties)

		INSERT INTO #cases_filtered (CaseID, PropertyCount)
			SELECT
				cpp.CaseID,
				COUNT(*) AS PropertyCount
			FROM
				[dbo].[CasePropertiesParsed] cpp (NOLOCK)
				JOIN @Properties cp ON cpp.PropertyName=cp.property
			WHERE
				--StartDateTime and EndDateTime is to filter events, not cases.
				--cpp.StartDateTime BETWEEN @StartDateTime AND @EndDateTime AND
				--cpp.EndDateTime BETWEEN @StartDateTime AND @EndDateTime AND
				(
					(cp.operator_type = 'eq' AND cp.property_numeric IS NOT NULL AND cpp.PropertyValueNumeric = cp.property_numeric)
					OR
					(cp.operator_type = 'eq' AND cp.property_alpha IS NOT NULL AND cpp.PropertyValueAlpha = cp.property_alpha)
					OR
					(cp.operator_type = 'between' AND cpp.PropertyValueNumeric BETWEEN cp.range_start_numeric AND cp.range_end_numeric)
					OR
					(cp.operator_type = 'in' AND EXISTS
						(
							SELECT 1
							FROM OPENJSON(@CaseFilterProperties, '$."' + cp.property + '"') j
							WHERE
								(ISNUMERIC(j.[value]) = 1 AND cpp.PropertyValueNumeric = CAST(j.[value] AS FLOAT))
								OR
								(ISNUMERIC(j.[value]) = 0 AND cpp.PropertyValueAlpha = j.[value])
						)
					)
				)
			GROUP BY
				cpp.CaseID
			HAVING
				COUNT(*)=@MaxProps
	END

	IF @EventFilterProperties IS NOT NULL
	BEGIN
		DELETE FROM @Properties
		INSERT INTO @Properties
			SELECT * FROM ParseFilterProperties(@EventFilterProperties)

		DECLARE @EventMaxProps INT=(SELECT COUNT(*) FROM @Properties)

		INSERT INTO #events_filtered (EventID,PropertyCount)
			SELECT
				epp.EventID,
				COUNT(*) AS PropertyCount
			FROM
				dbo.EventPropertiesParsed epp WITH (NOLOCK)
				JOIN @Properties ep ON epp.PropertyName = ep.property
				JOIN #ex ex ON ex.[event] = epp.[Event]
			WHERE
				epp.EventDate BETWEEN @StartDateTime AND @EndDateTime
				AND epp.PropertySource = 0
				AND	(
					(ep.operator_type = 'eq' AND ep.property_numeric IS NOT NULL AND epp.PropertyValueNumeric = ep.property_numeric)
					OR
					(ep.operator_type = 'eq' AND ep.property_alpha IS NOT NULL AND epp.PropertyValueAlpha = ep.property_alpha)
					OR
					(ep.operator_type = 'between' AND epp.PropertyValueNumeric BETWEEN ep.range_start_numeric AND ep.range_end_numeric)
					OR
					(ep.operator_type = 'in' AND EXISTS
						(
							SELECT 1
							FROM OPENJSON(ep.property_json) j
							WHERE
								(TRY_CAST(j.[value] AS FLOAT) IS NOT NULL AND epp.PropertyValueNumeric = TRY_CAST(j.[value] AS FLOAT))
								OR
								(TRY_CAST(j.[value] AS FLOAT) IS NULL AND epp.PropertyValueAlpha = j.[value])
						)
					)
				)
			GROUP BY
				epp.EventID
			HAVING
				COUNT(*) = @EventMaxProps;

	END

	DECLARE @AccessBitmap BIGINT=dbo.UserAccessBitmap()

	INSERT INTO WORK.SelectedEvents
		SELECT
			@SessionID,
			e.CaseID, 
			e.[Event], 
			e.EventDate, 
			RANK() OVER (PARTITION BY e.CaseID ORDER BY e.EventDate) AS [Rank], 
			RANK() OVER (PARTITION BY e.CaseID, e.[Event] ORDER BY e.EventDate) AS [EventOccurence],--Event that occurs multiple times in a case.
			e.MetricInputValue AS MetricInputValue,
			e.MetricOutputValue AS MetricOutputValue,
			e.EventID
		FROM  
			(
				SELECT
					CASE WHEN @ByCase=1 THEN e.CaseID ELSE -1 END AS CaseID, --If @ByCase=0, we're considering everything a single case. 
					CASE WHEN tr.fromKey IS NULL THEN e.[Event] ELSE tr.tokey END AS [Event], 
					e.EventDate,
					e.EventID,
					[pi].PropertyValueNumeric AS MetricInputValue,
					[po].PropertyValueNumeric AS MetricOutputValue
				FROM
					[dbo].[EventsFact] e (NOLOCK)
					JOIN [dbo].[Cases] c (NOLOCK) ON c.CaseID=e.CaseID
					JOIN #ex x ON x.[event]=e.[Event]
					LEFT JOIN #trans tr ON tr.fromKey=e.[Event]
					LEFT JOIN [dbo].[EventPropertiesParsed] [pi] (NOLOCK) ON @metric<>@DefaultMetric AND [pi].EventID=e.EventID AND [pi].PropertySource=0 AND [pi].PropertyName=@metric
					LEFT JOIN [dbo].[EventPropertiesParsed] [po] (NOLOCK) ON @metric<>@DefaultMetric AND [po].EventID=e.EventID AND [po].PropertySource=1 AND [po].PropertyName=@metric
					LEFT JOIN #events_filtered ef ON ef.EventID=e.EventID
					LEFT JOIN #cases_filtered cf ON cf.CaseID=e.CaseID
				WHERE 
					e.EventDate BETWEEN @StartDateTime AND @EndDateTime AND
					(@EventFilterProperties IS NULL OR ef.EventID IS NOT NULL) AND
					(@CaseFilterProperties IS NULL OR cf.CaseID IS NOT NULL) AND
					(@AccessBitmap & c.AccessBitmap)=c.AccessBitmap
			) e

	SET @RowsReturned=@@ROWCOUNT

	
	IF @enumerate_multiple_events>0
	BEGIN
		UPDATE WORK.SelectedEvents
		SET
			[Event]=r.[Event]+CAST(CASE WHEN r.EventOccurence<=@enumerate_multiple_events THEN r.EventOccurence ELSE @enumerate_multiple_events END AS NVARCHAR(5))
		FROM
			WoRK.SelectedEvents r
		WHERE
			r.EventOccurence>1 -- Set event to event1, event2, event3, etc if the event occurs more than once in a case.
	END

	IF @DisplayResult=1
	BEGIN
		SELECT
			CaseID,[Event],EventDate,[Rank],EventOccurence,Eventid,MetricInputValue,MetricOutputValue
		FROM WORK.SelectedEvents
		WHERE SessionID=@SessionID
	END

	DROP TABLE IF EXISTS #cases_filtered
	DROP TABLE IF EXISTS #events_filtered
	
END
GO
/****** Object:  StoredProcedure [dbo].[sp_SelectEventsbyProperties]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "dbo.sp_SelectEventsbyProperties",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-03-25",
  "Description": "Returns events from dbo.EventPropertiesParsed that belong to the specified EventSet, fall within the effective datetime window, and match all property names supplied in the JSON property filter. The procedure expands the EventSet into distinct event names, parses the property filter JSON, and returns one row per matching event occurrence.",
  "Utilization": "Use when you want to find actual event occurrences that match a named event set and a JSON property filter, especially for targeted drill-through, validation, or event-level troubleshooting.",
  "Input Parameters": [
    {
      "name": "@EventSet",
      "type": "NVARCHAR(MAX)",
      "default": null,
      "description": "Required event-set expression or code. Parsed by dbo.ParseEventSet into the list of eligible event names."
    },
    {
      "name": "@EventFilterProperties",
      "type": "NVARCHAR(1000)",
      "default": null,
      "description": "JSON object containing property filters. Property names are required for matching; values are parsed into numeric or alpha form but are not currently used in the filtering predicate."
    },
    {
      "name": "@StartDateTime",
      "type": "DATETIME",
      "default": "NULL",
      "description": "Optional lower datetime bound. If NULL, dbo.SetDefaultModelParameters supplies the effective default start datetime."
    },
    {
      "name": "@EndDateTime",
      "type": "DATETIME",
      "default": "NULL",
      "description": "Optional upper datetime bound. If NULL, dbo.SetDefaultModelParameters supplies the effective default end datetime."
    }
  ],
  "Output Notes": [
    {
      "name": "EventID",
      "type": "BIGINT",
      "description": "Identifier of the matching event occurrence."
    },
    {
      "name": "Event",
      "type": "NVARCHAR(20)",
      "description": "Event name for the matching occurrence."
    },
    {
      "name": "EventDate",
      "type": "DATETIME",
      "description": "Datetime of the matching event occurrence."
    },
    {
      "name": "CaseID",
      "type": "INT",
      "description": "Identifier of the case containing the matching event."
    },
    {
      "name": "PropertyCount",
      "type": "INT",
      "description": "Count of matched properties for the event occurrence. The HAVING clause requires this count to equal the number of requested filter properties."
    }
  ],
  "Referenced objects": [
    {
      "name": "dbo.SetDefaultModelParameters",
      "type": "Table-Valued Function",
      "description": "Supplies effective default model parameters, including datetime bounds when input values are NULL."
    },
    {
      "name": "dbo.ParseEventSet",
      "type": "Table-Valued Function",
      "description": "Expands an EventSet expression or code into distinct event names."
    },
    {
      "name": "dbo.EventPropertiesParsed",
      "type": "Table",
      "description": "Stores parsed event properties used to identify matching event occurrences."
    }
  ]
}
Sample utilization:

*/
CREATE   PROCEDURE [dbo].[sp_SelectEventsbyProperties]
	@EventSet NVARCHAR(MAX), --An Event Set MUST be specified. This is the primary key.
    @EventFilterProperties NVARCHAR(1000),
    @StartDateTime DATETIME = NULL,
    @EndDateTime DATETIME = NULL
AS
BEGIN
    SELECT
		@StartDateTime=StartDateTime,
		@EndDateTime=EndDateTime
     FROM dbo.SetDefaultModelParameters(
             @StartDateTime,    -- @StartDateTime
             @EndDateTime,    -- @EndDateTime
             NULL,    -- @Order
             NULL,    -- @enumerate_multiple_events
             NULL     -- @metric
           );

	DECLARE @ex TABLE ([event] NVARCHAR(50))
	IF @EventSet IS NOT NULL -- @EventSet=0 means essentially means all events.
	BEGIN
		INSERT INTO @ex([event])
			SELECT DISTINCT [event] FROM dbo.ParseEventSet(@EventSet, 1)  --@EventSet could reference a code (IncludedEvents.Code). IsSequence=0, it's a set.
	END
	ELSE
	BEGIN
		RETURN --Error
	END
	
	DECLARE @EventProperties TABLE (property NVARCHAR(50), property_numeric FLOAT,property_alpha NVARCHAR(1000),[rank] INT, UNIQUE (property,[rank]))
	IF @EventFilterProperties IS NOT NULL
	BEGIN
		INSERT INTO @EventProperties
		SELECT 
			[key],
			CASE WHEN ISNUMERIC([value])=1 THEN CAST([value] AS FLOAT) ELSE NULL END,
			CASE WHEN ISNUMERIC([value])=0 THEN [value] ELSE NULL END,
			ROW_NUMBER() OVER(ORDER BY [key]) [rank]
		FROM 
			OPENJSON(@EventFilterProperties)
	END
	DECLARE @EventMaxProps INT=(SELECT COUNT(*) FROM @EventProperties)

	SELECT
		epp.EventID,
		epp.[Event],
		epp.[EventDate],
		epp.CaseID,
		COUNT(*) AS PropertyCount
	FROM
		[dbo].[EventPropertiesParsed] epp (NOLOCK)
		JOIN @EventProperties ep ON epp.PropertyName=ep.property
		JOIN @ex ex ON ex.[event]=epp.[Event]
	WHERE
		epp.EventDate BETWEEN @StartDateTime AND @EndDateTime AND
		epp.PropertySource=0
	GROUP BY
		epp.EventID,
		epp.[Event],
		epp.[EventDate],
		epp.CaseID
	HAVING
		COUNT(*)=@EventMaxProps
END
GO
/****** Object:  StoredProcedure [dbo].[sp_Sequences]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Stored procedure": "sp_Sequences",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-16",
  "Description": "Computes all successive event‐sequence statistics (per‐sequence and per‐hop) for a given event set over a time window, optionally using cached results for performance.",
  "Utilization": "Use when you want sequence discovery or sequence extraction materialized procedurally, especially when the output needs to feed work tables or later pipeline steps.",
  "Input Parameters": [
    { "name": "@EventSet",                 "type": "NVARCHAR(MAX)", "default": "NULL", "description": "Comma-separated events or code referencing dbo.ParseEventSet." },
    { "name": "@enumerate_multiple_events","type": "INT",           "default": "NULL", "description": "When >0, appends sequence numbers to duplicate events in a case." },
    { "name": "@StartDateTime",            "type": "DATETIME",      "default": "NULL", "description": "Inclusive lower bound; defaults to '1900-01-01' if NULL." },
    { "name": "@EndDateTime",              "type": "DATETIME",      "default": "NULL", "description": "Inclusive upper bound; defaults to '2050-12-31' if NULL." },
    { "name": "@transforms",               "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON or code mapping of event rename transformations." },
    { "name": "@ByCase",                   "type": "BIT",           "default": "1",    "description": "1 to partition by CaseID; 0 to treat all events as one sequence." },
    { "name": "@Metric",                   "type": "NVARCHAR(20)",  "default": "NULL", "description": "Metric name in dbo.Metrics; defaults to 'Time Between' if NULL." },
    { "name": "@CaseFilterProperties",     "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON filters for CasePropertiesParsed." },
    { "name": "@EventFilterProperties",    "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON filters for EventPropertiesParsed." },
    { "name": "@ForceRefresh",             "type": "BIT",           "default": "0",    "description": "0 to use cache when available; 1 to recalculate always." }
  ],
  "Output Notes": [
    { "name": "Seq",        "type": "NVARCHAR(2000)", "description": "Comma-delimited event sequence from case start." },
    { "name": "lastEvent",  "type": "NVARCHAR(20)",   "description": "Final event in the sequence." },
    { "name": "nextEvent",  "type": "NVARCHAR(20)",   "description": "Event immediately following the sequence." },
    { "name": "SeqStDev",   "type": "FLOAT",          "description": "Std. dev. of total time from sequence start to nextEvent." },
    { "name": "SeqMax",     "type": "FLOAT",          "description": "Max total time for that sequence." },
    { "name": "SeqAvg",     "type": "FLOAT",          "description": "Avg total time for that sequence." },
    { "name": "SeqMin",     "type": "FLOAT",          "description": "Min total time for that sequence." },
    { "name": "SeqSum",     "type": "FLOAT",          "description": "Sum of total times for that sequence." },
    { "name": "HopStDev",   "type": "FLOAT",          "description": "Std. dev. of individual hop times (lastEvent→nextEvent)." },
    { "name": "HopMax",     "type": "FLOAT",          "description": "Max individual hop time." },
    { "name": "HopAvg",     "type": "FLOAT",          "description": "Avg individual hop time." },
    { "name": "HopMin",     "type": "FLOAT",          "description": "Min individual hop time." },
    { "name": "TotalRows",  "type": "INT",            "description": "Total occurrences of that sequence across all cases." },
    { "name": "Rows",       "type": "INT",            "description": "Occurrences of that sequence immediately followed by nextEvent." },
    { "name": "Prob",       "type": "FLOAT",          "description": "Conditional probability = Rows / TotalRows." },
    { "name": "ExitRows",   "type": "INT",            "description": "Count where nextEvent does not exist (sequence end)." },
    { "name": "Cases",      "type": "INT",            "description": "Distinct cases containing the sequence." },
    { "name": "ModelID",    "type": "INT",            "description": "Identifier of the Markov model used or created." },
    { "name": "FromCache",  "type": "BIT",            "description": "1 if returned from cache table; 0 if computed on the fly." },
    { "name": "length",     "type": "INT",            "description": "Number of events in the sequence." }
  ],
  "Referenced objects": [
    { "name": "dbo.SelectedEvents",   "type": "Table-Valued Function", "description": "Filters and enriches EventsFact per model parameters." },
    { "name": "dbo.ModelID",          "type": "Scalar Function",       "description": "Retrieves or inserts a Markov model entry for given parameters." },
    { "name": "dbo.SetDefaultModelParameters","type":"Table-Valued Function","description":"Applies defaults to date range, metric, order, and enumeration flags." },
    { "name": "dbo.ModelSequences",   "type": "Table",                  "description": "Cached sequence statistics for prior calls." }
  ]
}
Sample utilization:
      EXEC dbo.sp_Sequences 'arrive,greeted,seated',  
         1, '1900-01-01','2050-12-31',
         NULL,1,NULL,NULL,NULL,0

		SELECT
			*
		FROM
			SelectedEvents('arrive,greeted,seated',1,NULL,NULL,NULL,NULL,NULL,NULL,NULL) e
	



    SELECT * 
      FROM dbo.Sequences(
        'arrive,greeted,seated',  
         1, '1900-01-01','2050-12-31',
         NULL,1,NULL,NULL,NULL,0
      );

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE PROCEDURE [dbo].[sp_Sequences]
(
    @EventSet NVARCHAR(MAX),
    @enumerate_multiple_events INT,
    @StartDateTime DATETIME,
    @EndDateTime DATETIME,
    @transforms NVARCHAR(MAX),
    @ByCase BIT = 1,
    @Metric NVARCHAR(20),
    @CaseFilterProperties NVARCHAR(MAX),
    @EventFilterProperties NVARCHAR(MAX),
    @ForceRefresh BIT = 0,
	@SessionID UNIQUEIDENTIFIER=NULL,
    @CreatedBy_AccessBitmap BIGINT = NULL,
    @AccessBitmap BIGINT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @CreatedBy_AccessBitmap =
        COALESCE(@CreatedBy_AccessBitmap, CAST(dbo.UserAccessBitmap() AS BIGINT));

    SET @AccessBitmap =
        COALESCE(@AccessBitmap, @CreatedBy_AccessBitmap);

    DECLARE @ModelType NVARCHAR(50) = 'MarkovChain';
	DECLARE @DisplayResult BIT=0
	IF @SessionID IS NULL
	BEGIN
		SET @SessionID=NEWID()
		SET @DisplayResult=1	--Since this sproc was called independently, display the result at the end.
	END

    SELECT
        @StartDateTime = StartDateTime,
        @EndDateTime   = EndDateTime,
        @Metric        = [metric]
    FROM dbo.SetDefaultModelParameters
    (
        @StartDateTime,
        @EndDateTime,
        NULL,
        NULL,
        @Metric
    );

    SET @ByCase = COALESCE(@ByCase, 1);
    SET @ForceRefresh = COALESCE(@ForceRefresh, 0);


	DECLARE @ModelID INT = dbo.ModelID
	(
		@EventSet,
		@enumerate_multiple_events,
		@StartDateTime,
		@EndDateTime,
		@transforms,
		@ByCase,
		@metric,
		@CaseFilterProperties,
		@EventFilterProperties,
		@ModelType,
		@CreatedBy_AccessBitmap
	);

    IF @ForceRefresh = 0 AND @ModelID IS NOT NULL
    BEGIN
        INSERT INTO WORK.[Sequences]
        (
            [Seq],
            [lastEvent],
            [nextEvent],
            [SeqStDev],
            [SeqMax],
            [SeqAvg],
            [SeqMin],
            [SeqSum],
            [HopStDev],
            [HopMax],
            [HopAvg],
            [HopMin],
            [TotalRows],
            [Rows],
            [Prob],
            [ExitRows],
            [Cases],
            [ModelID],
            [FromCache],
            [length],
			SessionID
        )
        SELECT
            [Seq],
            [lastEvent],
            [nextEvent],
            [SeqStDev],
            [SeqMax],
            [SeqAvg],
            [SeqMin],
            [SeqSum],
            [HopStDev],
            [HopMax],
            [HopAvg],
            [HopMin],
            [TotalRows],
            [Rows],
            [Prob],
            [TermRows],   -- maps to ExitRows
            [Cases],
            [ModelID],
            1,            -- FromCache
            [length],
			@SessionID
        FROM [dbo].[ModelSequences]
        WHERE [ModelID] = @ModelID;

        RETURN;
    END;

    DECLARE @raw TABLE
    (
        CaseID int, 
        [Event] NVARCHAR(50), 
        EventDate datetime, 
        [Rank] INT NULL, 
        EventOccurence bigint,
		UNIQUE([CaseID],[Rank])
    );

	EXEC dbo.sp_SelectedEvents
			@EventSet = @EventSet,
			@enumerate_multiple_events = @enumerate_multiple_events,
			@StartDateTime = @StartDateTime,
			@EndDateTime = @EndDateTime,
			@transforms = @transforms,
			@ByCase = @ByCase,
			@metric = @metric,
			@CaseFilterProperties = @CaseFilterProperties,
			@EventFilterProperties = @EventFilterProperties,
			@SessionID=@SessionID


    INSERT INTO @raw
    (
        CaseID,
        [Event],
        EventDate,
        [Rank],
        EventOccurence
    )
    SELECT
        e.CaseID,
        e.[Event],
        e.EventDate,
        e.[Rank],
        e.[EventOccurence]
    FROM WORK.SelectedEvents e
	WHERE
		e.SessionID=@SessionID

	DELETE FROM WORK.SelectedEvents WHERE SessionID=@SessionID

    DECLARE @c TABLE (c INT);

    INSERT INTO @c
    SELECT DISTINCT [Rank]
    FROM @raw;

    DECLARE @seq TABLE
    (
        CaseID INT,
        StartEventDate DATETIME,
        c INT,
        [Seq] NVARCHAR(2000),
        [length] INT
    );

    INSERT INTO @seq
    (
        CaseID,
        StartEventDate,
        c,
        [Seq],
        [length]
    )
    SELECT
        e.[CaseID],
        e1.EventDate AS StartEventDate,
        c.c,
        STRING_AGG(e.[Event], ',') WITHIN GROUP (ORDER BY e.[EventDate]) AS [Seq],
        COUNT(*) AS [length]
    FROM @raw e
    JOIN @raw e1
        ON e1.CaseID = e.CaseID
       AND e1.[Rank] = 1
    CROSS APPLY @c c
    WHERE e.[Rank] BETWEEN 1 AND c.c
    GROUP BY
        e.[CaseID],
        c.c,
        e1.EventDate;

    INSERT INTO WORK.[Sequences]
    (
        Seq,
        lastEvent,
        nextEvent,
        SeqStDev,
        SeqMax,
        SeqAvg,
        SeqMin,
        SeqSum,
        HopStDev,
        HopMax,
        HopAvg,
        HopMin,
        TotalRows,
        [Rows],
        Prob,
        ExitRows,
        Cases,
        ModelID,
        FromCache,
        [length],
		SessionID
    )
    SELECT
        s.Seq AS Seq,
        l.[Event] AS lastEvent,
        e.[Event] AS nextEvent,
        ROUND(CAST(STDEV(DATEDIFF(ss, s.StartEventDate, e.EventDate)) AS FLOAT) / 60.0, 4) AS SeqStDev,
        ROUND(MAX(DATEDIFF(ss, s.StartEventDate, e.EventDate)) / 60.0, 4) AS SeqMax,
        ROUND(CAST(AVG(DATEDIFF(ss, s.StartEventDate, e.EventDate)) AS FLOAT) / 60.0, 4) AS SeqAvg,
        ROUND(MIN(DATEDIFF(ss, s.StartEventDate, e.EventDate)) / 60.0, 4) AS SeqMin,
        SUM(DATEDIFF(ss, s.StartEventDate, e.EventDate)) / 60.0 AS SeqSum,
        ROUND(CAST(STDEV(DATEDIFF(ss, l.EventDate, e.EventDate)) AS FLOAT) / 60.0, 4) AS HopStDev,
        MAX(DATEDIFF(ss, l.EventDate, e.EventDate)) / 60.0 AS HopMax,
        ROUND(CAST(AVG(DATEDIFF(ss, l.EventDate, e.EventDate)) AS FLOAT) / 60.0, 4) AS HopAvg,
        MIN(DATEDIFF(ss, l.EventDate, e.EventDate)) / 60.0 AS HopMin,
        s1.[Rows] AS TotalRows,
        COUNT(*) AS [Rows],
        ROUND(COUNT(*) / CAST(s1.[Rows] AS FLOAT), 4) AS Prob,
        SUM(CASE WHEN twoout.CaseID IS NULL THEN 1 ELSE 0 END) AS ExitRows,
        COUNT(DISTINCT s.CaseID) AS Cases,
        @ModelID,
        0,
        s.[length],
		@SessionID
    FROM @seq s
    JOIN
    (
        SELECT
            s1.[Seq],
            COUNT(*) AS [Rows]
        FROM @seq s1
        GROUP BY s1.[Seq]
    ) AS s1
        ON s1.[Seq] = s.[Seq]
    LEFT JOIN @raw twoout
        ON twoout.CaseID = s.CaseID
       AND twoout.[Rank] = s.c + 2
    LEFT JOIN @raw e
        ON e.CaseID = s.CaseID
       AND e.[Rank] = s.c + 1
    LEFT JOIN @raw l
        ON l.CaseID = s.CaseID
       AND l.[Rank] = s.c
    WHERE e.CaseID IS NOT NULL
    GROUP BY
        s.Seq,
        l.[Event],
        e.[Event],
        s1.[Rows],
        s.[length];

	IF @DisplayResult=1
	BEGIN
		SELECT * FROM WORK.[Sequences] WHERE SessionID=@SessionID
		DELETE FROM WORK.[Sequences] WHERE SessionID=@SessionID
	END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_SequenceSegments]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "SequenceSegments",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-19",
  "Description": "Identifies and aggregates all event sequences in raw event data that begin with a specified start event and end with a specified end event, computing basic statistics (min, max, avg, stdev, sum) on the elapsed time between those events and listing the cases in which they occur.",
  "Utilization": "Use when you want segment-level sequence output produced procedurally, especially for downstream comparison, caching, or staging into work tables.",
  "Input Parameters": [
    { "name": "@StartEvent",               "type": "NVARCHAR(20)",  "default": "NULL", "description": "Name of the event at which sequences must begin." },
    { "name": "@EndEvent",                 "type": "NVARCHAR(20)",  "default": "NULL", "description": "Name of the event at which sequences must end." },
    { "name": "@EventSet",                 "type": "NVARCHAR(MAX)", "default": "NULL", "description": "Comma‐delimited list or code referencing ParseEventSet to restrict which events are considered." },
    { "name": "@enumerate_multiple_events","type": "INT",           "default": "0",    "description": "If >0, disambiguates repeated events by appending an occurrence index." },
    { "name": "@StartDateTime",            "type": "DATETIME",     "default": "NULL", "description": "Lower bound of event dates; defaults to '1900-01-01' if NULL." },
    { "name": "@EndDateTime",              "type": "DATETIME",     "default": "NULL", "description": "Upper bound of event dates; defaults to '2050-12-31' if NULL." },
    { "name": "@transforms",               "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON or code for event renaming via ParseTransforms." },
    { "name": "@ByCase",                   "type": "BIT",          "default": "1",    "description": "1 to partition events by CaseID; 0 to treat all as a single sequence." },
    { "name": "@Metric",                   "type": "NVARCHAR(20)",  "default": "'Time Between'", "description": "Metric name for time calculation; defaults to 'Time Between'." },
    { "name": "@FilterProperties",         "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON to filter which cases are included via CasePropertiesParsed." }
  ],
  "Output Notes": [
    { "name": "Seq",           "type": "NVARCHAR(2000)", "description": "Comma-delimited sequence of events from start to end." },
    { "name": "SeqStDev",      "type": "FLOAT",          "description": "Standard deviation of elapsed minutes across all cases for this sequence." },
    { "name": "SeqMax",        "type": "FLOAT",          "description": "Maximum elapsed minutes for the sequence." },
    { "name": "SeqAvg",        "type": "FLOAT",          "description": "Average elapsed minutes for the sequence." },
    { "name": "SeqMin",        "type": "FLOAT",          "description": "Minimum elapsed minutes for the sequence." },
    { "name": "SeqSum",        "type": "FLOAT",          "description": "Sum of elapsed minutes across all cases for the sequence." },
    { "name": "Cases",         "type": "INT",            "description": "Count of distinct cases in which the sequence occurs." },
    { "name": "CaseID_List",   "type": "NVARCHAR(MAX)",   "description": "Comma-delimited list of CaseIDs where the sequence is found." }
  ],
  "Referenced objects": [
    { "name": "dbo.SelectedEvents", "type": "Table-Valued Function", "description": "Filters, orders, and enriches raw event data per model parameters." }
  ]
}


Sample utilization:

EXEC sp_SequenceSegments 'greeted','order','arrive,greeted,seated,intro,drinks,ccdeclined,charged,order,check,seated,served,bigtip,depart',1,'01/01/1900','12/31/2050',NULL,1,NULL

SELECT * FROM dbo.[SequenceSegments]('drinks','depart','arrive,greeted,seated,intro,drinks,ccdeclined,charged,order,check,seated,served,bigtip,depart',1,'01/01/1900','12/31/2050',NULL,1,NULL,NULL)
EXEC sp_SequenceSegments 'drinks','depart','arrive,greeted,seated,intro,drinks,ccdeclined,charged,order,check,seated,served,bigtip,depart',1,'01/01/1900','12/31/2050',NULL,1,NULL,NULL


Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query-plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

Notes:
    Differences between SequenceSegments and FindModelSequence:

    1. SequenceSegments processes from raw EventsFact; FindModelSequence processes precomputed ModelSequences.
    2. SequenceSegments finds any span from a start event to an end event; FindModelSequence matches a specific, exact sequence.


*/
CREATE PROCEDURE [dbo].[sp_SequenceSegments]
(
	@StartEvent NVARCHAR(50),
	@EndEvent NVARCHAR(50),
	@EventSet NVARCHAR(MAX),
	@enumerate_multiple_events INT,
	@StartDateTime DATETIME,
	@EndDateTime DATETIME,
	@transforms NVARCHAR(MAX),
	@ByCase BIT=1,
	@Metric NVARCHAR(20),
	@FilterProperties NVARCHAR(MAX)=NULL
)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @seq TABLE (
		[Seq] NVARCHAR(2000), 
		[SeqStDev] FLOAT, 
		[SeqMax] FLOAT, 
		[SeqAvg] FLOAT, 
		[SeqMin] FLOAT, --Max and min can help detect skew.
		[SeqSum] FLOAT, -- This lets us calculate an AVG across any way we reach the last event.
		Cases INT,
		CaseID_List NVARCHAR(MAX)
	)

	SET @metric=COALESCE(@metric,'Time Between')
	DECLARE @SessionID UNIQUEIDENTIFIER=NEWID()


    SELECT
		@StartDateTime=StartDateTime,
		@EndDateTime=EndDateTime,
		@metric=[metric],
		@enumerate_multiple_events=@enumerate_multiple_events
      FROM dbo.SetDefaultModelParameters(
             @StartDateTime,    -- @StartDateTime
             @EndDateTime,    -- @EndDateTime
             NULL,    -- @Order
             @enumerate_multiple_events,    -- @enumerate_multiple_events
             @metric     -- @metric
           );

	EXEC dbo.sp_SelectedEvents
			@EventSet = @EventSet,
			@enumerate_multiple_events = @enumerate_multiple_events,
			@StartDateTime = @StartDateTime,
			@EndDateTime = @EndDateTime,
			@transforms = @transforms,
			@ByCase = @ByCase,
			@metric = @metric,
			@CaseFilterProperties = @FilterProperties,
			@EventFilterProperties = NULL,
			@SessionID=@SessionID

	DECLARE @raw TABLE(CaseID int, [Event] NVARCHAR(50), EventDate datetime, [Rank] INT NULL, EventOccurence bigint)
	INSERT INTO @raw
		SELECT
			e.CaseID,
			e.[Event],
			e.EventDate,
			[Rank],
			EventOccurence
		FROM
			WORK.SelectedEvents e
		WHERE
			e.SessionID=@SessionID


	DECLARE @seq0 TABLE (CaseID INT,EventDate DATETIME, [Event] NVARCHAR(50),[Rank] INT,[EndRank] INT,EndDateTime DATETIME)
	DELETE FROM @seq0
	INSERT INTO @seq0
		SELECT
			e.[CaseID],
			e1.EventDate AS EventDate,
			e.[Event],
			e.[Rank],
			e1.[Rank] AS EndRank,
			e1.EventDate AS EndDateTime
		FROM
			@raw e
			JOIN @raw e1 On e1.CaseID=e.CaseID AND e1.[Rank]>e.[Rank]
		WHERE
			e.[Event]=@StartEvent
			AND e1.[Event]=@EndEvent

	DECLARE @seq1 TABLE (CaseID INT, StartEventDate DATETIME, EndEventDate DATETIME,[Seq] NVARCHAR(MAX))

	INSERT INTO @seq1
		SELECT
			e.[CaseID],
			MIN(e.EventDate) AS StartEventDate,
			MAX(e1.EventDate) AS EndEventDate,
			STRING_AGG(e.[Event],',') WITHIN GROUP (ORDER BY e.[EventDate]) AS [Seq]
		FROM
			@raw e
			JOIN @seq0 e1 On e1.CaseID=e.CaseID AND e1.[Event]=@StartEvent
		WHERE
			e.[Rank] BETWEEN e1.[Rank] AND e1.EndRank 
		GROUP BY
			e.[CaseID]
	   
	INSERT INTO @seq
		SELECT
			s.Seq AS Seq,
			ROUND(CAST(STDEV(DATEDIFF(ss,s.StartEventDate,s.EndEventDate)) AS FLOAT)/60.0,4) AS SeqStDev,
			ROUND(MAX(DATEDIFF(ss,s.StartEventDate,s.EndEventDate))/60,4) AS SeqMax,
			ROUND(CAST(AVG(DATEDIFF(ss,s.StartEventDate,s.EndEventDate)) AS FLOAT),4)/60.0 AS SeqAvg,
			ROUND(MIN(DATEDIFF(ss,s.StartEventDate,s.EndEventDate))/60,4) AS SeqMin,
			SUM(DATEDIFF(ss,s.StartEventDate,s.EndEventDate))/60 AS SeqSum,
			COUNT(DISTINCT s.CaseID) AS Cases,
			STRING_AGG(s.[CaseID],',') WITHIN GROUP (ORDER BY s.[CaseID]) AS [CaseIDs_List]
		FROM
			@seq1 s
		GROUP BY
			s.Seq

	SELECT *
	FROM @seq
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateCaseFromEvents]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "dbo.UpdateCaseFromEvents",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Recalculates and updates the EventCount, StartDateTime, and EndDateTime in the Cases table based on the EventsFact entries, optionally for a single case or all cases.",
  "Utilization": "Use when case-level metadata should be refreshed from the events that belong to the case, especially after new event loads or corrections.",
  "Input Parameters": [
    { "name": "@CaseID", "type": "INT", "default": "NULL", "description": "Identifier of the case to update; NULL to update all cases." }
  ],
  "Output Notes": [
    { "name": "Updated Rows", "type": "N/A", "description": "Number of cases updated." }
  ],
  "Referenced objects": [
    { "name": "dbo.Cases",      "type": "Table", "description": "Target table where case summary fields are stored." },
    { "name": "dbo.EventsFact", "type": "Table", "description": "Source table of event records used to compute counts and date ranges." }
  ]
}


Sample utilization:
    EXEC dbo.UpdateCaseFromEvents @CaseID = 871;
    EXEC dbo.UpdateCaseFromEvents @CaseID = NULL;  -- Update all cases

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE PROCEDURE [dbo].[UpdateCaseFromEvents]
@CaseID INT=NULL --NULL means update values for all caseID
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	UPDATE c
	SET
		c.EventCount = t.EventCount,
		c.StartDateTime = t.StartDateTime,
		c.EndDateTime = t.EndDateTime
	FROM
		dbo.Cases c
	JOIN
		(
			SELECT
				CaseID,
				MAX(CaseOrdinal) AS EventCount,
				MIN(EventDate) AS StartDateTime,
				MAX(EventDate) AS EndDateTime
			FROM
				dbo.EventsFact
			WHERE
				@CaseID IS NULL OR CaseID = @CaseID
			GROUP BY
				CaseID
		) t
		ON c.CaseID = t.CaseID
	WHERE
		@CaseID IS NULL OR c.CaseID = @CaseID;

	INSERT INTO dbo.ProcErrorLog
	(
	  ProcedureName,
	  EventName,
	  PropertyName,
	  ErrorMessage,
	  ID
	)
	VALUES
	(
	  OBJECT_NAME(@@PROCID),            -- ProcedureName
	  'CaseUpdated',              
	  'CaseID',                   -- PropertyName
	  CONCAT('Case Inserted ', @CaseID), 
	  @CaseID
	 )

END
GO
/****** Object:  StoredProcedure [dbo].[UpdateCases_retire]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
/*
EXEC UpdateCases
*/
CREATE PROCEDURE [dbo].[UpdateCases_retire]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    MERGE [dbo].[Cases] AS tgt  
    USING (
	SELECT 
		e.CaseID,
		MIN(e.EventDate) AS StartDateTime,
		MAX(e.EventDate) AS EndDateTime,
		COUNT(*) AS EventCount
	FROM
		[dbo].[EventsFact] e 
	GROUP BY
		e.CaseID
	)as src (CaseID,StartDateTime,EndDateTime,EventCount)
    ON (tgt.CaseID = src.CaseID)  
    WHEN MATCHED THEN
        UPDATE SET 
			StartDateTime=src.StartDateTime,
			EndDateTime=src.EndDateTime,
			EventCount=src.EventCount
    WHEN NOT MATCHED THEN  
        INSERT (CaseID,CaseType,StartDateTime,EndDateTime,EventCount)  
        VALUES (src.CaseID,'Event',src.StartDateTime,src.EndDateTime,src.EventCount)
;
END
GO
/****** Object:  StoredProcedure [dbo].[UpdateTransform]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "dbo.UpdateTransform",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Updates an existing transforms entry by computing its key, ensuring the code is unique for that key, updating its code and description, and logs the update event.",
  "Utilization": "Use when changing an existing transform definition without manually editing metadata tables, especially when event normalization rules evolve.",
  "Input Parameters": [
    { "name": "@Transforms",   "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON mapping definitions for event name transformations." },
    { "name": "@Code",         "type": "NVARCHAR(20)",   "default": "NULL", "description": "Short code or identifier for this transforms set." },
    { "name": "@Dessciption",  "type": "NVARCHAR(500)",  "default": "NULL", "description": "New descriptive text for the transforms set." },
    { "name": "@Transformskey","type": "VARBINARY(16)",  "default": "OUTPUT", "description": "OUTPUT. The MD5 key computed for the transforms JSON." }
  ],
  "Output Notes": [
    { "name": "ProcErrorLog Entry", "type": "Table", "description": "A record inserted indicating the transforms update event." }
  ],
  "Referenced objects": [
    { "name": "dbo.TransformsKey",   "type": "Scalar Function", "description": "Generates the canonical VARBINARY key for the transforms JSON." },
    { "name": "dbo.Transforms",      "type": "Table",           "description": "Stores distinct transforms JSON payloads keyed by TransformsKey." },
    { "name": "dbo.ProcErrorLog",    "type": "Table",           "description": "Procedure error/event logging table used to record the update." }
  ]
}


Sample utilization:
    DECLARE @tk VARBINARY(16);
    EXEC dbo.UpdateTransform
      @Transforms = '{"arnold1":"arnold","arnold2":"arnold","keto1":"dietpage","weightwatcher1":"dietpage","vanproteinbars":"proteinbars","chocproteinbars":"proteinbars"}',
      @Code = 'Map1',
      @Dessciption = 'Maps A to X and B to Y',
      @Transformskey = @tk OUTPUT;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE PROCEDURE [dbo].[UpdateTransform]
@Transforms NVARCHAR(MAX),
@Code NVARCHAR(20),
@Dessciption NVARCHAR(500),
@Transformskey VARBINARY(16) OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF @Transforms IS NOT NULL AND @Code IS NOT NULL
	BEGIN
		SET @Transformskey=[dbo].[TransformsKey](@Transforms)
		--Be sure the code doesn't belong to another transform key.
		IF NOT EXISTS (SELECT TransformsKey FROM [dbo].[Transforms] WHERE [Code]=@Code AND [TransformsKey]<>@Transformskey)
		BEGIN
			UPDATE Transforms SET 
				[Code]=@Code,
				[Description]=@Dessciption,
				LastUpdate=getdate()
			WHERE 
				TransformsKey=@Transformskey
		END
	END

	INSERT INTO dbo.ProcErrorLog
	(
	  ProcedureName,
	  EventName,
	  PropertyName,
	  binaryID
	)
	VALUES
	(
	  OBJECT_NAME(@@PROCID),            -- ProcedureName
	  'TransformUpdated',              
	  '@TransformKey',                   -- PropertyName
	  @Transformskey
	 )

END
GO
/****** Object:  StoredProcedure [dbo].[usp_LogTimestamp]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_LogTimestamp]
    @StepName NVARCHAR(100) = NULL,
    @Message  NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @timestamp NVARCHAR(30) = CONVERT(VARCHAR(30), SYSDATETIME(), 121);
    DECLARE @output NVARCHAR(MAX);

    IF @StepName IS NOT NULL
        SET @output = FORMATMESSAGE('[%s] Step: %s - %s', @timestamp, @StepName, ISNULL(@Message, ''));
    ELSE
        SET @output = FORMATMESSAGE('[%s] %s', @timestamp, ISNULL(@Message, ''));

    PRINT @output;
END;
GO
/****** Object:  StoredProcedure [dbo].[utility_Bad_Data]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "dbo.utility_Bad_Data",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Performs a series of data‐quality checks across event and metadata tables: identifies cases with duplicate timestamps, non-unique EventSetCode values, and cases missing valid source or property mappings.",
  "Utilization": "Use when scanning for, logging, or correcting known bad-data patterns in the Time Molecules environment, especially during ETL hygiene and troubleshooting.",
  "Input Parameters": [
    { "name": "@IncludeCases", "type": "BIT", "default": "0", "description": "If 1, include detailed case/property rows in the missing‐source check; otherwise only return summary issues." }
  ],
  "Output Notes": [
    { "name": "DuplicateTimestamps", "type": "Resultset", "description": "Rows from EventsFact where a CaseID has multiple identical EventDate values." },
    { "name": "NonUniqueEventSetCodes", "type": "Resultset", "description": "EventSetCode values in EventSets table that are non-null but appear more than once." },
    { "name": "CasesMissingSource", "type": "Resultset", "description": "Case records lacking a valid SourceID or SourceColumnID, with joined property and source details." }
  ],
  "Referenced objects": [
    { "name": "dbo.EventsFact",               "type": "Table",                 "description": "Fact table of all events with CaseID and EventDate." },
    { "name": "dbo.EventSets",                "type": "Table",                 "description": "Lookup of named event sets and their codes." },
    { "name": "dbo.Cases",                    "type": "Table",                 "description": "Master table of cases with source and type metadata." },
    { "name": "dbo.CasePropertiesParsed",     "type": "Table",                 "description": "Parsed case-level property values including SourceColumnID." },
    { "name": "dbo.Sources",                  "type": "Table",                 "description": "Registered data sources with connection metadata." }
  ]
}


Sample utilization:
    EXEC dbo.utility_Bad_Data @IncludeCases = 1;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, transaction management, indexing, or performance tuning have been omitted.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE PROCEDURE [dbo].[utility_Bad_Data]
@IncludeCases BIT=0 --There could be lots of cases. Mostly interested in metadata.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--EventSetCode must be unique or null.
	SELECT
		s.ServerName,
		s.DatabaseName,
		COALESCE(s.DefaultTableName,'NULL') AS [DefaultTableName],
		'Duplicate server, database, default table',
		COUNT(*) AS [Count]
	FROM
		dbo.Sources s
	GROUP BY
		s.ServerName,
		s.DatabaseName,
		COALESCE(s.DefaultTableName,'NULL') 
	HAVING COUNT(*)<>1

	--Every CaseID row must have a unique time - ms are ok.
	SELECT 
	caseid,
	[EventDate],
	'Event is Case has same timestamp',
	count(*) 
	FROM dbo.EventsFact
	group by caseid,[EventDate] HAVING COUNT(*)<>1

	--EventSetCode must be unique or null.
	SELECT
		EventSetCode,
		'Event Set Code not Unique',
		COUNT(*) AS [Count]
	FROM
		dbo.EventSets
	WHERE
		EventSetCode IS NOT NULL
	GROUP BY EventSetCode
	HAVING COUNT(*)<>1

	--Cases Missing SourceID
	SELECT
		c.CaseID,
		c.SourceID,
		cp.SourceColumnID,
		s.[Name] AS [SourceName],
		s.ServerName,
		s.DatabaseName,
		s.DefaultTableName,
		cp.PropertyName,
		cp.PropertyValueAlpha,
		cp.PropertyValueNumeric,
		'Missing SourceID or SourceColumnID'
	FROM
		[dbo].[Cases] c (NOLOCK)
		JOIN [dbo].[CasePropertiesParsed] cp (NOLOCK) ON cp.CaseID=c.CaseID
		LEFT JOIN [dbo].[Sources] s (NOLOCK) ON s.SourceID=c.SourceID
	WHERE
		c.SourceID IS NULL OR 
		cp.SourceColumnID IS NULL


END
GO
/****** Object:  StoredProcedure [dbo].[utility_LogProcError]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Stored Procedure": "dbo.utility_LogProcError",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-03-27",
  "Description": "Inserts a row into dbo.ProcErrorLog for procedure events, warnings, or errors.",
  "Utilization": "Use when procedures need a common, reusable way to write rows to dbo.ProcErrorLog instead of repeating manual INSERT statements.",
  "Input Parameters": [
    { "name": "@ProcedureName", "type": "NVARCHAR(128)", "default": "NULL", "description": "Name of the calling procedure. If NULL, caller may pass OBJECT_NAME(@@PROCID)." },
    { "name": "@EventName", "type": "NVARCHAR(128)", "default": "NULL", "description": "Short event label such as ERROR, BatchDeleted, ModelDeleted, or ImportStarted." },
    { "name": "@PropertyName", "type": "NVARCHAR(128)", "default": "NULL", "description": "Optional contextual property such as BatchID, CaseID, ModelID, or parameter name." },
    { "name": "@ErrorMessage", "type": "NVARCHAR(MAX)", "default": "NULL", "description": "Detailed message or freeform log text." },
    { "name": "@LoggedAt", "type": "DATETIME2(7)", "default": "NULL", "description": "Optional explicit timestamp. If NULL, defaults to SYSUTCDATETIME()." }
  ],
  "Output Notes": [
    { "name": "dbo.ProcErrorLog row", "type": "Table", "description": "One log row inserted for the supplied event." }
  ],
  "Referenced objects": [
    { "name": "dbo.ProcErrorLog", "type": "Table", "description": "Procedure event/error log table." }
  ]
}
Sample utilization:

EXEC dbo.utility_LogProcError
    @ProcedureName = OBJECT_NAME(@@PROCID),
    @EventName = 'ERROR',
    @PropertyName = 'BatchID',
    @ErrorMessage = CONCAT(
        'BatchID=', @BatchID,
        '; Error ', ERROR_NUMBER(),
        '; Line ', ERROR_LINE(),
        '; Message: ', ERROR_MESSAGE()
    );

*/
CREATE   PROCEDURE [dbo].[utility_LogProcError]
    @ProcedureName NVARCHAR(128) = NULL,
    @EventName NVARCHAR(128) = NULL,
    @PropertyName NVARCHAR(128) = NULL,
    @ErrorMessage NVARCHAR(MAX) = NULL,
    @LoggedAt DATETIME2(7) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.ProcErrorLog
    (
        ProcedureName,
        EventName,
        PropertyName,
        ErrorMessage,
        LoggedAt
    )
    VALUES
    (
        @ProcedureName,
        @EventName,
        @PropertyName,
        @ErrorMessage,
        COALESCE(@LoggedAt, SYSUTCDATETIME())
    );
END
GO
/****** Object:  StoredProcedure [dbo].[utility_Set_CaseOrdinal]    Script Date: 4/21/2026 7:16:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Stored Procedure": "dbo.utility_Set_CaseOrdinal",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Recalculates and updates the CaseOrdinal for every event in EventsFact so that each CaseID’s events are sequentially numbered by EventDate.",
  "Utilization": "Use when case event order needs to be recalculated or repaired so sequence-based logic, drill-through, and model building all see correct event ordinals.",
  "Input Parameters": [],
  "Output Notes": [
    { "name": "Updated Rows", "type": "N/A", "description": "Updates EventsFact.CaseOrdinal in place; no resultset returned." }
  ],
  "Referenced objects": [
    { "name": "dbo.EventsFact", "type": "Table", "description": "Fact table of events containing CaseID, EventDate, and CaseOrdinal." }
  ]
}


Sample utilization:
    EXEC dbo.utility_Set_CaseOrdinal;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: concurrency control, indexing, or performance tuning have been omitted or simplified.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE PROCEDURE [dbo].[utility_Set_CaseOrdinal]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
		WITH OrderedEvents AS (
			SELECT 
				CaseID,
				EventDate,
				ROW_NUMBER() OVER (PARTITION BY CaseID ORDER BY EventDate) AS NewCaseOrdinal
			FROM dbo.EventsFact
		)
		UPDATE e
		SET e.CaseOrdinal = oe.NewCaseOrdinal
		FROM dbo.EventsFact e
		JOIN OrderedEvents oe ON e.CaseID = oe.CaseID AND e.EventDate = oe.EventDate;

END
GO
