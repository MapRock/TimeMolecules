USE [TimeSolution]
GO
/****** Object:  Schema [DIM]    Script Date: 4/21/2026 7:17:02 AM ******/
CREATE SCHEMA [DIM]
GO
/****** Object:  Schema [ETL]    Script Date: 4/21/2026 7:17:02 AM ******/
CREATE SCHEMA [ETL]
GO
/****** Object:  Schema [FACT]    Script Date: 4/21/2026 7:17:02 AM ******/
CREATE SCHEMA [FACT]
GO
/****** Object:  Schema [KPI]    Script Date: 4/21/2026 7:17:02 AM ******/
CREATE SCHEMA [KPI]
GO
/****** Object:  Schema [STAGE]    Script Date: 4/21/2026 7:17:02 AM ******/
CREATE SCHEMA [STAGE]
GO
/****** Object:  Schema [WORK]    Script Date: 4/21/2026 7:17:02 AM ******/
CREATE SCHEMA [WORK]
GO
/****** Object:  UserDefinedFunction [dbo].[AddSegmentProbabilities]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "dbo.AddSegmentProbabilities",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": "Aggregates probabilities across multiple model-event segments by reverse-engineering total event counts to yield an overall segment probability.",
  "Utilization": "Use when you want to combine several existing model segments into one rolled-up probability without rebuilding the whole model. Helpful for testing composite paths, summarizing related transitions, or estimating the probability of a larger process fragment from known segment probabilities.",
  "Input Parameters": [
    { "name": "@add_segments_json", "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON array of objects each with ModelID, EventA, and EventB to include in the aggregation." }
  ],
  "Output Notes": [
    { "name": "Return Value", "type": "FLOAT", "description": "Computed overall probability across the provided segments; NULL or error if any segment’s probability is zero." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelEvents", "type": "Table", "description": "Holds per-segment rows and probability (Prob) for each EventA→EventB." },
    { "name": "OPENJSON", "type": "Built-in Function", "description": "Parses the input JSON array into rows for joining against ModelEvents." }
  ]
}

Sample utilization:

    SELECT dbo.AddSegmentProbabilities(
        '[{"ModelID":1,"EventA":"arrive","EventB":"greeted"},'
        + '{"ModelID":1,"EventA":"charged","EventB":"depart"},'
        + '{"ModelID":4,"EventA":"charged","EventB":"bigtip"}]'
    );

Notes:
    • If any segment’s Prob is zero, the denominator SUM([Rows]/Prob) will error or return NULL—consider validating or filtering zero‐prob entries.

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/


CREATE FUNCTION [dbo].[AddSegmentProbabilities]
(
@add_segments_json NVARCHAR(MAX)
)
RETURNS FLOAT
AS
BEGIN
	DECLARE @result FLOAT = (
		SELECT
			SUM(me.[Rows]) / SUM(me.[Rows]/me.[Prob]) --SUM(me.[Rows]/me.[Prob] will reverse-engineer the total rows of EventA.
		FROM 
			[dbo].[ModelEvents] me
			JOIN OPENJSON(@add_segments_json) 
				WITH (
					ModelID INT '$.ModelID',
					EventA NVARCHAR(100) '$.EventA',
					EventB NVARCHAR(100) '$.EventB'
				) AS seg ON seg.ModelID=me.ModelID AND seg.EventA=me.EventA AND seg.EventB=me.EventB
		)
	RETURN @result

END
GO
/****** Object:  UserDefinedFunction [dbo].[BayesianProbability]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "dbo.BayesianProbability",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": "Calculates the joint and conditional probabilities of two event sequences occurring within the same case over a specified time range, returning counts and P(B|A), P(A|B), P(A), P(B).",
  "Utilization": "Use when you want to measure how often one event sequence co-occurs with another within the same case or time bucket. Helpful for questions like 'given A, how likely is B,' especially in exploratory process intelligence or causal-hypothesis work.",
  "Input Parameters": [
    { "name": "@SeqA",                  "type": "NVARCHAR(MAX)", "default": "—",   "description": "CSV list defining sequence A." },
    { "name": "@SeqB",                  "type": "NVARCHAR(MAX)", "default": "—",   "description": "CSV list defining sequence B." },
    { "name": "@EventSet",              "type": "NVARCHAR(MAX)", "default": "—",   "description": "Optional CSV of all events; if NULL, union of SeqA and SeqB." },
    { "name": "@StartDateTime",         "type": "DATETIME",       "default": "—",   "description": "Lower bound for event dates." },
    { "name": "@EndDateTime",           "type": "DATETIME",       "default": "—",   "description": "Upper bound for event dates." },
    { "name": "@transforms",            "type": "NVARCHAR(MAX)", "default": "—",   "description": "Optional event mapping rules." },
    { "name": "@CaseFilterProperties",  "type": "NVARCHAR(MAX)", "default": "—",   "description": "JSON of case-level filter properties." },
    { "name": "@EventFilterProperties", "type": "NVARCHAR(MAX)", "default": "—",   "description": "JSON of event-level filter properties." },
    { "name": "@GroupType",             "type": "NVARCHAR(10)",  "default": "—",   "description": "Grouping key: 'CASEID','DAY','MONTH','YEAR'." }
  ],
  "Output Notes": [
    { "name": "ACount",      "type": "INT",   "description": "Number of cases containing sequence A." },
    { "name": "BCount",      "type": "INT",   "description": "Number of cases containing sequence B." },
    { "name": "A_Int_BCount","type": "INT",   "description": "Number of cases containing both A and B." },
    { "name": "PB|A",        "type": "FLOAT", "description": "Conditional probability P(B|A)." },
    { "name": "PA|B",        "type": "FLOAT", "description": "Conditional probability P(A|B)." },
    { "name": "TotalCases",  "type": "INT",   "description": "Total distinct cases in the date range." },
    { "name": "PA",          "type": "FLOAT", "description": "Probability of sequence A P(A)." },
    { "name": "PB",          "type": "FLOAT", "description": "Probability of sequence B P(B)." }
  ],
  "Referenced objects": [
    { "name": "dbo.SelectedEvents",     "type": "Table-Valued Function", "description": "Returns filtered events for given parameters." },
    { "name": "dbo.DefaultGroupType",   "type": "Scalar Function",        "description": "Normalizes GroupType to CASEID/DAY/MONTH/YEAR." },
    { "name": "dbo.EventSetByCode",     "type": "Scalar Function",        "description": "Resolves EventSetCode to comma-separated events." },
    { "name": "string_split",           "type": "Built-in TVF",            "description": "Splits CSV into rows for sequence ranking." }
  ]
}

Sample utilization:

The Probability of B given A.
Given 'arrive,greeted', what is the probability of 'intro,order'?

SELECT * FROM dbo.BayesianProbability('arrive,greeted','intro,order','restaurantguest','01/01/1900','12/31/2050',NULL,NULL,NULL,NULL)
SELECT * FROM dbo.BayesianProbability('arrive,greeted','bigtip','restaurantguest','01/01/1900','12/31/2050',NULL,NULL,NULL,NULL)
SELECT * FROM dbo.BayesianProbability('arrive,greeted,seated','intro,drinks','restaurantguest','01/01/1900','12/31/2050',NULL,NULL,NULL,NULL)
SELECT * FROM dbo.BayesianProbability('arrive,greeted,seated','intro,drinks',NULL,'01/01/1900','12/31/2050',NULL,NULL,NULL,NULL)
SELECT * FROM dbo.BayesianProbability('GameState-1','folds',NULL,'01/01/1900','12/31/2050',NULL,NULL,NULL,NULL)


Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

Notes: 

The sequence order must be exact, to find the co-occurrence of two sequences. 
This is a Bayesian inference. Meaning, the two sequences are really objects. Do these two sequences occur in the same case?
There is no ByCase parameter since this is always comparing the co-occurwnce in a case.

*/
CREATE FUNCTION [dbo].[BayesianProbability]
(
	@SeqA NVARCHAR(MAX), --csv. 
	@SeqB NVARCHAR(MAX), --csv sequence.
	@EventSet NVARCHAR(MAX), -- IF NULL, this will be constructed from @SeA and @SeqB
	@StartDateTime DATETIME,
	@EndDateTime DATETIME,
	@transforms NVARCHAR(MAX),
	@CaseFilterProperties NVARCHAR(MAX),
	@EventFilterProperties NVARCHAR(MAX),
	@GroupType NVARCHAR(10) --NULL will default to CASEID. Values: 'CASEID','DAY','MONTH','YEAR'
)
RETURNS 
@result TABLE 
(
	ACount INT,
	BCount INT,
	A_Int_BCount INT,
	[PB|A] FLOAT,	-- P(B|A)
	[PA|B] FLOAT,	-- P(A|B)
	[TotalCases] INT,
	PA FLOAT,		--Probability of A P(A)
	PB FLOAT		--Probability of B P(B)
)
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

	DECLARE @t0 TABLE ([rank] INT,CaseID INT, [Event] NVARCHAR(50),UNIQUE ([CaseID],[rank]))
	INSERT INTO @t0
		SELECT 
			[rank],
			CASE
				WHEN @GroupType='DAY' THEN cast(convert(char(8), EventDate, 112) as int)
				WHEN @GroupType='MONTH' THEN YEAR(EventDate)*100+MONTH(EventDate)
				WHEN @GroupType='YEAR' THEN YEAR(EventDate)
				ELSE CaseID
			END AS CaseID,
			[Event]
		FROM 
			dbo.SelectedEvents(@EventSet,@enumerate_multiple_events,@StartDateTime,@EndDateTime,@transforms,@ByCase,@metric,@CaseFilterProperties,@EventFilterProperties)

	DECLARE @TotalCases INT=(SELECT COUNT(DISTINCT CaseID ) FROM @t0)

	DECLARE @A TABLE (CaseID INT,[rows] INT, UNIQUE (CaseID))
	INSERT INTO @A 
		SELECT 
			se.CaseID,
			COUNT(*) AS [rows]
		FROM
			@sqA sq
			JOIN @t0 se ON se.[Event]=sq.[Event] 
			JOIN @t0 se1 ON se1.CaseID=se.CaseID AND se1.[Event]=@Ar1 -- GEt the rank of the first event in the sequence.
		WHERE
			se.[Rank]=se1.[Rank]+sq.[Rank]-1 -- join to the event relative to the first event (which may not be rank=1).
		GROUP BY
			se.CaseID
		HAVING
			COUNT(*)=@ArCount

	DECLARE @B TABLE (CaseID INT,[rows] INT, UNIQUE (CaseID))
	INSERT INTO @B
		SELECT 
			se.CaseID,
			COUNT(*) AS [rows]
		FROM
			@sqB sq
			JOIN @t0 se ON se.[Event]=sq.[Event] 
			JOIN @t0 se1 ON se1.CaseID=se.CaseID AND se1.[Event]=@Br1
		WHERE
			se.[Rank]=se1.[Rank]+sq.[Rank]-1
		GROUP BY
			se.CaseID
		HAVING
			COUNT(*)=@BrCount

	DECLARE @ACount INT = (SELECT COUNT(*) FROM @A) 
	DECLARE @BCount INT = (SELECT COUNT(*) FROM @B) 
	DECLARE @A_Int_BCount INT =(SELECT COUNT(*) FROM @A a JOIN @B b ON a.CaseID=b.CaseID) 

	INSERT INTO @result
	SELECT 
		@ACount,
		@BCount,
		@A_Int_BCount, --Intersection of A and B.
		CASE WHEN COALESCE(@ACount,0)=0 THEN NULL ELSE @A_Int_BCount/CAST(@ACount AS FLOAT) END AS [PB|A],
		CASE WHEN COALESCE(@BCount,0)=0 THEN NULL ELSE @A_Int_BCount/CAST(@BCount AS FLOAT) END AS [PA|B],
		@TotalCases AS TotalCases,
		@ACount/CAST(@TotalCases AS FLOAT) AS PA,
		@BCount/CAST(@TotalCases AS FLOAT) AS PB
	RETURN 
END
GO
/****** Object:  UserDefinedFunction [dbo].[bigint_to_binary_string]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "dbo.bigint_to_binary_string",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-14",
  "Description": "Converts a BIGINT value into its 62-bit binary string representation, padding with leading zeros as needed.",
  "Utilization": "Use when you need a readable bit-string form of a BIGINT, especially for debugging access bitmaps, flags, or other packed integer settings.",
  "Input Parameters": [
    { "name": "@num", "type": "BIGINT", "default": null, "description": "The integer value to convert to binary." }
  ],
  "Output Notes": [
    { "name": "Return Value", "type": "VARCHAR(64)", "description": "Binary string (length 62) representing the bits of the input value, reversed into human-readable order." }
  ],
  "Referenced objects": []
}
Sample utilization:

    SELECT dbo.bigint_to_binary_string(13);  -- returns '000...01101'

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/

CREATE FUNCTION [dbo].[bigint_to_binary_string](@num BIGINT)
RETURNS VARCHAR(64)
AS
BEGIN
    DECLARE @binary_str VARCHAR(63) = '';
    DECLARE @i INT = 0;
	DECLARE @two BIGINT=2 -- Use this for power of 2 so this casts as bigint in POWER.
    WHILE @i < 62
    BEGIN
        SET @binary_str += CASE WHEN (@num & POWER(@two,@i))=POWER(@two,@i) THEN '1' ELSE '0' END 
        SET @i += 1;
    END;
    RETURN REVERSE(@binary_str);
END;
GO
/****** Object:  UserDefinedFunction [dbo].[CaseCharacteristics]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
*** THIS TVF is deprecated as it cannot be ported to Azure Synapse. Use the sproc, sp_CaseCharacteristics.***


Metadata JSON:
{
  "Table-Valued Function": "dbo.CaseCharacteristics",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": "Retrieves both anomaly-derived event-pair metrics and case-level properties for a given model, consolidating them into a single result set for downstream association analysis.",
  "Utilization": "Use when you want one result set that mixes model-derived anomaly signals with case properties for the same population of cases. Helpful for downstream association analysis, clustering, or finding which case attributes travel with anomalous behavior.",
  "Input Parameters": [
    { "name": "@ModelID", "type": "INT", "default": "NULL", "description": "Identifier of the model whose characteristics are to be returned." }
  ],
  "Output Notes": [
    { "name": "ModelID",              "type": "INT",          "description": "Model identifier for anomaly rows; NULL for case properties." },
    { "name": "CaseID",               "type": "INT",          "description": "Identifier of the case." },
    { "name": "EventIDA",             "type": "INT",          "description": "Event A ID for anomaly pairs; NULL for case properties." },
    { "name": "EventIDB",             "type": "INT",          "description": "Event B ID for anomaly pairs; NULL for case properties." },
    { "name": "Category",             "type": "NVARCHAR(50)", "description": "‘AnomalyCode’ for anomalies or ‘CaseProperty’ for properties." },
    { "name": "Attribute",            "type": "NVARCHAR(50)", "description": "Metric name for anomalies or property name for case properties." },
    { "name": "EventA",               "type": "NVARCHAR(20)", "description": "Name of event A for anomalies; NULL for case properties." },
    { "name": "EventB",               "type": "NVARCHAR(20)", "description": "Name of event B for anomalies; NULL for case properties." },
    { "name": "metric_zscore",        "type": "FLOAT",        "description": "Z-score of the anomaly metric; NULL for case properties." },
    { "name": "metric_value",         "type": "FLOAT",        "description": "Raw anomaly metric value; NULL for case properties." },
    { "name": "transistion_prob",     "type": "FLOAT",        "description": "Anomaly transition probability; NULL for case properties." },
    { "name": "EventAIsEntry",        "type": "BIT",          "description": "Flag if EventA is entry; NULL for case properties." },
    { "name": "EventBIsExit",         "type": "BIT",          "description": "Flag if EventB is exit; NULL for case properties." },
    { "name": "PropertyValueNumeric", "type": "FLOAT",        "description": "Numeric value of case property; NULL for anomalies." },
    { "name": "PropertyValueAlpha",   "type": "NVARCHAR(1000)","description": "Text value of case property; NULL for anomalies." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelDrillThrough",    "type": "Table-Valued Function", "description": "Provides list of CaseIDs for the given model." },
    { "name": "dbo.EventPairAnomalies",   "type": "Table",                  "description": "Stores computed anomaly event-pair metrics generated by MarkovProcess2." },
    { "name": "dbo.Models",               "type": "Table",                  "description": "Stores model metadata and links to Metrics." },
    { "name": "dbo.Metrics",              "type": "Table",                  "description": "Lookup of metric definitions used in anomaly analysis." },
    { "name": "dbo.CasePropertiesParsed", "type": "Table",                  "description": "Parsed case-level properties to include as characteristics." }
  ]
}

Sample utilization:

    SELECT * FROM dbo.CaseCharacteristics(1);
	SELECT * FROM dbo.CaseCharacteristics(2);

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/

CREATE FUNCTION [dbo].[CaseCharacteristics]
(
@ModelID INT
)
RETURNS 
@result TABLE 
(
	[ModelID] [int] NULL,
	[CaseID] [int] NOT NULL,
	[EventIDA] [int] NULL,
	[EventIDB] [int] NULL,
	[Category] [nvarchar](50) NOT NULL,
	[Attribute] [nvarchar](50) NOT NULL,
	[EventA] [nvarchar](20) NULL,
	[EventB] [nvarchar](20) NULL,
	[metric_zscore] [float] NULL,
	[metric_value] [float] NULL,
	[transistion_prob] [float] NULL,
	[EventAIsEntry] [bit] NULL,
	[EventBIsExit] [bit] NULL,
	[PropertyValueNumeric] [float] NULL,
	[PropertyValueAlpha] [nvarchar](1000) NULL
)
AS
BEGIN
	DECLARE @Cases TABLE (CaseID INT, UNIQUE (CaseID))
	INSERT INTO @Cases
		SELECT DISTINCT
			CaseID
		FROM
			[dbo].[ModelDrillThrough](@ModelID,NULL,NULL)


	INSERT INTO @result
	SELECT epa.[ModelID]
		  ,epa.[CaseID]
		  ,[EventIDA]
		  ,[EventIDB]
		  ,[AnomalyCode] AS [Category]
		  ,met.Metric AS [Attribute]
		  ,[EventA]
		  ,[EventB]
		  ,[metric_zscore]
		  ,[metric_value]
		  ,[transistion_prob]
		  ,[EventAIsEntry]
		  ,[EventBIsExit]
		  ,NULL AS PropertyValueNumeric
		  ,NULL AS PropertyValueAlpha
	  FROM 
		  [dbo].[EventPairAnomalies] epa
		  JOIN [dbo].[Models] m ON m.modelid=epa.ModelID
		  JOIN [dbo].[Metrics] met ON met.MetricID=m.MetricID
		WHERE
			epa.ModelID=@ModelID
	UNION
	SELECT
		NULL AS ModelID,	--NULL because this is about Cases. The anomalies are part of a model, so we look at the ModelID.
		CaseID,
		NULL AS EventIDA,
		NULL AS EventIDB,
		'CaseProperty' AS [Category],
		cpp.PropertyName AS [Attribute],
		NULL AS EventA,
		NULL AS EventB,
		NULL AS metric_zscore,
		NULL AS metric_value,
		NULL AS transition_prob,
		NULL AS EventAIsEntry,
		NULL AS EventBIsExit,
		cpp.PropertyValueNumeric,
		cpp.PropertyValueAlpha
	FROM
		[dbo].[CasePropertiesParsed] cpp
	WHERE
		EXISTS (SELECT CaseID FROM @Cases epa WHERE epa.CaseID=cpp.CaseID)
	RETURN 
END
GO
/****** Object:  UserDefinedFunction [dbo].[CasesWithProperties]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Table-Valued Function": "dbo.CasesWithProperties",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": "Returns case rows enriched with up to five selected case‐level properties (both numeric and alpha), along with CaseType and SourceID.",
  "Utilization": "Use when you need to turn case-level properties from row form into a simple wide result per case. This is helpful for exploratory analysis, debugging property population, quick reporting, export to BI tools, or joining a few important case attributes into other SQL queries without repeatedly writing separate joins to dbo.CasePropertiesParsed.",
  "Input Parameters": [
    { "name": "@SelectedProperties", "type": "NVARCHAR(MAX)", "default": "NULL", "description": "CSV of up to five property names to retrieve per case." }
  ],
  "Output Notes": [
    { "name": "CaseID",          "type": "INT",           "description": "Identifier of the case." },
    { "name": "CaseType",        "type": "NVARCHAR(50)",   "description": "Name of the case type." },
    { "name": "SourceID",        "type": "INT",           "description": "Source system identifier for the case." },
    { "name": "Prop1",           "type": "nvarchar(50)",   "description": "First property name." },
    { "name": "Prop1Numeric",    "type": "FLOAT",         "description": "Numeric value of first property." },
    { "name": "Prop1Alpha",      "type": "NVARCHAR(1000)","description": "Alpha/text value of first property." },
    { "name": "Prop2",           "type": "nvarchar(50)",   "description": "Second property name." },
    { "name": "Prop2Numeric",    "type": "FLOAT",         "description": "Numeric value of second property." },
    { "name": "Prop2Alpha",      "type": "NVARCHAR(1000)","description": "Alpha/text value of second property." },
    { "name": "Prop3",           "type": "nvarchar(50)",   "description": "Third property name." },
    { "name": "Prop3Numeric",    "type": "FLOAT",         "description": "Numeric value of third property." },
    { "name": "Prop3Alpha",      "type": "NVARCHAR(1000)","description": "Alpha/text value of third property." },
    { "name": "Prop4",           "type": "nvarchar(50)",   "description": "Fourth property name." },
    { "name": "Prop4Numeric",    "type": "FLOAT",         "description": "Numeric value of fourth property." },
    { "name": "Prop4Alpha",      "type": "NVARCHAR(1000)","description": "Alpha/text value of fourth property." },
    { "name": "Prop5",           "type": "nvarchar(50)",   "description": "Fifth property name." },
    { "name": "Prop5Numeric",    "type": "FLOAT",         "description": "Numeric value of fifth property." },
    { "name": "Prop5Alpha",      "type": "NVARCHAR(1000)","description": "Alpha/text value of fifth property." }
  ],
  "Referenced objects": [
    { "name": "dbo.Cases",               "type": "Table",                "description": "Base table of cases." },
    { "name": "dbo.CaseTypes",           "type": "Table",                "description": "Lookup of case type names." },
    { "name": "dbo.CasePropertiesParsed","type": "Table",                "description": "Parsed case-level property values." },
    { "name": "string_split",            "type": "Built-in TVF",         "description": "Used to split CSV property list into rows." }
  ]
}
Sample utilization:

SELECT * FROM [dbo].[CasesWithProperties]('EmployeeID,CustomerID,OrderID')
SELECT * FROM [dbo].[CasesWithProperties]('Players,seats, button')

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/

CREATE FUNCTION [dbo].[CasesWithProperties]
(
	@SelectedProperties NVARCHAR(MAX) --CSV of properties
)
RETURNS 

@result TABLE (
	CaseID INT,
	CaseType NVARCHAR(50),
	SourceID INT,
	Prop1 nvarchar(50),
	Prop1Numeric FLOAT,
	PropAlpha NVARCHAR(1000),
	Prop2 nvarchar(50),
	Prop2Numeric FLOAT,
	Prop2Alpha NVARCHAR(1000),
	Prop3 nvarchar(50),
	Prop3Numeric FLOAT,
	Prop3Alpha NVARCHAR(1000),
	Prop4 nvarchar(50),
	Prop4Numeric FLOAT,
	Prop4Alpha NVARCHAR(1000),
	Prop5 nvarchar(50),
	Prop5Numeric FLOAT,
	Prop5Alpha NVARCHAR(1000)
)
AS
BEGIN



	DECLARE @Properties TABLE (property nvarchar(50),[rank] INT)
	DECLARE @PropKey1 nvarchar(50)
	DECLARE @PropKey2 nvarchar(50)
	DECLARE @PropKey3 nvarchar(50)
	DECLARE @PropKey4 nvarchar(50)
	DECLARE @PropKey5 nvarchar(50)
	IF @SelectedProperties IS NOT NULL
	BEGIN
		INSERT INTO @Properties
			SELECT TRIM([value]),ROW_NUMBER() OVER(ORDER BY [value]) [rank] FROM string_split(@SelectedProperties,',')
		SELECT @PropKey1=[property] FROM @Properties WHERE [rank]=1
		SELECT @PropKey2=[property] FROM @Properties WHERE [rank]=2
		SELECT @PropKey3=[property] FROM @Properties WHERE [rank]=3
		SELECT @PropKey4=[property] FROM @Properties WHERE [rank]=4
		SELECT @PropKey5=[property] FROM @Properties WHERE [rank]=5
	END

	INSERT INTO @result
		SELECT
			c.CaseID,
			ct.[Name] AS CaseType,
			c.SourceID,
			cp1.PropertyName,
			cp1.PropertyValueNumeric,
			cp1.PropertyValueAlpha,
			cp2.PropertyName,
			cp2.PropertyValueNumeric,
			cp2.PropertyValueAlpha,
			cp3.PropertyName,
			cp3.PropertyValueNumeric,
			cp3.PropertyValueAlpha,
			cp4.PropertyName,
			cp4.PropertyValueNumeric,
			cp4.PropertyValueAlpha,
			cp5.PropertyName,
			cp5.PropertyValueNumeric,
			cp5.PropertyValueAlpha
		FROM
			[dbo].[Cases] c
			JOIN [dbo].[CaseTypes] ct ON ct.CaseTypeID=c.CaseTypeID
			LEFT JOIN [dbo].[CasePropertiesParsed] cp1 ON @PropKey1 IS NOT NULL AND cp1.CaseID=c.CaseID AND cp1.PropertyName=@PropKey1
			LEFT JOIN [dbo].[CasePropertiesParsed] cp2 ON @PropKey2 IS NOT NULL AND cp2.CaseID=c.CaseID AND cp2.PropertyName=@PropKey2
			LEFT JOIN [dbo].[CasePropertiesParsed] cp3 ON @PropKey3 IS NOT NULL AND cp3.CaseID=c.CaseID AND cp3.PropertyName=@PropKey3
			LEFT JOIN [dbo].[CasePropertiesParsed] cp4 ON @PropKey4 IS NOT NULL AND cp4.CaseID=c.CaseID AND cp4.PropertyName=@PropKey4
			LEFT JOIN [dbo].[CasePropertiesParsed] cp5 ON @PropKey5 IS NOT NULL AND cp5.CaseID=c.CaseID AND cp5.PropertyName=@PropKey5
		WHERE
			cp1.CaseID IS NOT NULL OR cp2.CaseID IS NOT NULL OR cp3.CaseID IS NOT NULL OR cp4.CaseID IS NOT NULL OR cp5.CaseID IS NOT NULL



	RETURN 
END

--SELECT *,ROW_NUMBER() OVER(ORDER BY [key]) [Rank] FROM OPENJSON('{"EmployeeID":1}')
GO
/****** Object:  UserDefinedFunction [dbo].[ConditionalProbabilityTable]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
*** THIS TVF is deprecated as it cannot be ported to Azure Synapse. Use the sproc, sp_ConditionalProbabilityTable.***


Metadata JSON:
{
  "Table-Valued Function": "dbo.ConditionalProbabilityTable",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": "For each case or time-group (CASEID/DAY/MONTH/YEAR), counts occurrences of two event sequences A and B so you can compute conditional probabilities across cases.",
  "Utilization": "Use when you want grouped counts of sequence A and sequence B by case, day, month, or year so you can compute conditional probabilities or compare how the relationship changes over time.",
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

    SELECT * 
      FROM dbo.ConditionalProbabilityTable
        ('arrive,greeted','intro,order','restaurantguest',
         '1900-01-01','2050-12-31',NULL,NULL,NULL,'Day');

Notes:

    The Probability of B given A.
    Given 'arrive,greeted', what is the probability of 'intro,order'?
*/

CREATE FUNCTION [dbo].[ConditionalProbabilityTable]
(
	@SeqA NVARCHAR(MAX), --csv. 
	@SeqB NVARCHAR(MAX), --csv sequence.
	@EventSet NVARCHAR(MAX), -- IF NULL, this will be constructed from @SeA and @SeqB
	@StartDateTime DATETIME,
	@EndDateTime DATETIME,
	@transforms NVARCHAR(MAX),
	@CaseFilterProperties NVARCHAR(MAX),
	@EventFilterProperties NVARCHAR(MAX),
	@GroupType NVARCHAR(10) --NULL will default to CASEID. Values: 'CASEID','DAY','MONTH','YEAR'
)
RETURNS 
@result TABLE 
(
	GroupTypeKey INT,
	a INT,
	b INT
)
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

	INSERT INTO @result
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
				dbo.SelectedEvents(@EventSet,@enumerate_multiple_events,@StartDateTime,@EndDateTime,@transforms,@ByCase,@metric,@CaseFilterProperties,@EventFilterProperties) t
				LEFT JOIN @sqA a ON a.[Event]=t.[Event]
				LEFT JOIN @sqB b ON b.[Event]=t.[Event]
		) t
		GROUP BY
			t.GroupTypeKey
	RETURN 
END
GO
/****** Object:  UserDefinedFunction [dbo].[DefaultGroupType]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*

Scalar Function: [dbo].[DefaultGroupType]
Author: Eugene Asahara, eugene@softcodedlogic.com
Description:
    Normalizes a user-supplied GroupType string to one of the accepted values:
    ‘CaseID’, ‘DAY’, ‘MONTH’, or ‘YEAR’.  If input is NULL or not in the allowed
    list (case-insensitive), defaults to ‘CaseID’.

Sample utilization:

    SELECT dbo.DefaultGroupType(NULL);        -- returns 'CASEID'
    SELECT dbo.DefaultGroupType('month');     -- returns 'MONTH'
    SELECT dbo.DefaultGroupType('invalid');   -- returns 'CASEID'

Input Parameters:

    • @GroupType NVARCHAR(20)
        – The desired grouping period (e.g. ‘CASEID’, ‘DAY’, ‘MONTH’, ‘YEAR’).
        – NULL or unrecognized values are mapped to ‘CASEID’.

Output Notes:

    • Returns an NVARCHAR(20) uppercase string:
        – One of ‘CASEID’, ‘DAY’, ‘MONTH’, ‘YEAR’.
    • Always non-NULL; invalid or NULL input yields ‘CASEID’.

Referenced objects:

    • None (pure T-SQL scalar function).

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency,
      indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/

CREATE FUNCTION [dbo].[DefaultGroupType]
(
@GroupType NVARCHAR(20)
)
RETURNS NVARCHAR(20)
AS
BEGIN
	DECLARE @result NVARCHAR(20)
	SET @result=UPPER(COALESCE(@GroupType,'CaseID'))
	IF @result NOT IN ('CaseID','DAY','MONTH','YEAR')
	BEGIN
		SET @result='CaseID'
	END
	RETURN @result

END
GO
/****** Object:  UserDefinedFunction [dbo].[DrillThroughToModelEvents]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
*** THIS TVF is deprecated as it cannot be ported to Azure Synapse. Use the sproc, sp_DrillThroughToModelEvents.***


Metadata JSON:
{
  "Table-Valued Function": "DrillThroughToModelEvents",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Retrieves all events (with ordering, occurrence counts, and metric values) that constitute the specified Markov model by its ModelID, leveraging the parameters stored for that model.",
  "Utilization": "Use when you want to see the actual event rows behind a stored model, including order and metric values, instead of only the summarized model segments. Helpful for validation, walkthroughs, and explaining a model to others.",
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
    SELECT * FROM dbo.DrillThroughToModelEvents(24);

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security, concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/


CREATE FUNCTION [dbo].[DrillThroughToModelEvents]
(
@ModelID INT
)
RETURNS 

@result TABLE (
		CaseID int, 
		[Event] NVARCHAR(50), 
		EventDate datetime, 
		[Rank] INT NULL, 
		EventOccurence bigint,
		MetricActualValue FLOAT, 
		MetricExpectedValue FLOAT,
		UNIQUE (CaseID,[Rank])
)
AS
BEGIN

	DECLARE @Order INT
	DECLARE @EventSet NVARCHAR(MAX)
	DECLARE @enumerate_multiple_events INT
	DECLARE @StartDateTime DATETIME
	DECLARE @EndDateTime DATETIME
	DECLARE @transforms NVARCHAR(MAX)
	DECLARE @ByCase BIT=1
	DECLARE @metric NVARCHAR(20)
	DECLARE @CaseFilterProperties NVARCHAR(MAX)
	DECLARE @EventFilterProperties NVARCHAR(MAX)

	IF @ModelID IS NOT NULL
	BEGIN
		SELECT
			@Order=m.[Order],
			@EventSet=es.EventSet,
			@enumerate_multiple_events=m.enumerate_multiple_events,
			@StartDateTime=m.StartDateTime,
			@EndDateTime=m.EndDateTime,
			@transforms=t.transforms,
			@ByCase=m.ByCase,
			@metric=mt.Metric,
			@CaseFilterProperties=m.CaseFilterProperties,
			@EventFilterProperties=m.EventFilterProperties
		FROM
			[dbo].[Models] m
			JOIN [dbo].[EventSets] es ON es.EventSetKey=m.EventSetKey
			LEFT JOIN [dbo].[Transforms] t ON t.transformskey=m.transformskey
			LEFT JoIN dbo.[Metrics] mt ON mt.MetricID=m.MetricID
		WHERE
			ModelID=@ModelID

		INSERT INTO @result
		SELECT
			e.CaseID,
			e.[Event],
			e.EventDate,
			[Rank],
			[EventOccurence],
			e.MetricActualValue,
			MetricExpectedValue
		FROM
			SelectedEvents(@EventSet,@enumerate_multiple_events,@StartDateTime,@EndDateTime,@transforms,@ByCase,@metric,@CaseFilterProperties,@EventFilterProperties) e
	END
	RETURN 
END
GO
/****** Object:  UserDefinedFunction [dbo].[EventSetByCode]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "dbo.EventSetByCode",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-03-25",
  "Description": "Given an EventSetCode and a flag indicating set versus sequence, looks up and returns the corresponding EventSet definition as a comma-separated list of events from dbo.EventSets.",
  "Utilization": "Use when callers may provide a short event-set code instead of a literal event list and you want to resolve it into the actual comma-separated definition before filtering, model building, or event-set parsing.",
  "Input Parameters": [
    {
      "name": "@EventSetCode",
      "type": "NVARCHAR(20)",
      "default": null,
      "description": "Code identifying a named event set or sequence."
    },
    {
      "name": "@IsSequence",
      "type": "BIT",
      "default": "NULL",
      "description": "1 to retrieve a sequence definition; 0 or NULL to retrieve a set definition."
    }
  ],
  "Output Notes": [
    {
      "name": "Return Value",
      "type": "NVARCHAR(MAX)",
      "description": "Comma-separated list of events associated with the supplied EventSetCode and IsSequence flag."
    },
    {
      "name": "Null Handling",
      "type": "Note",
      "description": "Returns NULL if @EventSetCode is NULL or if no matching row is found."
    },
    {
      "name": "Default Behavior",
      "type": "Note",
      "description": "Defaults @IsSequence to 0 when NULL, so the lookup behaves as a set lookup unless sequence mode is explicitly requested."
    }
  ],
  "Referenced objects": [
    {
      "name": "dbo.EventSets",
      "type": "Table",
      "description": "Lookup table containing EventSetCode, EventSet definition text, and the IsSequence flag."
    }
  ]
}

Sample utilization:

    SELECT dbo.EventSetByCode('restaurantguest', 1);  -- returns sequence if defined
    SELECT dbo.EventSetByCode('restaurantguest', 0);  -- returns set if defined

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is not production-hardened: error handling, security, concurrency, indexing, query plan tuning, partitioning, and related concerns have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara.

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE FUNCTION [dbo].[EventSetByCode]
(
@EventSetCode NVARCHAR(4000), -- comma-separated list of Events
@IsSequence BIT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @result NVARCHAR(MAX)=NULL
	SET @IsSequence=COALESCE(@IsSequence,0) --Default to this being a set, not a sequence.

	IF @EventSetCode IS NOT NULL
	BEGIN
		SELECT
			@result=EventSet
		FROM
			[dbo].[EventSets]
		WHERE
			EventSetCode=@EventSetCode AND
			IsSequence=@IsSequence
	END
	RETURN @result

END
GO
/****** Object:  UserDefinedFunction [dbo].[EventSetKey]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "dbo.EventSetKey",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-03-25",
  "Description": "Generates a 16-byte binary key for a comma-separated list of events, treating the list either as a set (order-agnostic) or as a sequence (order-sensitive). Uses MD5 hashing of the normalized event list plus a single-character sequence flag.",
  "Utilization": "Use when you need a stable hash key for an event set or sequence so that equivalent definitions can be matched, stored, reused, or looked up consistently across models, metadata, and caching logic.",
  "Input Parameters": [
    {
      "name": "@EventSet",
      "type": "NVARCHAR(MAX)",
      "default": null,
      "description": "Comma-separated list of event codes, such as 'b,c,d'."
    },
    {
      "name": "@IsSequence",
      "type": "BIT",
      "default": "NULL",
      "description": "1 to treat @EventSet as an ordered sequence; 0 or NULL to treat it as an unordered set."
    }
  ],
  "Output Notes": [
    {
      "name": "Return Value",
      "type": "VARBINARY(16)",
      "description": "MD5 hash of the normalized event list plus the sequence flag."
    },
    {
      "name": "Set Behavior",
      "type": "Note",
      "description": "When @IsSequence is 0 or NULL, the function normalizes ordering so equivalent sets return the same key regardless of input order."
    },
    {
      "name": "Sequence Behavior",
      "type": "Note",
      "description": "When @IsSequence is 1, the sequence flag distinguishes ordered use from set-based use."
    },
    {
      "name": "Null Handling",
      "type": "Note",
      "description": "Returns NULL if @EventSet is NULL."
    },
    {
      "name": "Collision Note",
      "type": "Note",
      "description": "MD5 collisions are theoretically possible but unlikely for typical event-set usage."
    }
  ],
  "Referenced objects": [
    {
      "name": "string_split",
      "type": "Built-in Table-Valued Function",
      "description": "Splits the CSV input into rows."
    },
    {
      "name": "HASHBYTES",
      "type": "Built-in Function",
      "description": "Computes the MD5 hash used as the returned key."
    },
    {
      "name": "STRING_AGG",
      "type": "Built-in Aggregate Function",
      "description": "Reassembles the normalized event list into a canonical comma-separated string before hashing."
    },
    {
      "name": "DENSE_RANK",
      "type": "Built-in Window Function",
      "description": "Used in the normalization step when assigning ordering over the event values."
    }
  ]
}

Sample utilization:

    -- Same key for set {b,c,d}, regardless of input order:
    SELECT dbo.EventSetKey('b,c,d', NULL);
    SELECT dbo.EventSetKey('c,b,d', 0);
    SELECT dbo.EventSetKey('d,b,c', 0);

    -- Different key when treated as a sequence:
    SELECT dbo.EventSetKey('d,b,c', 1);

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is not production-hardened: error handling, security, concurrency, indexing, query plan tuning, partitioning, and related concerns have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara.

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE FUNCTION [dbo].[EventSetKey]
(
@EventSet NVARCHAR(MAX), -- comma-separated list of Events
@IsSequence BIT
)
RETURNS  VARBINARY(16)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @result VARBINARY(16)=NULL
	SET @IsSequence=COALESCE(@IsSequence,0) --Default to this being a set, not a sequence.
	IF @EventSet IS NOT NULL
	BEGIN
		DECLARE @kv TABLE ([event] nvarchar(50),r int)
		INSERT into @kv
			SELECT [event], DENSE_RANK() OVER (ORDER BY [event]) as [r]  FROM (SELECT TRIM([value]) AS [event] FROM string_split(@EventSet, ',')) t  order by [event]
		SELECT @result=HASHBYTES('MD5', STRING_AGG([event],',')+CAST(@IsSequence AS CHAR(1))) FROM @kv o
	END
	RETURN @result

END
GO
/****** Object:  UserDefinedFunction [dbo].[GetMetadataJsonValueFromDefinition]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Scalar Function": "dbo.GetMetadataJsonValueFromDefinition",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-03-25",
  "Description": "Extracts the Metadata JSON block from a module definition comment and returns the value of a specified top-level JSON key.",
  "Utilization": "Use when querying sys.sql_modules and you want to pull a single metadata field such as Description, Utilization, or Author from the Metadata JSON block without manually parsing the comment text.",
  "Input Parameters": [
    { "name": "@Definition", "type": "NVARCHAR(MAX)", "default": null, "description": "Full text of sys.sql_modules.definition." },
    { "name": "@KeyName",    "type": "NVARCHAR(400)", "default": null, "description": "Top-level JSON key to return, such as Description, Author, or Contact." }
  ],
  "Output Notes": [
    { "name": "Return Value", "type": "NVARCHAR(MAX)", "description": "Value of the specified top-level key from the Metadata JSON block, or NULL if not found or invalid." }
  ]
}
Sample utilization:
*/
CREATE   FUNCTION [dbo].[GetMetadataJsonValueFromDefinition]
(
    @Definition NVARCHAR(MAX),
    @KeyName NVARCHAR(400)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @StartTag NVARCHAR(100) = N'Metadata JSON:'
	DECLARE @EndTag NVARCHAR(100)='Sample utilization:'
    DECLARE @TagPos INT
    DECLARE @JsonStart INT
    DECLARE @CommentEnd INT
    DECLARE @JsonText NVARCHAR(MAX)
    DECLARE @Result NVARCHAR(MAX)

    SET @TagPos = CHARINDEX(@StartTag, @Definition)

    IF @Definition IS NULL OR @KeyName IS NULL OR @TagPos = 0
        RETURN NULL

    SET @JsonStart = CHARINDEX(N'{', @Definition, @TagPos + LEN(@StartTag))
    IF @JsonStart = 0
        RETURN NULL

    SET @CommentEnd = CHARINDEX(@EndTag, @Definition, @JsonStart)
    IF @CommentEnd = 0 OR @CommentEnd <= @JsonStart
        RETURN NULL

    SET @JsonText = LTRIM(RTRIM(SUBSTRING(@Definition, @JsonStart, @CommentEnd - @JsonStart)))

    IF ISJSON(@JsonText) <> 1
        RETURN NULL

    SELECT @Result = j.[value]
    FROM OPENJSON(@JsonText) j
    WHERE j.[key] = @KeyName

    RETURN @Result
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetModelEventString]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "dbo.GetModelEventString",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-14",
  "Description": "Aggregates all transition pairs (EventA → EventB) and their probabilities for a given model into a single delimited string.",
  "Utilization": "Use when you need a compact human-readable summary of a model’s event path or transitions for display, prompts, reporting, or quick inspection.",
  "Input Parameters": [
    { "name": "@ModelID", "type": "INT", "default": null, "description": "Identifier of the model whose transitions are to be concatenated." }
  ],
  "Output Notes": [
    { "name": "Return Value", "type": "NVARCHAR(MAX)", "description": "Concatenated string of the form 'EventA-(Prob)->EventB|...'; empty string if no transitions exist." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelEvents", "type": "Table", "description": "Holds first-order transition records, with EventA, EventB, Prob, and ModelID." }
  ]
}
Sample utilization:

    SELECT dbo.GetModelEventString(1);

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/


CREATE FUNCTION [dbo].[GetModelEventString]
(
    @ModelID INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Result NVARCHAR(MAX) = ''

    SELECT @Result = STRING_AGG(CONCAT(EventA, '-('+CAST(Prob AS NVARCHAR(10))+')->', EventB), '|')
    FROM dbo.ModelEvents
    WHERE ModelID = @ModelID

    RETURN @Result
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetModelPropertyString]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "GetModelPropertyString",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": [
    "Aggregates all properties for a given ModelID into a single string of the form 'PropertyName:Value|...'.",
    "Uses numeric PropertyValueNumeric when present; otherwise falls back to PropertyValueAlpha."
  ],
  "Utilization": "Use when you want to flatten a model’s properties into a single readable string for display, metadata generation, embeddings, or audit-style summaries.",
  "Input Parameters": [
    {"name":"@ModelID","type":"INT","default":null,"description":"The ModelID whose properties will be concatenated."}
  ],
  "Output Notes": [
    {"name":"Return Value","type":"NVARCHAR(MAX)","description":"Concatenated string 'PropertyName:Value|...'; empty string if no properties exist."}
  ],
  "Referenced objects": [
    {"name":"dbo.ModelProperties","type":"Table","description":"Holds model property records with columns PropertyName, PropertyValueNumeric, PropertyValueAlpha, and ModelID."}
  ]
}

Sample utilization:

    -- Concatenate all properties for model 6
    SELECT 
		mp.ModelID,
		dbo.GetModelPropertyString(mp.ModelID) PropertyString
	FRoM
		[dbo].[ModelProperties] mp
		

Context:
    • This function is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, indexing, and performance tuning have been simplified or omitted.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE FUNCTION [dbo].[GetModelPropertyString]
(
    @ModelID INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Result NVARCHAR(MAX) = ''

    SELECT @Result = STRING_AGG(CONCAT(PropertyName, ':', CASE WHEN PropertyValueNumeric IS NOT NULL THEN CAST(PropertyValueNumeric AS NVARCHAR(50)) ELSE PropertyValueAlpha END ), '|')
    FROM dbo.ModelProperties
    WHERE ModelID = @ModelID

    RETURN @Result
END
GO
/****** Object:  UserDefinedFunction [dbo].[GetViewColumns]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "GetViewColumns",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-04-16",
  "Description": "Returns a JSON document that lists the columns of a specified SQL Server view in ordinal order.",
  "Utilization": "Use when you want a lightweight JSON description of a view's output columns for metadata inspection, LLM prompts, documentation, or object-to-object mapping.",
  "Input Parameters": [
    { "name": "@ViewName", "type": "NVARCHAR(256)", "default": "NULL", "description": "Name of the view to inspect. May be schema-qualified such as 'dbo.vwModels' or unqualified, in which case schema dbo is assumed." }
  ],
  "Output Notes": [
    { "name": "return value", "type": "NVARCHAR(MAX)", "description": "JSON document of the form {\"Columns\":[{\"Name\":\"Column1\"},{\"Name\":\"Column2\"}]}, with columns returned in view ordinal order. Returns NULL if the view cannot be resolved." }
  ],
  "Referenced objects": [
    { "name": "sys.columns", "type": "System View", "description": "Supplies column metadata for the resolved view object." },
    { "name": "OBJECT_ID", "type": "Built-in Function", "description": "Resolves the object_id of the requested view using object type V." },
    { "name": "PARSENAME", "type": "Built-in Function", "description": "Parses a potentially schema-qualified two-part object name." },
    { "name": "QUOTENAME", "type": "Built-in Function", "description": "Safely delimits schema and object names during object resolution." },
    { "name": "FOR JSON PATH", "type": "SQL Clause", "description": "Formats the column list as JSON with root node Columns." }
  ]
}

Sample utilization:

SELECT dbo.GetViewColumns('dbo.vwModels');

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, concurrency, indexing, query plan tuning, partitioning, and related concerns have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE   FUNCTION [dbo].[GetViewColumns]
(
    @ViewName NVARCHAR(256)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @SchemaName SYSNAME;
    DECLARE @ObjectName SYSNAME;
    DECLARE @ObjectID INT;
    DECLARE @ColumnsJson NVARCHAR(MAX);

    SET @SchemaName =
        CASE
            WHEN CHARINDEX('.', @ViewName) > 0 THEN PARSENAME(@ViewName, 2)
            ELSE 'dbo'
        END;

    SET @ObjectName =
        CASE
            WHEN CHARINDEX('.', @ViewName) > 0 THEN PARSENAME(@ViewName, 1)
            ELSE @ViewName
        END;

    SET @ObjectID = OBJECT_ID(QUOTENAME(@SchemaName) + '.' + QUOTENAME(@ObjectName), 'V');

    IF @ObjectID IS NULL
        RETURN NULL;

    SELECT @ColumnsJson =
    (
        SELECT c.name AS [Name]
        FROM sys.columns c
        WHERE c.object_id = @ObjectID
        ORDER BY c.column_id
        FOR JSON PATH, ROOT('Columns')
    );

    RETURN @ColumnsJson;
END;
GO
/****** Object:  UserDefinedFunction [dbo].[IsMutuallyExclusive]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "IsMututallyExclusive",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": [
    "Determines whether two models’ time ranges do not overlap (i.e., are mutually exclusive).",
    "Returns 1 if Model1 ends before Model2 starts or Model2 ends before Model1 starts; otherwise 0."
  ],
  "Utilization": "Use when checking whether two events, properties, or conditions should be treated as incompatible in the same analytical context, especially when validating event-set or model design.",
  "Input Parameters": [
    {"name":"@ModelID1","type":"BIGINT","default":null,"description":"The first ModelID to compare."},
    {"name":"@ModelID2","type":"BIGINT","default":null,"description":"The second ModelID to compare."}
  ],
  "Output Notes": [
    {"name":"Return Value","type":"BIT","description":"1 if date ranges are mutually exclusive; 0 otherwise."}
  ],
  "Referenced objects": [
    {"name":"dbo.Models","type":"Table","description":"Holds model metadata, including StartDateTime and EndDateTime columns."}
  ]
}

Sample utilization:

    -- Check if models 1 and 2 have non‐overlapping time ranges
    SELECT dbo.IsMututallyExclusive(1, 2) AS AreExclusive;

Context:
    • This function is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, indexing, and performance tuning have been simplified or omitted.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/


CREATE FUNCTION [dbo].[IsMutuallyExclusive]
(
	@ModelID1 BIGINT,
	@ModelID2 BIGINT
)
RETURNS BIT
AS
BEGIN
	DECLARE @StartDate1 DATETIME2,
		@StartDate2 DATETIME2,
		@EndDate1 DATETIME2,
		@EndDate2 DATETIME2
	SELECT
		@StartDate1=m.StartDateTime,
		@EndDate1=m.EndDateTime
	FROM
		Models m
	WHERE
		m.modelid=@ModelID1

	SELECT
		@StartDate2=m.StartDateTime,
		@EndDate2=m.EndDateTime
	FROM
		Models m
	WHERE
		m.modelid=@ModelID2


	DECLARE @result BIT=
	(
		CASE
			WHEN
				(@EndDate1 < @StartDate2) OR (@EndDate2 < @StartDate1)
			THEN 1
			ELSE
				0
			END
		)
	RETURN @result

END

GO
/****** Object:  UserDefinedFunction [dbo].[MarkovChain_old]    Script Date: 4/21/2026 7:17:02 AM ******/
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
DECLARE @include NVARCHAR(MAX) = 'leavehome,heavytraffic,lighttraffic,arrivework'
SELECT * FROM dbo.[MarkovChain](@include,0,'01/01/1900','12/31/2050',NULL,1,'Fuel',NULL)
SELECT * FROM dbo.[MarkovChain](@include,0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL)
*/
CREATE FUNCTION [dbo].[MarkovChain_old]
(
	@Include NVARCHAR(MAX),
	@enumerate_multiple_events INT,
	@StartDateTime DATETIME,
	@EndDateTime DATETIME,
	@transforms NVARCHAR(MAX),
	@ByCase BIT=1,
	@metric NVARCHAR(20),
	@FilterProperties NVARCHAR(MAX)
)
RETURNS 

@seq1 TABLE (
	EventA NVARCHAR(20),
	EventB NVARCHAR(20),
	[Max] FLOAT,
	[Avg] FLOAT,
	[Min] FLOAT,
	[StDev] FLOAT,
	[CoefVar] FLOAT, --Coefficient of Variation.
	[Sum] FLOAT,
	[Rows] INT,
	Prob FLOAT,
	IsEntry BIT
)
AS
BEGIN

	SET @metric=COALESCE(@metric,'Time Between')
	DECLARE @metricMethod INT=(SELECT [Method] FROM [dbo].[Metrics] WHERE [Metric]=@metric)

	DECLARE @raw TABLE
	(
		CaseID int, 
		[Event] NVARCHAR(20), 
		EventDate datetime, 
		[Rank] INT NULL, 
		EventOccurance bigint,
		MetricInputValue FLOAT, 
		MetricOutputValue FLOAT,
		UNIQUE (CaseID,[Rank])
	)
	INSERT  INTO @raw
	SELECT
		e.CaseID,
		e.[Event],
		e.EventDate,
		[Rank],
		[EventOccurance],
		MetricInputValue,
		MetricOutputValue
	FROM
		SelectedEvents(@Include,@enumerate_multiple_events,@StartDateTime,@EndDateTime,@transforms,@ByCase,@metric,@FilterProperties,NULL) e

	;
	WITH t0 (EventA, EventB,[value],[Rank])
	AS
	(
	SELECT
		t1.[Event] AS EventA,
		t2.[Event] AS EventB,
		CASE WHEN @metric='Time Between' THEN
			DATEDIFF(ss,t1.[EventDate],t2.[EventDate])/60.0
		ELSE
			dbo.[MetricValue](@metricMethod,t1.MetricInputValue,t1.MetricOutputValue,t2.MetricInputValue,t2.MetricOutputValue)
		END AS [value],
		t1.[Rank]
	FROM
		@raw AS t1  --From Event
		JOIN @raw AS t2 ON t2.CaseID=t1.CaseID AND t2.[Rank]=t1.[Rank]+1 --To Event
	WHERE
		t2.CaseID IS NOT NULL --AND
		--t.[Event]!=p.[Event]

	),
	t1 (EventA,EventB,[Rows],[Avg],[StDev],[Max],[Min],IsEntry,[Sum])
	AS
	(
	SELECT
		t.[EventA] AS EventA,
		t.[EventB] AS EventB,
		COUNT(*) AS [Rows],
		CAST(AVG(t.[value]) AS FLOAT) AS [Avg],
		STDEV(t.[value]) AS [StDev],
		MAX(t.[value]) AS [Max],
		MIN(t.[value]) AS [Min],
		SUM(CASE WHEN t.[Rank]=1 THEN 1 ELSE 0 END) AS IsEntry,
		SUM(t.[value]) AS [Sum]
	FROM
		t0 AS t
	GROUP BY
		t.[EventA],
		t.[EventB]

	),
	t2 (EventA,[Total])
	AS
	(
	SELECT
		EventA,
		CAST(SUM([Rows]) AS FLOAT) AS Total
	FROM t1
	GROUP BY
		EventA
	)
	INSERT INTO @seq1
	SELECT
		t1.EventA,
		t1.EventB,
		t1.[Max],
		ROUND(t1.[Avg],4) AS [Avg],
		t1.[Min],
		ROUND(t1.[StDev],4) AS [StDev],
		ROUND(t1.[StDev]/t1.[Avg],3) AS [CoefVar], --Coefficient of Variation.
		t1.[Sum] AS [Sum],
		t1.[Rows],
		ROUND(t1.[Rows]/t2.[Total],4) AS Prob,
		t1.IsEntry
	FROM
		t1
		JOIN t2 ON t2.EventA=t1.EventA
	ORDER BY
		t1.EventA

	RETURN 
END
GO
/****** Object:  UserDefinedFunction [dbo].[MarkovChain_retired]    Script Date: 4/21/2026 7:17:02 AM ******/
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
Compare the 1st order and 2nd order

SELECT * FROM [dbo].[MarkovChain](0,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL)
SELECT * FROM [dbo].[MarkovChain](1,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL)
SELECT * FROM [dbo].[MarkovChain](2,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL)
SELECT * FROM [dbo].[MarkovChain](3,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL)
*/
CREATE FUNCTION [dbo].[MarkovChain_retired]
(
	@Order INT, -- 1, 2 or 3
	@EventSet NVARCHAR(MAX),
	@enumerate_multiple_events INT,
	@StartDateTime DATETIME,
	@EndDateTime DATETIME,
	@transforms NVARCHAR(MAX),
	@ByCase BIT=1,
	@metric NVARCHAR(20),
	@FilterProperties NVARCHAR(MAX),
	@ForceRefresh BIT
)
RETURNS 

@seq1 TABLE (
	ModelID INT,
	Event1A NVARCHAR(20), 
	Event2A NVARCHAR(20),
	Event3A NVARCHAR(20),
	EventB NVARCHAR(20),
	[Max] FLOAT,
	[Avg] FLOAT,
	[Min] FLOAT,
	[StDev] FLOAT,
	[CoefVar] FLOAT, --Coefficient of Variation.
	[Sum] FLOAT,
	[Rows] INT,
	Prob FLOAT,
	IsEntry BIT,
	IsExit BIT,
	FromCache BIT
)
AS
BEGIN

	SET @metric=COALESCE(@metric,'Time Between')
	DECLARE @metricMethod INT=(SELECT [Method] FROM [dbo].[Metrics] WHERE [Metric]=@metric)
	DECLARE @EventBIncrement INT= CASE WHEN COALESCE(@Order,1) BETWEEN 1 AND 3 THEN @Order ELSE 1 END
	SET @ForceRefresh=COALESCE(@ForceRefresh,0)

	DECLARE @ModelID INT=dbo.[ModelID]
	(
		@EventSet,
		@enumerate_multiple_events,
		@StartDateTime,
		@EndDateTime ,
		@transforms,
		@ByCase,
		@Metric,
		@FilterProperties
	)

	IF @ForceRefresh=0 AND @ModelID IS NOT NULL AND @EventBIncrement=1
	BEGIN
		INSERT INTO @seq1
			SELECT
				[ModelID]
				,[EventA]
				,NULL
				,NULL
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
				,1	--Is from cache
			  FROM 
					[dbo].[ModelEvents]
				WHERE
					ModelID=@ModelID
		RETURN
	END

	DECLARE @raw TABLE(CaseID int, [Event] NVARCHAR(20), EventDate datetime, [Rank] INT NULL, EventOccurance bigint,MetricInputValue FLOAT, MetricOutputValue FLOAT)
	INSERT  INTO @raw
	SELECT
		e.CaseID,
		e.[Event],
		e.EventDate,
		[Rank],
		[EventOccurance],
		MetricInputValue,
		MetricOutputValue
	FROM
		SelectedEvents(@EventSet,@enumerate_multiple_events,@StartDateTime,@EndDateTime,@transforms,@ByCase,@metric,@FilterProperties) e

	;
	WITH t0 (Event1A,Event2A,Event3A, EventB,[value],[IsEntry],[EventBIsExit])
	AS
	(
	SELECT
		t1a.[Event] AS Event1A,
		CASE WHEN @EventBIncrement<2 OR t1b.[Event] IS NULL THEN '------' ELSE t1b.[Event] END AS Event2A,
		CASE WHEN @EventBIncrement<3 OR t1c.[Event] IS NULL THEN '------' ELSE t1c.[Event] END AS Event3A,
		t2.[Event] AS EventB,
		CASE WHEN @metric='Time Between' THEN
			DATEDIFF(
				ss,
				CASE
					WHEN @EventBIncrement=1 THEN t1a.EventDate
					WHEN @EventBIncrement=2 THEN t1b.EventDate
					WHEN @EventBIncrement=3 THEN t1c.EventDate
				END,
				t2.[EventDate]
			)/60.0
		ELSE
			CASE
				WHEN @EventBIncrement=1 THEN dbo.[MetricValue](@metricMethod,t1a.MetricInputValue,t1a.MetricOutputValue,t2.MetricInputValue,t2.MetricOutputValue)
				WHEN @EventBIncrement=2 THEN dbo.[MetricValue](@metricMethod,t1b.MetricInputValue,t1b.MetricOutputValue,t2.MetricInputValue,t2.MetricOutputValue)
				WHEN @EventBIncrement=3 THEN dbo.[MetricValue](@metricMethod,t1c.MetricInputValue,t1c.MetricOutputValue,t2.MetricInputValue,t2.MetricOutputValue)
			END
		END AS [value],
		CASE WHEN t1a.[Rank]=1 THEN 1 ELSE 0 END AS IsEntry,
		CASE WHEN t2a.[Rank] IS NULL THEN 1 ELSE 0 END as EventBIsExit
	FROM
		@raw AS t1a  --From Event
		JOIN @raw AS t2 ON t2.CaseID=t1a.CaseID AND t2.[Rank]=t1a.[Rank]+@EventBIncrement 
		LEFT JOIN @raw AS t2a ON t2.CaseID=t2a.CaseID AND t2a.[Rank]=t2.[Rank]+1 --Read one past to see if this is the last eent in a case.
		LEFT JOIN @raw AS t1b ON t1b.CaseID=t1a.CaseID AND t1b.[Rank]=t1a.[Rank]+1 
		LEFT JOIN @raw AS t1c ON t1c.CaseID=t1a.CaseID AND t1c.[Rank]=t1a.[Rank]+2 

	),
	t1 (Event1A,Event2A,Event3A,EventB,[Rows],[Avg],[StDev],[Max],[Min],IsEntry,[EventBIsExit],[Sum])
	AS
	(
	SELECT
		t.[Event1A],
		t.Event2A,
		t.Event3A,
		t.[EventB] ,
		COUNT(*) AS [Rows],
		CAST(AVG(t.[value]) AS FLOAT) AS [Avg],
		STDEV(t.[value]) AS [StDev],
		MAX(t.[value]) AS [Max],
		MIN(t.[value]) AS [Min],
		SUM(t.IsEntry) AS IsEntry,
		SUM(t.EventBIsExit) AS IsExit,
		SUM(t.[value]) AS [Sum]
	FROM
		t0 AS t
	GROUP BY
		t.[Event1A],
		t.Event2A,
		t.Event3A,
		t.[EventB]

	),
	t2 (Event1A,Event2A,Event3A,[Total])
	AS
	(
	SELECT
		Event1A,
		Event2A,
		Event3A,
		CAST(SUM([Rows]) AS FLOAT) AS Total
	FROM t1
	GROUP BY
		Event1A,Event2A,Event3A
	)
	INSERT INTO @seq1
		SELECT
			@ModelID,
			t1.Event1A,
			t1.Event2A,
			t1.Event3A,
			t1.EventB,
			t1.[Max],
			ROUND(t1.[Avg],4) AS [Avg],
			t1.[Min],
			ROUND(t1.[StDev],4) AS [StDev],
			CASE WHEN t1.[Avg]=0 THEN NULL ELSE ROUND(t1.[StDev]/t1.[Avg],3) END AS [CoefVar], --Coefficient of Variation.
			t1.[Sum] AS [Sum],
			t1.[Rows],
			CASE WHEN t2.[Total]=0 THEN NULL ELSE ROUND(t1.[Rows]/t2.[Total],4) END AS Prob,
			t1.IsEntry,
			t1.EventBIsExit AS IsExit,
			0 --Not from cache
		FROM
			t1
			JOIN t2 ON t2.Event1A=t1.Event1A AND t2.Event2A=t1.Event2A AND t2.Event3A=t1.Event3A
		ORDER BY
			t1.Event1A,t1.Event2A,t1.Event3A

	RETURN 
END
GO
/****** Object:  UserDefinedFunction [dbo].[MarkovProcess]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*** THIS TVF is deprecated as it cannot be ported to Azure Synapse. Use the sproc, MarkovProcess2.***

Metadata JSON:
{
  "Table-Valued Function": "MarkovProcess",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-16",
  "Description": "Computes an Nth-order Markov chain over a specified event set and time window, returning detailed transition statistics, probabilities, entry/exit flags, ordinal metrics, and cache indicators for each tuple of prior events → next event.",
  "Input Parameters": [
    { "name": "@Order",                     "type": "INT",          "default": null, "description": "Desired Markov order (1–3); NULL or ≤0 defaults to 1." },
    { "name": "@EventSet",                  "type": "NVARCHAR(MAX)", "default": null, "description": "Comma-separated events or code referencing dbo.ParseEventSet." },
    { "name": "@enumerate_multiple_events", "type": "INT",          "default": null, "description": "When >0, appends sequence numbers to duplicate events in a case." },
    { "name": "@StartDateTime",             "type": "DATETIME",     "default": null, "description": "Inclusive lower bound; defaults to '1900-01-01' if NULL." },
    { "name": "@EndDateTime",               "type": "DATETIME",     "default": null, "description": "Inclusive upper bound; defaults to '2050-12-31' if NULL." },
    { "name": "@transforms",                "type": "NVARCHAR(MAX)", "default": null, "description": "JSON or code mapping of event rename transformations." },
    { "name": "@ByCase",                    "type": "BIT",          "default": 1,    "description": "1 to partition by CaseID; 0 to treat all events as one sequence." },
    { "name": "@metric",                    "type": "NVARCHAR(20)",  "default": null, "description": "Metric name in dbo.Metrics; defaults to 'Time Between'." },
    { "name": "@CaseFilterProperties",      "type": "NVARCHAR(MAX)", "default": null, "description": "JSON filters for CasePropertiesParsed." },
    { "name": "@EventFilterProperties",     "type": "NVARCHAR(MAX)", "default": null, "description": "JSON filters for EventPropertiesParsed." },
    { "name": "@ForceRefresh",              "type": "BIT",          "default": 0,    "description": "0 to use cache for order=1; 1 to recalculate always." }
  ],
  "Output Notes": [
    { "name": "ModelID",        "type": "INT",         "description": "Surrogate key identifying the Markov model." },
    { "name": "Event1A",        "type": "NVARCHAR(20)", "description": "First prior event (or '------' if unused)." },
    { "name": "Event2A",        "type": "NVARCHAR(20)", "description": "Second prior event (or '------' if unused)." },
    { "name": "Event3A",        "type": "NVARCHAR(20)", "description": "Third prior event (or '------' if unused)." },
    { "name": "EventB",         "type": "NVARCHAR(20)", "description": "Target event following the prior tuple." },
    { "name": "Min",            "type": "FLOAT",       "description": "Minimum observed metric value." },
    { "name": "Max",            "type": "FLOAT",       "description": "Maximum observed metric value." },
    { "name": "Avg",            "type": "FLOAT",       "description": "Average observed metric value." },
    { "name": "StDev",          "type": "FLOAT",       "description": "Standard deviation of metric values." },
    { "name": "CoefVar",        "type": "FLOAT",       "description": "Coefficient of variation (StDev/Avg), NULL if Avg=0." },
    { "name": "Sum",            "type": "FLOAT",       "description": "Sum of metric values across all occurrences." },
    { "name": "Rows",           "type": "INT",         "description": "Count of observed transitions." },
    { "name": "Prob",           "type": "FLOAT",       "description": "Transition probability = Rows / total Rows for that prior tuple." },
    { "name": "IsEntry",        "type": "INT",         "description": "1 if this is the first transition in a case." },
    { "name": "IsExit",         "type": "INT",         "description": "1 if no subsequent event follows this transition." },
    { "name": "FromCache",      "type": "BIT",         "description": "1 if loaded from cache, 0 if freshly computed." },
    { "name": "OrdinalMean",    "type": "FLOAT",       "description": "Average rank position of the transition." },
    { "name": "OrdinalStDev",   "type": "FLOAT",       "description": "Standard deviation of rank positions." },
    { "name": "metric",         "type": "NVARCHAR(20)", "description": "Actual metric name used." }
  ],
  "Referenced objects": [
    { "name": "dbo.SelectedEvents", "type": "Table-Valued Function", "description": "Filters and enriches EventsFact per model parameters." },
    { "name": "dbo.ModelID",        "type": "Scalar Function",       "description": "Retrieves or inserts a Markov model entry for given parameters." },
    { "name": "dbo.MetricValue",    "type": "Scalar Function",       "description": "Computes custom metric between two events." },
    { "name": "dbo.ModelEvents",    "type": "Table",                  "description": "Cached transition metrics for order=1 models." },
    { "name": "dbo.Models",         "type": "Table",                  "description": "Stores metadata and keys for Markov models." },
    { "name": "dbo.Metrics",        "type": "Table",                  "description": "Lookup of metric names and methods." }
  ]
}

Sample utilization:

    SELECT * 
      FROM dbo.MarkovProcess(
        1, 'restaurantguest', 0,
        '1900-01-01','2050-12-31',
        NULL, 1, NULL, NULL, NULL, 0
      );

    -- Force recalculation and bypass cache:
    SELECT * 
      FROM dbo.MarkovProcess(
        1, 'restaurantguest', 0,
        NULL,NULL,
        NULL, 1, NULL, NULL, NULL, 1
      );

    SELECT * 
      FROM dbo.MarkovProcess(
        2, 'restaurantguest', 0,
        '1900-01-01','2050-12-31',
        NULL, 1, NULL, NULL, NULL, 0
      );

    SELECT * 
      FROM dbo.MarkovProcess(
        3, 'restaurantguest', 0,
        '1900-01-01','2050-12-31',
        NULL, 1, NULL, NULL, NULL, 0
      );

    -- Bypass cache and default to order 1 when @Order ≤ 0
    SELECT * 
      FROM dbo.MarkovProcess(
        0, 'poker', 0,
        NULL, NULL,
        NULL, 1, NULL, NULL, NULL, 1
      );


Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

Input Notes:

    @Order                      INT  
        Desired Markov order (1–3).  
        NULL or ≤ 0 defaults to 1.

    @EventSet                   NVARCHAR(MAX)  
        Comma-separated event codes or a reference to dbo.IncludedEvents.Code.

    @enumerate_multiple_events  INT  
        When > 0, appends “1”, “2”,… to duplicate events in the same case for disambiguation.

    @StartDateTime              DATETIME  
        Inclusive lower bound; defaults to '1900-01-01' if NULL.

    @EndDateTime                DATETIME  
        Inclusive upper bound; defaults to '2050-12-31' if NULL.

    @transforms                 NVARCHAR(MAX)  
        JSON or code mapping “fromKey” → “toKey” for event renaming.

    @ByCase                     BIT  
        1 (default): partition by CaseID;  
        0: treat all events as a single synthetic case.

    @metric                     NVARCHAR(20)  
        Name of the event-level metric (must exist in dbo.Metrics).  
        Defaults to 'Time Between'.

    @CaseFilterProperties       NVARCHAR(MAX)  
        JSON object of CasePropertiesParsed filters (e.g. {"EmployeeID":1}).

    @EventFilterProperties      NVARCHAR(MAX)  
        JSON object of EventPropertiesParsed filters.

    @ForceRefresh               BIT  
        0 (default): use cached model if available and order = 1;  
        1: always recalculate.

Output Notes:

    ModelID         INT     — Surrogate key identifying the Markov model.  
    Event1A–Event3A NVARCHAR(20) — 1st–3rd prior events (’------’ if not used).  
    EventB          NVARCHAR(20) — Target event following the prior tuple.  
    Min, Max, Avg   FLOAT   — Metric statistics for the transition.  
    StDev           FLOAT   — Standard deviation of metric values.  
    CoefVar         FLOAT   — Coefficient of variation (StDev/Avg), NULL if Avg=0.  
    Sum             FLOAT   — Sum of all metric values.  
    Rows            INT     — Count of observed transitions.  
    Prob            FLOAT   — Transition probability = Rows / total Rows for that prior tuple.  
    IsEntry         INT     — 1 if this is the first transition in a case.  
    IsExit          INT     — 1 if no subsequent event follows this transition.  
    FromCache       BIT     — 1 if loaded from cache, 0 if freshly computed.  
    OrdinalMean     FLOAT   — Average rank position of the transition.  
    OrdinalStDev    FLOAT   — Standard deviation of rank positions.  
    metric          NVARCHAR(20) — Actual metric name used.

Context:  
    Part of the TimeSolution code supplementing the book  
    “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:  
    Licensed under the MIT License. See LICENSE.md for full terms.  
    (c) 2025 Eugene Asahara. All rights reserved.

*/

/*
Compare the 1st order and 2nd order

SELECT * FROM [dbo].[MarkovProcess](1,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL,NULL,0)
SELECT * FROM [dbo].[MarkovProcess](2,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL,NULL,0)
SELECT * FROM [dbo].[MarkovProcess](3,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL,NULL,0)
SELECT * FROM [dbo].[MarkovProcess](0,'poker',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL,NULL,1)

SELECT * FROM [dbo].[MarkovProcess](0,'restaurantguest',0,NULL,NULL,NULL,1,NULL,NULL,NULL,1)
SELECT * FROM [dbo].[MarkovProcess](0,'restaurantguest',0,NULL,NULL,NULL,1,NULL,'{"EmployeeID":1,"CustomerID":2}',NULL,1)

*/
CREATE FUNCTION [dbo].[MarkovProcess]
(
	@Order INT, -- 1, 2 or 3
	@EventSet NVARCHAR(MAX),
	@enumerate_multiple_events INT,
	@StartDateTime DATETIME,
	@EndDateTime DATETIME,
	@transforms NVARCHAR(MAX),
	@ByCase BIT=1,
	@metric NVARCHAR(20),
	@CaseFilterProperties NVARCHAR(MAX),
	@EventFilterProperties NVARCHAR(MAX),
	@ForceRefresh BIT
)
RETURNS 

@seq1 TABLE (
	ModelID INT,
	Event1A NVARCHAR(20), 
	Event2A NVARCHAR(20),
	Event3A NVARCHAR(20),
	EventB NVARCHAR(20),
	[Max] FLOAT, -- Max time between.
	[Avg] FLOAT, -- Avg time between.
	[Min] FLOAT, -- Min time between.
	[StDev] FLOAT, --StDev time between.
	[CoefVar] FLOAT, --Coefficient of Variation.
	[Sum] FLOAT, -- Sum time between.
	[Rows] INT,  -- Row count.
	Prob FLOAT,  -- Probability from EventA to EventB
	IsEntry INT,
	IsExit INT,
	FromCache BIT,
	OrdinalMean FLOAT,
	OrdinalStDev FLOAT,
	metric NVARCHAR(20)
)
AS
BEGIN

	DECLARE @CreatedBy_AccessBitmap BIGINT;


    SELECT
		@StartDateTime=StartDateTime,
		@EndDateTime=EndDateTime,
		@Order=[Order],
		@metric=[metric],
		@CreatedBy_AccessBitmap = AccessBitmap
      FROM dbo.SetDefaultModelParameters(
             @StartDateTime,    -- @StartDateTime
             @EndDateTime,    -- @EndDateTime
             @Order,    -- @Order
             NULL,    -- @enumerate_multiple_events
             @metric     -- @metric
           );

	DECLARE @metricMethod INT=(SELECT [Method] FROM [dbo].[Metrics] WHERE [Metric]=@metric)
	DECLARE @EventBIncrement INT= CASE WHEN COALESCE(@Order,1) BETWEEN 1 AND 3 THEN @Order ELSE 1 END
	SET @ForceRefresh=COALESCE(@ForceRefresh,0)

	DECLARE @ModelID INT=dbo.[ModelID]
	(
		@EventSet,
		@enumerate_multiple_events,
		@StartDateTime,
		@EndDateTime ,
		@transforms,
		@ByCase,
		@Metric,
		@CaseFilterProperties,
		@EventFilterProperties,
		'MarkovChain',
		@CreatedBy_AccessBitmap
	)

	IF @ForceRefresh=0 AND @ModelID IS NOT NULL AND @EventBIncrement=1
	BEGIN
		INSERT INTO @seq1
			SELECT
				me.[ModelID]
				,[EventA]
				,'------'
				,'------'
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
				,1	--Is from cache
				,OrdinalMean
				,OrdinalStDev
				,CASE WHEN met.Metric IS NULL THEN @metric ELSE met.Metric END
			  FROM 
					[dbo].[ModelEvents] me
					JOIN [dbo].[Models] m ON m.modelid=me.ModelID
					LEFT JOIN [dbo].[Metrics] met ON met.MetricID=m.MetricID
				WHERE
					me.ModelID=@ModelID
		RETURN
	END
	ELSE
	BEGIN
		SET @ModelID=NULL --Set to NULL because we're forcing a refresh.
	END

	DECLARE @raw TABLE
	(
		CaseID int, 
		[Event] NVARCHAR(20), 
		EventDate datetime, 
		[Rank] INT NULL, 
		EventOccurence bigint,
		MetricActualValue FLOAT, 
		MetricExpectedValue FLOAT,
		UNIQUE (CaseID,[Rank])
	)
	INSERT INTO @raw
	SELECT
		e.CaseID,
		e.[Event],
		e.EventDate,
		[Rank],
		[EventOccurence],
		MetricActualValue,
		MetricExpectedValue
	FROM
		SelectedEvents(@EventSet,@enumerate_multiple_events,@StartDateTime,@EndDateTime,@transforms,@ByCase,@metric,@CaseFilterProperties,@EventFilterProperties) e

	DECLARE @t0 TABLE
	(
		Event1A NVARCHAR(20),
		Event2A NVARCHAR(20),
		Event3A NVARCHAR(20), 
		EventB NVARCHAR(20),
		[value] FLOAT,
		[IsEntry] INT,
		[EventBIsExit] INT,
		[Rank] INT
		--No UNIQUE should be here.
	)

	INSERT INTO @t0
	SELECT
		t1a.[Event] AS Event1A,
		CASE WHEN @EventBIncrement<2 OR t1b.[Event] IS NULL THEN '------' ELSE t1b.[Event] END AS Event2A,
		CASE WHEN @EventBIncrement<3 OR t1c.[Event] IS NULL THEN '------' ELSE t1c.[Event] END AS Event3A,
		t2.[Event] AS EventB,
		CASE WHEN @metric='Time Between' THEN
			DATEDIFF(
				ss,
				CASE
					WHEN @EventBIncrement=1 THEN t1a.EventDate
					WHEN @EventBIncrement=2 THEN t1b.EventDate
					WHEN @EventBIncrement=3 THEN t1c.EventDate
				END,
				t2.[EventDate]
			)/60.0
		ELSE
			CASE
				WHEN @EventBIncrement=1 THEN dbo.[MetricValue](@metricMethod,t1a.MetricActualValue,t1a.MetricExpectedValue,t2.MetricActualValue,t2.MetricExpectedValue)
				WHEN @EventBIncrement=2 THEN dbo.[MetricValue](@metricMethod,t1b.MetricActualValue,t1b.MetricExpectedValue,t2.MetricActualValue,t2.MetricExpectedValue)
				WHEN @EventBIncrement=3 THEN dbo.[MetricValue](@metricMethod,t1c.MetricActualValue,t1c.MetricExpectedValue,t2.MetricActualValue,t2.MetricExpectedValue)
			END
		END AS [value],
		CASE WHEN t1a.[Rank]=1 THEN 1 ELSE 0 END AS IsEntry,
		CASE WHEN t2a.[Rank] IS NULL THEN 1 ELSE 0 END as EventBIsExit,
		CAST(t1a.[Rank] AS FLOAT) AS [Rank]
	FROM
		@raw AS t1a  --From Event
		JOIN @raw AS t2 ON t2.CaseID=t1a.CaseID AND t2.[Rank]=t1a.[Rank]+@EventBIncrement 
		LEFT JOIN @raw AS t2a ON t2.CaseID=t2a.CaseID AND t2a.[Rank]=t2.[Rank]+1 --Read one past to see if this is the last eent in a case.
		--These two LEFT JOINS create great perf problem without the Check on whether we need the join.
		LEFT JOIN @raw AS t1b ON @EventBIncrement>=2 AND t1b.CaseID=t1a.CaseID AND t1b.[Rank]=t1a.[Rank]+1 
		LEFT JOIN @raw AS t1c ON @EventBIncrement>=3 AND t1c.CaseID=t1a.CaseID AND t1c.[Rank]=t1a.[Rank]+2 

	DECLARE @t1 TABLE 
	(
		Event1A NVARCHAR(20),
		Event2A NVARCHAR(20),
		Event3A NVARCHAR(20), 
		EventB NVARCHAR(20),
		[Rows] INT,
		[Avg] FLOAT,
		[StDev] FLOAT,
		[Max] FLOAT,
		[Min] FLOAT,
		IsEntry INT,
		[EventBIsExit] INT,
		[Sum] FLOAT,
		[OrdinalMean] FLOAT,
		OrdinalStDev FLOAT

		)
	INSERT INTO @t1
	SELECT
		t.[Event1A],
		t.Event2A,
		t.Event3A,
		t.[EventB] ,
		COUNT(*) AS [Rows],
		CAST(AVG(t.[value]) AS FLOAT) AS [Avg],
		STDEV(t.[value]) AS [StDev],
		MAX(t.[value]) AS [Max],
		MIN(t.[value]) AS [Min],
		SUM(t.IsEntry) AS IsEntry,
		SUM(t.EventBIsExit) AS IsExit,
		SUM(t.[value]) AS [Sum],
		AVG(t.[Rank]),
		STDEV(t.[Rank])
	FROM
		@t0 AS t
	GROUP BY
		t.[Event1A],
		t.Event2A,
		t.Event3A,
		t.[EventB]


	DECLARE @t2 TABLE (
	Event1A NVARCHAR(20),Event2A NVARCHAR(20),Event3A NVARCHAR(20),[Total] FLOAT,
	UNIQUE (Event1A,Event2A,Event3A)
	)
	INSERT INTO @t2
	SELECT
		Event1A,
		Event2A,
		Event3A,
		CAST(SUM([Rows]) AS FLOAT) AS Total
	FROM @t1
	GROUP BY
		Event1A,Event2A,Event3A

	INSERT INTO @seq1
		SELECT
			@ModelID,
			t1.Event1A,
			t1.Event2A,
			t1.Event3A,
			t1.EventB,
			t1.[Max],
			ROUND(t1.[Avg],4) AS [Avg],
			t1.[Min],
			ROUND(t1.[StDev],4) AS [StDev],
			CASE WHEN t1.[Avg]=0 THEN NULL ELSE ROUND(t1.[StDev]/t1.[Avg],3) END AS [CoefVar], --Coefficient of Variation.
			t1.[Sum] AS [Sum],
			t1.[Rows],
			CASE WHEN t2.[Total]=0 THEN NULL ELSE ROUND(t1.[Rows]/t2.[Total],4) END AS Prob,
			t1.IsEntry,
			t1.EventBIsExit AS IsExit,
			0, --Not from cache
			t1.OrdinalMean,
			t1.OrdinalStDev,
			@metric
		FROM
			@t1 t1
			JOIN @t2 t2 ON t2.Event1A=t1.Event1A AND t2.Event2A=t1.Event2A AND t2.Event3A=t1.Event3A
		ORDER BY
			t1.Event1A,t1.Event2A,t1.Event3A

	RETURN 
END
GO
/****** Object:  UserDefinedFunction [dbo].[MarkovProcess_retired]    Script Date: 4/21/2026 7:17:02 AM ******/
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
Compare the 1st order and 2nd order

SELECT * FROM [dbo].[MarkovProcess1](0,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL,NULL)
SELECT * FROM [dbo].[MarkovProcess](1,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL,NULL)
SELECT * FROM [dbo].[MarkovProcess](2,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL,NULL)
SELECT * FROM [dbo].[MarkovProcess](3,'restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL,NULL)
*/
CREATE FUNCTION [dbo].[MarkovProcess_retired]
(
	@Order INT, -- 1, 2 or 3
	@EventSet NVARCHAR(MAX),
	@enumerate_multiple_events INT,
	@StartDateTime DATETIME,
	@EndDateTime DATETIME,
	@transforms NVARCHAR(MAX),
	@ByCase BIT=1,
	@metric NVARCHAR(20),
	@FilterProperties NVARCHAR(MAX),
	@ForceRefresh BIT
)
RETURNS 

@seq1 TABLE (
	ModelID INT,
	Event1A NVARCHAR(20), 
	Event2A NVARCHAR(20),
	Event3A NVARCHAR(20),
	EventB NVARCHAR(20),
	[Max] FLOAT,
	[Avg] FLOAT,
	[Min] FLOAT,
	[StDev] FLOAT,
	[CoefVar] FLOAT, --Coefficient of Variation.
	[Sum] FLOAT,
	[Rows] INT,
	Prob FLOAT,
	IsEntry BIT,
	IsExit BIT,
	FromCache BIT
)
AS
BEGIN

	SET @Order=COALESCE(@Order,1)
	SET @metric=COALESCE(@metric,'Time Between')
	DECLARE @metricMethod INT=(SELECT [Method] FROM [dbo].[Metrics] WHERE [Metric]=@metric)
	DECLARE @EventBIncrement INT= CASE WHEN @Order BETWEEN 1 AND 3 THEN @Order ELSE 1 END
	SET @ForceRefresh=COALESCE(@ForceRefresh,0)

	DECLARE @ModelID INT=dbo.[ModelID]
	(
		@EventSet,
		@enumerate_multiple_events,
		@StartDateTime,
		@EndDateTime ,
		@transforms,
		@ByCase,
		@Metric,
		@FilterProperties,
		NULL, --EventFilterProperties
		'MarkovChain'
	)


	IF @ForceRefresh=0 AND @ModelID IS NOT NULL AND @EventBIncrement=1
	BEGIN
		INSERT INTO @seq1
			SELECT
				[ModelID]
				,[EventA]
				,'------'
				,'------'
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
				,1	--Is from cache
			  FROM 
					[dbo].[ModelEvents]
				WHERE
					ModelID=@ModelID
		RETURN
	END

	DECLARE @raw TABLE(CaseID int, [Event] NVARCHAR(20), EventDate datetime, [Rank] INT NULL, EventOccurance bigint,MetricInputValue FLOAT, MetricOutputValue FLOAT)
	INSERT  INTO @raw
	SELECT
		e.CaseID,
		e.[Event],
		e.EventDate,
		[Rank],
		[EventOccurance],
		MetricInputValue,
		MetricOutputValue
	FROM
		SelectedEvents(@EventSet,@enumerate_multiple_events,@StartDateTime,@EndDateTime,@transforms,@ByCase,@metric,@FilterProperties,NULL) e

	DECLARE @t0 TABLE(Event1A NVARCHAR(20),Event2A NVARCHAR(20),Event3A NVARCHAR(20), EventB NVARCHAR(20),[value] FLOAT,[IsEntry] INT,[EventBIsExit] INT)
	INSERT INTO @t0
	SELECT
		t1a.[Event] AS Event1A,
		CASE WHEN @EventBIncrement<2 OR t1b.[Event] IS NULL THEN '------' ELSE t1b.[Event] END AS Event2A,
		CASE WHEN @EventBIncrement<3 OR t1c.[Event] IS NULL THEN '------' ELSE t1c.[Event] END AS Event3A,
		t2.[Event] AS EventB,
		CASE WHEN @metric='Time Between' THEN
			DATEDIFF(
				ss,
				CASE
					WHEN @EventBIncrement=1 THEN t1a.EventDate
					WHEN @EventBIncrement=2 THEN t1b.EventDate
					WHEN @EventBIncrement=3 THEN t1c.EventDate
				END,
				t2.[EventDate]
			)/60.0
		ELSE
			CASE
				WHEN @EventBIncrement=1 THEN dbo.[MetricValue](@metricMethod,t1a.MetricInputValue,t1a.MetricOutputValue,t2.MetricInputValue,t2.MetricOutputValue)
				WHEN @EventBIncrement=2 THEN dbo.[MetricValue](@metricMethod,t1b.MetricInputValue,t1b.MetricOutputValue,t2.MetricInputValue,t2.MetricOutputValue)
				WHEN @EventBIncrement=3 THEN dbo.[MetricValue](@metricMethod,t1c.MetricInputValue,t1c.MetricOutputValue,t2.MetricInputValue,t2.MetricOutputValue)
			END
		END AS [value],
		CASE WHEN t1a.[Rank]=1 THEN 1 ELSE 0 END AS IsEntry,
		CASE WHEN t2a.[Rank] IS NULL THEN 1 ELSE 0 END as EventBIsExit
	FROM
		@raw AS t1a  --From Event
		JOIN @raw AS t2 ON t2.CaseID=t1a.CaseID AND t2.[Rank]=t1a.[Rank]+@EventBIncrement 
		LEFT JOIN @raw AS t2a ON t2.CaseID=t2a.CaseID AND t2a.[Rank]=t2.[Rank]+1 --Read one past to see if this is the last eent in a case.
		LEFT JOIN @raw AS t1b ON t1b.CaseID=t1a.CaseID AND t1b.[Rank]=t1a.[Rank]+1 
		LEFT JOIN @raw AS t1c ON t1c.CaseID=t1a.CaseID AND t1c.[Rank]=t1a.[Rank]+2 

	DECLARE @t1 TABLE (Event1A NVARCHAR(20),Event2A NVARCHAR(20),Event3A NVARCHAR(20),EventB NVARCHAR(20),[Rows] INT,[Avg] FLOAT,[StDev] FLOAT,[Max] FLOAT,[Min] FLOAT,IsEntry INT,[EventBIsExit] INT,[Sum] FLOAT)
	INSERT INTO @t1
	SELECT
		t.[Event1A],
		t.Event2A,
		t.Event3A,
		t.[EventB] ,
		COUNT(*) AS [Rows],
		CAST(AVG(t.[value]) AS FLOAT) AS [Avg],
		STDEV(t.[value]) AS [StDev],
		MAX(t.[value]) AS [Max],
		MIN(t.[value]) AS [Min],
		SUM(t.IsEntry) AS IsEntry,
		SUM(t.EventBIsExit) AS IsExit,
		SUM(t.[value]) AS [Sum]
	FROM
		@t0 AS t
	GROUP BY
		t.[Event1A],
		t.Event2A,
		t.Event3A,
		t.[EventB]


	DECLARE @t2 TABLE (Event1A NVARCHAR(20),Event2A NVARCHAR(20),Event3A NVARCHAR(20),[Total] FLOAT)
	INSERT INTO @t2
	SELECT
		Event1A,
		Event2A,
		Event3A,
		CAST(SUM([Rows]) AS FLOAT) AS Total
	FROM @t1
	GROUP BY
		Event1A,Event2A,Event3A
	
	INSERT INTO @seq1
		SELECT
			@ModelID,
			t1.Event1A,
			t1.Event2A,
			t1.Event3A,
			t1.EventB,
			t1.[Max],
			ROUND(t1.[Avg],4) AS [Avg],
			t1.[Min],
			ROUND(t1.[StDev],4) AS [StDev],
			CASE WHEN t1.[Avg]=0 THEN NULL ELSE ROUND(t1.[StDev]/t1.[Avg],3) END AS [CoefVar], --Coefficient of Variation.
			t1.[Sum] AS [Sum],
			t1.[Rows],
			CASE WHEN t2.[Total]=0 THEN NULL ELSE ROUND(t1.[Rows]/t2.[Total],4) END AS Prob,
			t1.IsEntry,
			t1.EventBIsExit AS IsExit,
			0 --Not from cache
		FROM
			@t1 t1
			JOIN @t2 t2 ON t2.Event1A=t1.Event1A AND t2.Event2A=t1.Event2A AND t2.Event3A=t1.Event3A
		ORDER BY
			t1.Event1A,t1.Event2A,t1.Event3A

	RETURN 
END
GO
/****** Object:  UserDefinedFunction [dbo].[MetricValue]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "MetricValue",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": [
    "Calculates a metric value based on the specified method:",
    "0: Direct current value (like an odometer reading), which means return the value as is.",
    "1: Delta between actual values of successive events, which is like a reading; return the from-to difference.",
    "2: Leak amount (expected minus actual at the current event).",
    "3: Current actual value on arrival (backlog/bottleneck).",
    "4: Percentage change since previous event."
  ],
  "Utilization": "Use when you need one standardized way to calculate the metric value for a model segment or process step instead of rewriting metric logic in multiple queries. Method 0 returns the current value as-is, like a direct reading; method 1 returns the from-to delta between successive events, useful for change such as fuel consumed between locations; method 2 returns expected minus actual, useful for leak, loss, or slippage; method 3 returns the current actual value at arrival, useful for backlog, bottleneck, queue, or load; and method 4 returns percentage change since the previous event.",
  "Input Parameters": [
    {"name":"@metricmethod","type":"INT","default":null,"description":"Method selector (0–4) determining calculation logic."},
    {"name":"@From_MetricActualValue","type":"FLOAT","default":null,"description":"Actual metric value at the previous event (EventA)."},
    {"name":"@From_MetricExpectedValue","type":"FLOAT","default":null,"description":"Expected metric value at the previous event."},
    {"name":"@To_MetricActualValue","type":"FLOAT","default":null,"description":"Actual metric value at the current event (EventB)."},
    {"name":"@To_MetricExpectedValue","type":"FLOAT","default":null,"description":"Expected metric value at the current event."}
  ],
  "Output Notes": [
    {"name":"Return Value","type":"FLOAT","description":"Computed metric according to selected method; NULL if method not matched or division by zero."}
  ],
  "Referenced objects": []
}

Sample utilization:

    -- Get the actual value at EventB:
    SELECT dbo.MetricValue(0, 50, 60, 40, 60) AS Metric;

    -- Compute consumption between events:
    SELECT dbo.MetricValue(1, 50, NULL, 40, NULL) AS Consumption;

Context:
    • This function is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, indexing, and performance tuning have been simplified or omitted.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.


*/
CREATE FUNCTION [dbo].[MetricValue]
(
@metricmethod INT,
@From_MetricActualValue FLOAT, --"From" means previous. Usually "EventA".
@From_MetricExpectedValue FLOAT,
@To_MetricActualValue FLOAT, -- "To" means current. Usually "EventB".
@To_MetricExpectedValue FLOAT
)
RETURNS FLOAT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result FLOAT=
			CASE
				WHEN @metricMethod=0 THEN	
					@To_MetricActualValue
				WHEN @metricMethod=1 THEN
					@To_MetricActualValue-@From_MetricActualValue

				WHEN @metricMethod=2 THEN -- Leaks
					@To_MetricExpectedValue-@To_MetricActualValue
				WHEN @metricMethod=3 THEN -- This is the value of something as we arrive (to). Ex: Arriving at CSV, we saw 1000 boxes piled up to be processed. Backlog.
					@To_MetricActualValue
				WHEN @metricMethod=4 AND COALESCE(@To_MetricActualValue,0)<>0 THEN -- Percentage change since previous event.
					(@To_MetricActualValue-@From_MetricActualValue)/@From_MetricActualValue
			END
	-- Return the result of the function
	RETURN @result

END
GO
/****** Object:  UserDefinedFunction [dbo].[ModelDrillThrough]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
*** THIS TVF is deprecated as it cannot be ported to Azure Synapse. Use the sproc, sp_ModelDrillThrough.***


Metadata JSON:
{
  "Table-Valued Function": "ModelDrillThrough",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-16",
  "Description": "Retrieves paired events (EventA -> EventB) and their details for a specified Markov model, including elapsed minutes, rank, and occurrence counts.",
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
    { "name": "EventB_ID",      "type": "INT",          "description": "Internal EventID of EventB." }
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

    SELECT * FROM dbo.ModelDrillThrough(24,'lv-csv1','homedepot1');

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/



CREATE FUNCTION [dbo].[ModelDrillThrough]
(
@ModelID INT,
@EventA NVARCHAR(50),
@EventB NVARCHAR(50)

)
RETURNS 
@result TABLE 
(
	CaseID INT,
	[EventA] NVARCHAR(50),
	[EventB] NVARCHAR(50),
	EventDate_A DATETIME,
	EventDate_B DATETIME,
	[Minutes] FLOAT,
	[Rank] INT,
	EventOccurence INT,
	EventA_ID INT,
	EventB_ID INT
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
		[dbo].[Models] m
		JOIN [dbo].[Metrics] mt ON m.Metricid=mt.MetricID
		LEFT JOIN [dbo].[Transforms] t ON m.transformskey=t.transformskey
		LEFT JOIN [dbo].[EventSets] e ON e.EventSetKey=m.EventSetKey
	WHERE
		m.modelid=@ModelID
		AND (dbo.UserAccessBitmap() & m.AccessBitmap)=m.AccessBitmap

	DECLARE @tmp TABLE 
	(
		CaseID INT,
		[Event] NVARCHAR(50),
		EventDate DATETIME,
		[Rank] INT,
		EventOccurence INT,
		EventID INT
	)

	DECLARE @ByCase BIT=1
	
	INSERT INTO @tmp
	SELECT
		e.CaseID,
		e.[Event],
		e.EventDate,
		[Rank],
		[EventOccurence],
		EventID
	FROM
		SelectedEvents(@EventSet,@enumerate_multiple_events,@StartDateTime,@EndDateTime,@transforms,@ByCase,@Metric,@CaseFilterProperties,@EventFilterProperties) e


	INSERT INTO @result
	SELECT
		e1.CaseID,
		e.[Event] AS EventA,
		e1.[Event] AS EventB,
		e.EventDate,
		e1.EventDate,
		DATEDIFF(ss,e.EventDate,e1.EventDate)/60.0 AS [Minutes],
		e1.[Rank],
		e1.[EventOccurence],
		e.EventID,
		e1.EventID
	FROM
		@tmp e
		JOIN @tmp e1 ON e1.[Rank]=e.[Rank]+1 AND e.CaseID=e1.CaseID
	WHERE
		(@EventA IS NULL OR e.[Event]=@EventA)
		AND (@EventB IS NULL OR e1.[Event]=@EventB)

	RETURN 
END
GO
/****** Object:  UserDefinedFunction [dbo].[ModelEventKey]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "ModelEventKey",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": [
    "Generates a 16-byte MD5 hash representing the combination of model-level parameters and filters.",
    "Enables linking of events across different models (e.g., Markov vs. Bayesian) by hashing the canonicalized parameter set."
  ],
  "Utilization": "Use when you need a stable identifier for a model event segment, especially for joins, deduplication, caching, or comparing segment definitions across runs.",
  "Input Parameters": [
    {"name":"@EventSet","type":"NVARCHAR(MAX)","default":null,"description":"Identifier or CSV defining the event set."},
    {"name":"@enumerate_multiple_events","type":"BIT","default":null,"description":"Flag to collapse (0) or enumerate duplicates (1)."},
    {"name":"@StartDateTime","type":"DATETIME","default":null,"description":"Lower bound of the date range."},
    {"name":"@EndDateTime","type":"DATETIME","default":null,"description":"Upper bound of the date range."},
    {"name":"@transforms","type":"NVARCHAR(MAX)","default":null,"description":"JSON mapping for normalizing event names."},
    {"name":"@ByCase","type":"BIT","default":"1","description":"1 to group by CaseID; 0 to treat all events as one sequence."},
    {"name":"@Metric","type":"NVARCHAR(20)","default":null,"description":"Metric name (e.g., 'Time Between')."},
    {"name":"@CaseFilterProperties","type":"NVARCHAR(MAX)","default":null,"description":"JSON of case-level filter properties."},
    {"name":"@EventFilterProperties","type":"NVARCHAR(MAX)","default":null,"description":"JSON of event-level filter properties."}
  ],
  "Output Notes": [
    {"name":"Return Value","type":"VARBINARY(16)","description":"MD5 hash of the concatenated, canonicalized input values."}
  ],
  "Referenced objects": [
    {"name":"dbo.SortKeyValueJSON","type":"Scalar Function","description":"Sorts and normalizes JSON key/value pairs into a canonical string representation."}
  ]
}

Sample utilization:

    DECLARE @key VARBINARY(16) = dbo.ModelEventKey(
      N'SalesProcess', 1,
      '2024-01-01', '2024-12-31',
      N'{"currency":"USD"}', 1,
      N'TotalSales',
      N'{"store":"Walmart"}',
      N'{"eventType":"purchase"}'
    );
    SELECT @key AS HashedModelEventKey;

Context:
    • This function is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, indexing, and performance tuning have been simplified or omitted.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.





*/

CREATE FUNCTION [dbo].[ModelEventKey]
(
	@EventSet NVARCHAR(MAX),	
	@enumerate_multiple_events BIT,
	@StartDateTime DATETIME,
	@EndDateTime DATETIME,
	@transforms NVARCHAR(MAX),
	@ByCase BIT = 1,
	@Metric NVARCHAR(20) NULL,
	@CaseFilterProperties NVARCHAR(MAX),
	@EventFilterProperties NVARCHAR(MAX)
)
RETURNS VARBINARY(16)
AS
BEGIN
	DECLARE @sortedTransforms NVARCHAR(MAX)=dbo.[SortKeyValueJSON](@transforms)
	DECLARE @sortedCaseFilter NVARCHAR(MAX)=dbo.[SortKeyValueJSON](@CaseFilterProperties)
	DECLARE @sortedEventFilter NVARCHAR(MAX)=dbo.[SortKeyValueJSON](@EventFilterProperties)


	-- Build concatenated string
	DECLARE @concatenatedString NVARCHAR(MAX)

	SET @concatenatedString = 
		CONVERT(NVARCHAR(8), @StartDateTime, 112) +  -- yyyymmdd
		CONVERT(NVARCHAR(8), @EndDateTime, 112) +    -- yyyymmdd
		ISNULL(@EventSet, '') + 
		CAST(@enumerate_multiple_events AS NVARCHAR(1)) + 
		ISNULL(@sortedTransforms, '') +
		CAST(@ByCase AS NVARCHAR(1)) +
		ISNULL(@Metric, '') + 
		ISNULL(@sortedCaseFilter, '') + 
		ISNULL(@sortedEventFilter, '')

	RETURN HASHBYTES('MD5', @concatenatedString) 
END
GO
/****** Object:  UserDefinedFunction [dbo].[ModelEventsByProperty]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "ModelEventsByProperty",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-16",
  "Description": "Retrieves transition metrics (Min, Max, Avg, Sum, Rows, Prob, entry/exit flags) for all Markov models matching the specified event set, time window, transforms, grouping, metric, and filter properties.",
  "Utilization": "Use when you want transition rows for all models that share a given parameter set, rather than for just one model ID. Helpful for comparing model-event metrics across related models, retrieving transition statistics by model family, or supporting reports that need EventA→EventB metrics filtered by model-definition parameters.",
  "Input Parameters": [
    { "name": "@EventSet",                "type": "NVARCHAR(MAX)", "default": "NULL", "description": "Comma-separated list of events or code for dbo.ParseEventSet to define the event set." },
    { "name": "@enumerate_multiple_events","type": "INT",           "default": "NULL", "description": "Flag (0/1) controlling enumeration of repeated events within a case." },
    { "name": "@StartDateTime",           "type": "DATETIME",      "default": "NULL", "description": "Inclusive lower bound of event timestamps for model selection." },
    { "name": "@EndDateTime",             "type": "DATETIME",      "default": "NULL", "description": "Inclusive upper bound of event timestamps for model selection." },
    { "name": "@transforms",              "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON or code mapping for event transformations prior to modeling." },
    { "name": "@ByCase",                  "type": "BIT",           "default": "NULL", "description": "1 to partition events by CaseID; 0 to treat all events as a single sequence." },
    { "name": "@Metric",                  "type": "NVARCHAR(20)",  "default": "NULL", "description": "Optional metric name; NULL returns all metrics." },
    { "name": "@CaseFilterProperties",    "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON filters to apply to CasePropertiesParsed when selecting models." },
    { "name": "@EventFilterProperties",   "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON filters to apply to EventPropertiesParsed when selecting models." },
    { "name": "@ModelType",               "type": "NVARCHAR(50)",  "default": "NULL", "description": "Model type filter (e.g., 'MarkovChain', 'BayesianProbability')." }
  ],
  "Output Notes": [
    { "name": "ModelID",  "type": "INT",          "description": "Identifier of the matching Markov model." },
    { "name": "EventA",    "type": "NVARCHAR(20)", "description": "From-event in the transition." },
    { "name": "EventB",    "type": "NVARCHAR(20)", "description": "To-event in the transition." },
    { "name": "Max",       "type": "FLOAT",        "description": "Maximum observed metric value for the transition." },
    { "name": "Avg",       "type": "FLOAT",        "description": "Average observed metric value for the transition." },
    { "name": "Min",       "type": "FLOAT",        "description": "Minimum observed metric value for the transition." },
    { "name": "Sum",       "type": "FLOAT",        "description": "Sum of all metric values for the transition." },
    { "name": "Rows",      "type": "INT",          "description": "Count of observed transitions." },
    { "name": "Prob",      "type": "FLOAT",        "description": "Transition probability for the event pair." },
    { "name": "IsEntry",   "type": "INT",          "description": "1 if this transition begins a case; otherwise 0." },
    { "name": "IsExit",    "type": "INT",          "description": "1 if this transition ends a case; otherwise 0." },
    { "name": "Metric",    "type": "NVARCHAR(50)", "description": "Metric name associated with these transition values." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelsByParameters",   "type": "Table-Valued Function", "description": "Selects model IDs and metrics matching the parameter set." },
    { "name": "dbo.ModelEvents",          "type": "Table",                  "description": "Contains transition metrics for each model segment." },
    { "name": "dbo.Models",               "type": "Table",                  "description": "Holds model definitions, parameters, and access controls." }
  ]
}

Sample utilization:

	DECLARE @CreatedBy_AccessBitmap BIGINT=NULL
    SELECT *
      FROM dbo.ModelEventsByProperty(
        'leavehome,heavytraffic,lighttraffic,arrivework',
        0,
        NULL,
        NULL,
        NULL,
        1,
        NULL,
        NULL,
        NULL,
        NULL,
		@CreatedBy_AccessBitmap
      );

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

Notes:
    • @Metric should not default to 'Time Between'. NULL means return all metrics.
*/

CREATE FUNCTION [dbo].[ModelEventsByProperty]
(
	@EventSet NVARCHAR(MAX),
	@enumerate_multiple_events INT,
	@StartDateTime DATETIME,
	@EndDateTime DATETIME,
	@transforms NVARCHAR(MAX),
	@ByCase BIT, -- 1 should be the Default. If 0, consider everything to be one case.
	@Metric NVARCHAR(20) NULL, --If null, that means all models otherwise the same, but with different metric.
	@CaseFilterProperties NVARCHAR(MAX),
	@EventFilterProperties NVARCHAR(MAX),
	@ModelType NVARCHAR(50),
	@CreatedBy_AccessBitmap BIGINT	--NULL means don't filter by this model property.
)
RETURNS 

@result TABLE (
	ModelID INT,
	EventA NVARCHAR(50),
	EventB NVARCHAR(50),
	[Max] FLOAT,
	[Avg] FLOAT,
	[Min] FLOAT,
	[Sum] FLOAT,
	[Rows] INT,
	Prob FLOAT,
	IsEntry INT,
	IsExit INT,
	Metric NVARCHAR(50)
)
AS
BEGIN

	DECLARE @UserAccessBitmap BIGINT
    SELECT
		@StartDateTime=StartDateTime,
		@EndDateTime=EndDateTime,
		@enumerate_multiple_events=enumerate_multiple_events,
		@UserAccessBitmap=AccessBitmap
      FROM dbo.SetDefaultModelParameters(
             @StartDateTime,    -- @StartDateTime
             @EndDateTime,    -- @EndDateTime
             NULL,    -- @Order
             @enumerate_multiple_events,    -- @enumerate_multiple_events
             NULL     -- @metric
           );

	DECLARE @FM_tmp TABLE (ModelID INT, CaseFilterProperties NVARCHAR(MAX),Metric NVARCHAR(20))
	--Get models with the event set and CaseFilterProperties.
	INSERT INTO @FM_tmp
		SELECT ModelID, CaseFilterProperties,Metric
		FROM [dbo].ModelsByParameters(@EventSet, @enumerate_multiple_events, @StartDateTime,@EndDateTime, @transforms,@ByCase, @Metric,@CaseFilterProperties,@EventFilterProperties, @ModelType,NULL,@CreatedBy_AccessBitmap)
	
	INSERT INTO @result
		SELECT me.ModelID,EventA,EventB,[Max],[Avg],[Min],[Sum],[Rows],Prob,IsEntry,IsExit,f.Metric
		FROM 
			dbo.[ModelEvents] me
			JOIN @FM_tmp f ON f.ModelID=me.ModelID
			JOIN dbo.Models m On me.ModelID=m.modelid
		WHERE
			(m.AccessBitmap = - 1 OR @UserAccessBitmap & m.AccessBitmap <> 0)


	RETURN 
END
GO
/****** Object:  UserDefinedFunction [dbo].[ModelID]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "ModelID",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": [
    "Looks up an existing ModelID matching the full model definition (event set, date range, enumeration flag, transforms, grouping, metric, filters, and model type).",
    "Returns the first matching ModelID or NULL if none found."
  ],
  "Utilization": "Use when you want to resolve or derive a model identifier from model-defining inputs instead of hard-coding ModelID values in downstream logic.",
  "Input Parameters": [
    {"name":"@EventSet","type":"NVARCHAR(MAX)","default":null,"description":"Identifier or CSV defining the event set."},
    {"name":"@enumerate_multiple_events","type":"BIT","default":null,"description":"0 to collapse duplicates; 1 to enumerate each occurrence."},
    {"name":"@StartDateTime","type":"DATETIME","default":null,"description":"Lower bound of the model’s time range."},
    {"name":"@EndDateTime","type":"DATETIME","default":null,"description":"Upper bound of the model’s time range."},
    {"name":"@transforms","type":"NVARCHAR(MAX)","default":null,"description":"JSON mapping for normalizing event names."},
    {"name":"@ByCase","type":"BIT","default":"1","description":"1 to group by CaseID; 0 to treat all events as one sequence."},
    {"name":"@Metric","type":"NVARCHAR(20)","default":null,"description":"Name of the metric (e.g., 'Time Between')."},
    {"name":"@CaseFilterProperties","type":"NVARCHAR(MAX)","default":null,"description":"JSON of case-level filter key/value pairs."},
    {"name":"@EventFilterProperties","type":"NVARCHAR(MAX)","default":null,"description":"JSON of event-level filter key/value pairs."},
    {"name":"@ModelType","type":"NVARCHAR(50)","default":null,"description":"Type of model (e.g., 'MarkovChain')."}
  ],
  "Output Notes": [
    {"name":"Return Value","type":"INT","description":"The matching ModelID, or NULL if no existing model matches."}
  ],
  "Referenced objects": [
    {"name":"dbo.Models","type":"Table","description":"Holds model definitions, including date range, keys, and filter JSON."},
    {"name":"dbo.Metrics","type":"Table","description":"Maps metric names to MetricID."},
    {"name":"dbo.EventSetKey","type":"Scalar Function","description":"Computes canonical key for an EventSet input."},
    {"name":"dbo.TransformsKey","type":"Scalar Function","description":"Computes canonical key for transforms JSON input."}
  ]
}

Sample utilization:

    -- Find existing model for these parameters
    SELECT dbo.ModelID(
      'restaurantguest', 1, '1900-1-1','2050-12-31',
      NULL, 1,
      'Time Between',
      NULL,NULL,
      'MarkovChain'
    ) AS ExistingModelID;

    SELECT dbo.ModelID(
      'arrive,depart', 1, '1900-1-1','2050-12-31',
      NULL, 1,
      'Time Between',
      NULL,NULL,
      'MarkovChain'
    ) AS ExistingModelID;


Context:
    • Provided as-is for teaching and demonstration of the Time Molecules concepts.
    • **Not** production‐hardened: error handling, security, concurrency, indexing, query tuning, and partitioning are simplified or omitted.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE FUNCTION [dbo].[ModelID]
(
	@EventSet NVARCHAR(MAX),	--This is a set that in part of the model definition, therefore, EventSetKey can be given IsSequence=0
	@enumerate_multiple_events BIT,
	@StartDateTime DATETIME,
	@EndDateTime DATETIME,
	@transforms NVARCHAR(MAX),
	@ByCase BIT=1,
	@Metric NVARCHAR(20) NULL,
	@CaseFilterProperties NVARCHAR(MAX),
	@EventFilterProperties NVARCHAR(MAX),
	@ModelType NVARCHAR(50),
	@CreatedBy_AccessBitmap  BIGINT
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @result INT=
	(
		SELECT TOP 1
			ModelID 
		FROM 
			[dbo].[Models] m
			LEFT JOIN [dbo].[Metrics] mt ON mt.Metric=@Metric
		WHERE 
			StartDateTime=@StartDateTime 
			AND EndDateTime=@EndDateTime 
			AND COALESCE([EventSetKey],'')=COALESCE([dbo].[EventSetKey](@EventSet,NULL),'') 
			AND enumerate_multiple_events=@enumerate_multiple_events 
			AND COALESCE([transformskey],'')=COALESCE(dbo.TransformsKey(@transforms),'')
			AND ByCase=@ByCase
			AND m.MetricID=mt.MetricID
			AND COALESCE(m.CaseFilterProperties,'')=COALESCE(@CaseFilterProperties,'')
			AND COALESCE(m.EventFilterProperties,'')=COALESCE(@EventFilterProperties,'')
			AND m.ModelType=@ModelType 
			AND m.CreatedBy_AccessBitmap =@CreatedBy_AccessBitmap 


		)
	RETURN @result

END
GO
/****** Object:  UserDefinedFunction [dbo].[ModelsByParameters]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "ModelsByParameters",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-16",
  "Description": "Selects Markov models whose parameters (event set, time window, transforms, grouping, metric, filter properties, and model type) match the inputs, returning their keys and metadata.",
  "Utilization": "Find models by its parameters, including properties. Differs from vwModels, which just reads the Models table, but enables the user to filter in a custom manner.
  "Input Parameters": [
    { "name": "@EventSet",                "type": "NVARCHAR(MAX)", "default": "NULL", "description": "CSV list of events or code for dbo.ParseCSV to define the model event set." },
    { "name": "@enumerate_multiple_events","type": "INT",           "default": "NULL", "description": "Flag (0/1) controlling enumeration of repeated events within a case." },
    { "name": "@StartDateTime",           "type": "DATETIME",      "default": "NULL", "description": "Inclusive lower bound of event timestamps for model selection." },
    { "name": "@EndDateTime",             "type": "DATETIME",      "default": "NULL", "description": "Inclusive upper bound of event timestamps for model selection." },
    { "name": "@transforms",              "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON or code mapping of event rename transformations." },
    { "name": "@ByCase",                  "type": "BIT",           "default": "NULL", "description": "1 to partition by CaseID; 0 to treat all events as a single sequence." },
    { "name": "@Metric",                  "type": "NVARCHAR(20)",  "default": "NULL", "description": "Optional metric name; NULL returns models for all metrics." },
    { "name": "@CaseFilterProperties",    "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON filters applied to Case-level properties." },
    { "name": "@EventFilterProperties",   "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON filters applied to Event-level properties." },
    { "name": "@ModelType",               "type": "NVARCHAR(50)",  "default": "NULL", "description": "Type/category of the model (e.g., 'MarkovChain', 'BayesianProbability')." },
    { "name": "@ExactCasePropertiesMatch","type": "BIT",           "default": "NULL", "description": "1 to require exact match on case properties count; 0 to allow subset match." }
  ],
  "Output Notes": [
    { "name": "ModelID",                  "type": "INT",           "description": "Identifier of the matching model." },
    { "name": "ModelType",                "type": "NVARCHAR(50)",  "description": "Category/type of the model." },
    { "name": "EventSet",                 "type": "NVARCHAR(MAX)", "description": "Original CSV event set string." },
    { "name": "EventSetKey",              "type": "VARBINARY(16)", "description": "Hash key representing the event set." },
    { "name": "StartDateTime",            "type": "DATETIME",      "description": "Model’s effective start date." },
    { "name": "EndDateTime",              "type": "DATETIME",      "description": "Model’s effective end date." },
    { "name": "transformskey",            "type": "VARBINARY(16)", "description": "Hash key representing the transforms mapping." },
    { "name": "transforms",               "type": "NVARCHAR(MAX)", "description": "Original JSON/code transforms string." },
    { "name": "ByCase",                   "type": "BIT",           "description": "Partitioning flag used when building the model." },
    { "name": "enumerate_multiple_events","type": "INT",           "description": "Enumeration flag used when building the model." },
    { "name": "Metric",                   "type": "NVARCHAR(20)",  "description": "Metric name used by the model." },
    { "name": "CaseFilterProperties",     "type": "NVARCHAR(MAX)", "description": "JSON of case-level filters applied when building the model." },
    { "name": "EventFilterProperties",    "type": "NVARCHAR(MAX)", "description": "JSON of event-level filters applied when building the model." },
    { "name": "AccessBitmap",             "type": "BIGINT",        "description": "Bitmap of user access permissions required to view the model." }
  ],
  "Referenced objects": [
    { "name": "dbo.Models",               "type": "Table",                  "description": "Stores model definitions and metadata." },
    { "name": "dbo.Metrics",              "type": "Table",                  "description": "Lookup of metric names and methods." },
    { "name": "dbo.Transforms",           "type": "Table",                  "description": "Stores event transformation mappings." },
    { "name": "dbo.EventSets",            "type": "Table",                  "description": "Stores predefined event-set definitions." },
    { "name": "dbo.ParseCSV",             "type": "Table-Valued Function",  "description": "Splits a CSV string into table rows." },
    { "name": "dbo.ModelsByParameters",   "type": "Table-Valued Function",  "description": "This function: filters models by given parameters." },
    { "name": "dbo.ModelProperties",      "type": "Table",                  "description": "Stores case- and event-level custom properties for models." },
    { "name": "dbo.TransformsKey",        "type": "Scalar Function",        "description": "Generates a hash key for a transforms JSON." },
    { "name": "dbo.UserAccessBitmap",     "type": "Scalar Function",        "description": "Retrieves the current user’s access bitmap." },
    { "name": "dbo.SetDefaultModelParameters","type": "Table-Valued Function","description": "Provides default date and parameter values." }
  ]
}

Sample utilization:

    SELECT *
      FROM dbo.ModelsByParameters(
        'restaurantguest', 0,
        NULL,NULL,
        NULL, 1, NULL,
        '{"EmployeeID":1,"LocationID":1}',
        NULL, NULL, 0,
		dbo.UserAccessBitmap()
      )
	  
    SELECT *
      FROM dbo.ModelsByParameters(
        'websitepages', 0,
        NULL,NULL,
        NULL, 1, NULL,
        NULL,
        NULL, NULL, 0,
		NULL
      )

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

Notes:
    • @Metric should not default to 'Time Between'. "NULL" means we want all metrics.
*/

CREATE FUNCTION [dbo].[ModelsByParameters]
(
	@EventSet NVARCHAR(MAX),
	@enumerate_multiple_events INT,
	@StartDateTime DATETIME,
	@EndDateTime DATETIME,
	@transforms NVARCHAR(MAX),
	@ByCase BIT, -- 1 should be the Default. If 0, consider everything to be one case.
	@Metric NVARCHAR(20) NULL, --If null, that means all models otherwise the same, but with different metric.
	@CaseFilterProperties NVARCHAR(MAX),
	@EventFilterProperties NVARCHAR(MAX),
	@ModelType NVARCHAR(50),
	@ExactCasePropertiesMatch BIT,
	@CreatedBy_AccessBitmap BIGINT	--NULL means don't filter by this. It just returns the model, but doesn't return events.
)
RETURNS 

@result TABLE (
	ModelID INT,
	ModelType NVARCHAR(50),
	[EventSet] NVARCHAR(MAX),
	[EventSetKey] VARBINARY(16),
	[StartDateTime] DATETIME,
	[EndDateTime] DATETIME,
	transformskey VARBINARY(16),
	transforms NVARCHAR(MAX),
	ByCase BIT,
	[enumerate_multiple_events] INT,
	Metric NVARCHAR(20),
	CaseFilterProperties NVARCHAR(MAX),
	EventFilterProperties NVARCHAR(MAX),
	CreatedBy_AccessBitmap BIGINT

)
AS
BEGIN
	--SET @Metric=COALESCE(@Metric,'Time Between')
	SET @ByCase=COALESCE(@ByCase,1)
	--If CreatedBy_AccessBitmap IS NULL, that means don't filter by it.
	--SET @CreatedBy_AccessBitmap=COALESCE(@CreatedBy_AccessBitmap,dbo.UserAccessBitmap())
	SET @ModelType=COALESCE(@ModelType,'MarkovChain')

	DECLARE @UserAccessBitmap BigiNT

	SELECT
		@StartDateTime=StartDateTime,
		@EndDateTime=EndDateTime,
		@Metric=Metric,
		@UserAccessBitmap=AccessBitmap	--What the user will see.
     FROM dbo.SetDefaultModelParameters(
             @StartDateTime,    -- @StartDateTime
             @EndDateTime,    -- @EndDateTime
             NULL,    -- @Order
             NULL,    -- @enumerate_multiple_events
             @Metric     -- @metric
		)

	SET @ExactCasePropertiesMatch=COALESCE(@ExactCasePropertiesMatch,0)

	DECLARE @include_parsed TABLE ([value] NVARCHAR(50))
	IF @EventSet IS NOT NULL
	BEGIN
		INSERT INTO @include_parsed SELECT [value] FROM dbo.ParseCSV(@EventSet,',')
	END

	DECLARE @Properties TABLE (property NVARCHAR(50), [numeric] FLOAT,[alpha] NVARCHAR(1000),[rank] INT)
	IF @CaseFilterProperties IS NOT NULL
	BEGIN
		INSERT INTO @Properties
			SELECT 
				[key],
				CASE WHEN ISNUMERIC([value])=1 THEN CAST([value] AS FLOAT) ELSE NULL END AS [numeric],
				CASE WHEN ISNUMERIC([value])=0 THEN [value] ELSE NULL END AS [alpha],
				ROW_NUMBER() OVER(ORDER BY [key]) [rank] 
			FROM OPENJSON(@CaseFilterProperties)
	END
	DECLARE @MaxProps INT=(SELECT COUNT(*) FROM @Properties)

	DECLARE @EventProperties TABLE (property NVARCHAR(50), [numeric] FLOAT,[alpha] NVARCHAR(1000),[rank] INT)
	IF @EventFilterProperties IS NOT NULL
	BEGIN
		INSERT INTO @EventProperties
			SELECT 
				[key],
				CASE WHEN ISNUMERIC([value])=1 THEN CAST([value] AS FLOAT) ELSE NULL END AS [numeric],
				CASE WHEN ISNUMERIC([value])=0 THEN [value] ELSE NULL END AS [alpha],
				ROW_NUMBER() OVER(ORDER BY [key]) [rank] 
			FROM OPENJSON(@EventFilterProperties)
	END
	DECLARE @EventMaxProps INT=(SELECT COUNT(*) FROM @EventProperties)

	INSERT INTO @result
		SELECT
			m.modelid,
			m.ModelType,
			e.EventSet,
			m.EventSetKey,
			m.StartDateTime,
			m.EndDateTime,
			m.transformskey,
			t.transforms,
			m.ByCase,
			m.enumerate_multiple_events,
			mt.Metric,
			m.CaseFilterProperties,
			m.EventFilterProperties,
			m.CreatedBy_AccessBitmap
		FROM
			[dbo].[Models] m (NOLOCK)
			LEFT JOIN [dbo].[Metrics] mt (NOLOCK) ON mt.MetricID=m.MetricID
			LEFT JOIN [dbo].[Transforms] t (NOLOCK) ON m.transformskey=t.transformskey
			LEFT JOIN [dbo].[EventSets] e (NOLOCK) ON e.EventSetKey=m.EventSetKey
		WHERE 
			(m.AccessBitmap = - 1 OR @UserAccessBitmap & m.AccessBitmap <> 0)
			AND (@StartDateTime IS NULL OR (m.StartDateTime>=@StartDateTime AND m.EndDateTime<=@EndDateTime))
			AND (@CreatedBy_AccessBitmap IS NULL OR  m.CreatedBy_AccessBitmap=@CreatedBy_AccessBitmap)
			AND (@EventSet IS NULL OR COALESCE(m.[EventSetKey],'')=COALESCE([dbo].[EventSetKey](@EventSet,NULL),'') )
			AND m.enumerate_multiple_events=@enumerate_multiple_events 
			AND (@transforms is NULL OR COALESCE(m.[transformskey],'')=COALESCE(dbo.TransformsKey(@transforms),''))
			AND m.ByCase=@ByCase
			AND (@EventSet IS NULL OR (SELECT COUNT(*) FROM dbo.ParseCSV(e.[EventSet],',') t1 JOIN @include_parsed t2 ON t1.[value]=t2.[value])>0)
			AND (@Metric IS NULL OR mt.Metric=@Metric)
			AND (
				SELECT COUNT(*) 
				FROM [dbo].[ModelProperties] mp  (NOLOCK)
				JOIN @Properties p ON mp.PropertyName=p.property AND 
					(
						(mp.PropertyValueNumeric IS NOT NULL AND mp.PropertyValueNumeric=p.[numeric]) OR
						(mp.PropertyValueAlpha IS NOT NULL AND mp.PropertyValueAlpha=p.[alpha])
					)
				WHERE mp.CaseLevel=1 AND mp.ModelID=m.ModelID
			)=@MaxProps
			AND 
			(
				--In case the model case properties must be an exact match.
				@ExactCasePropertiesMatch=0 OR 
				(SELECT COUNT(*) FROM [dbo].[ModelProperties] mp (NOLOCK) WHERE mp.CaseLevel=1 AND mp.ModelID=m.ModelID)=@MaxProps
			)
			AND (
				SELECT COUNT(*) 
				FROM [dbo].[ModelProperties] mp (NOLOCK)
				JOIN @EventProperties p ON mp.PropertyName=p.property AND 
					(
						(mp.PropertyValueNumeric IS NOT NULL AND mp.PropertyValueNumeric=p.[numeric]) OR
						(mp.PropertyValueAlpha IS NOT NULL AND mp.PropertyValueAlpha=p.[alpha])
					)
				WHERE mp.CaseLevel=0 AND mp.ModelID=m.ModelID
			)=@EventMaxProps
			AND (@ModelType IS NULL OR m.ModelType=@ModelType)
	RETURN 
END
GO
/****** Object:  UserDefinedFunction [dbo].[ModelSimilaritySegments]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Table-Valued Function": "dbo.ModelSimilaritySegments",
  "Author": "OpenAI draft based on current TimeSolution objects",
  "Contact": "n/a",
  "Description": "Returns a segment-by-segment comparison between two existing Markov models by aligning EventA→EventB segments from dbo.ModelEvents. For each segment appearing in either model, the function reports probabilities, averages, row counts, presence flags, differences, and a t-test-like value when both models contain the same segment with nonzero variance.",
  "Utilization": "Use when you already have two ModelID values and want to see exactly which segments are shared, unique, or materially different. Helpful after dbo.InsertModelSimilarities, or as a detailed complement to summary scores such as PercentSameSegments and CosineSimilarity.",
  "Input Parameters": [
    { "name": "@ModelID1", "type": "INT", "default": "NULL", "description": "Identifier of the first existing model to compare." },
    { "name": "@ModelID2", "type": "INT", "default": "NULL", "description": "Identifier of the second existing model to compare." }
  ],
  "Output Notes": [
    { "name": "EventA", "type": "NVARCHAR(50)", "description": "Source event of the segment." },
    { "name": "EventB", "type": "NVARCHAR(50)", "description": "Target event of the segment." },
    { "name": "Model1Prob", "type": "FLOAT", "description": "Probability of the segment in model 1, if present." },
    { "name": "Model2Prob", "type": "FLOAT", "description": "Probability of the segment in model 2, if present." },
    { "name": "ProbDiff", "type": "FLOAT", "description": "Model1Prob - Model2Prob when both exist, otherwise NULL." },
    { "name": "AbsProbDiff", "type": "FLOAT", "description": "Absolute probability difference when both exist, otherwise NULL." },
    { "name": "Model1Avg", "type": "FLOAT", "description": "Average metric value for the segment in model 1, if present." },
    { "name": "Model2Avg", "type": "FLOAT", "description": "Average metric value for the segment in model 2, if present." },
    { "name": "AvgDiff", "type": "FLOAT", "description": "Model1Avg - Model2Avg when both exist, otherwise NULL." },
    { "name": "Model1Rows", "type": "INT", "description": "Row count supporting the segment in model 1, if present." },
    { "name": "Model2Rows", "type": "INT", "description": "Row count supporting the segment in model 2, if present." },
    { "name": "PresentInModel1", "type": "BIT", "description": "1 if the segment exists in model 1." },
    { "name": "PresentInModel2", "type": "BIT", "description": "1 if the segment exists in model 2." },
    { "name": "SegmentStatus", "type": "NVARCHAR(20)", "description": "SameSegment, OnlyInModel1, or OnlyInModel2." },
    { "name": "Segment_ttest", "type": "FLOAT", "description": "A t-test-like value based on averages, variances, and row counts when both segments exist and both variances are greater than zero." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelEvents", "type": "Table", "description": "Stores per-model EventA→EventB segments with Avg, StDev, Rows, and Prob." }
  ]
}

Sample utilization:

    SELECT *
    FROM dbo.ModelSimilaritySegments(6,7)
    ORDER BY AbsProbDiff DESC, EventA, EventB;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is not production-hardened: error handling, security, concurrency, indexing, query plan tuning, and partitioning have been omitted or simplified.
    • Intended to complement dbo.InsertModelSimilarities by exposing a stable rowset for segment-level review.
*/

CREATE FUNCTION [dbo].[ModelSimilaritySegments]
(
    @ModelID1 INT,
    @ModelID2 INT
)
RETURNS @result TABLE
(
    EventA NVARCHAR(50),
    EventB NVARCHAR(50),

    Model1Prob FLOAT NULL,
    Model2Prob FLOAT NULL,
    ProbDiff FLOAT NULL,
    AbsProbDiff FLOAT NULL,

    Model1Avg FLOAT NULL,
    Model2Avg FLOAT NULL,
    AvgDiff FLOAT NULL,

    Model1Rows INT NULL,
    Model2Rows INT NULL,

    PresentInModel1 BIT NOT NULL,
    PresentInModel2 BIT NOT NULL,

    SegmentStatus NVARCHAR(20) NOT NULL,
    Segment_ttest FLOAT NULL
)
AS
BEGIN
    DECLARE @A INT = CASE WHEN @ModelID1 <= @ModelID2 THEN @ModelID1 ELSE @ModelID2 END;
    DECLARE @B INT = CASE WHEN @ModelID1 <= @ModelID2 THEN @ModelID2 ELSE @ModelID1 END;

    ;WITH
    m1 AS
    (
        SELECT
            EventA,
            EventB,
            CAST([Avg] AS FLOAT) AS AvgValue,
            CAST(POWER([StDev], 2) AS FLOAT) AS VarValue,
            CAST([Rows] AS INT) AS [RowCount],
            CAST([Prob] AS FLOAT) AS ProbValue
        FROM dbo.ModelEvents WITH (NOLOCK)
        WHERE ModelID = @A
    ),
    m2 AS
    (
        SELECT
            EventA,
            EventB,
            CAST([Avg] AS FLOAT) AS AvgValue,
            CAST(POWER([StDev], 2) AS FLOAT) AS VarValue,
            CAST([Rows] AS INT) AS [RowCount],
            CAST([Prob] AS FLOAT) AS ProbValue
        FROM dbo.ModelEvents WITH (NOLOCK)
        WHERE ModelID = @B
    )
    INSERT INTO @result
    SELECT
        COALESCE(m1.EventA, m2.EventA) AS EventA,
        COALESCE(m1.EventB, m2.EventB) AS EventB,

        m1.ProbValue AS Model1Prob,
        m2.ProbValue AS Model2Prob,
        CASE
            WHEN m1.EventA IS NOT NULL AND m2.EventA IS NOT NULL
                THEN m1.ProbValue - m2.ProbValue
            ELSE NULL
        END AS ProbDiff,
        CASE
            WHEN m1.EventA IS NOT NULL AND m2.EventA IS NOT NULL
                THEN ABS(m1.ProbValue - m2.ProbValue)
            ELSE NULL
        END AS AbsProbDiff,

        m1.AvgValue AS Model1Avg,
        m2.AvgValue AS Model2Avg,
        CASE
            WHEN m1.EventA IS NOT NULL AND m2.EventA IS NOT NULL
                THEN m1.AvgValue - m2.AvgValue
            ELSE NULL
        END AS AvgDiff,

        m1.[RowCount] AS Model1Rows,
        m2.[RowCount] AS Model2Rows,

        CASE WHEN m1.EventA IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS PresentInModel1,
        CASE WHEN m2.EventA IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS PresentInModel2,

        CASE
            WHEN m1.EventA IS NOT NULL AND m2.EventA IS NOT NULL THEN 'SameSegment'
            WHEN m1.EventA IS NOT NULL THEN 'OnlyInModel1'
            ELSE 'OnlyInModel2'
        END AS SegmentStatus,

        CASE
            WHEN m1.EventA IS NOT NULL
             AND m2.EventA IS NOT NULL
             AND COALESCE(m1.VarValue, 0) > 0
             AND COALESCE(m2.VarValue, 0) > 0
             AND COALESCE(m1.[RowCount], 0) > 0
             AND COALESCE(m2.[RowCount], 0) > 0
             AND SQRT((m1.VarValue / m1.[RowCount]) + (m2.VarValue / m2.[RowCount])) <> 0
                THEN (m1.AvgValue - m2.AvgValue)
                     / SQRT((m1.VarValue / m1.[RowCount]) + (m2.VarValue / m2.[RowCount]))
            ELSE NULL
        END AS Segment_ttest
    FROM m1
    FULL OUTER JOIN m2
        ON m1.EventA = m2.EventA
       AND m1.EventB = m2.EventB;

    RETURN;
END
GO
/****** Object:  UserDefinedFunction [dbo].[PromptEventSimilarity]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "[Stored Procedure, Table-Valued Function, etc. whichever you think]": "PromptEventSimilarity",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-14",
  "Description": "Constructs a natural‐language prompt for an LLM to score or explain the semantic similarity between two event names, optionally including contextual co‐occurring words.",
  "Utilization": "Use when generating text prompts or similarity text around events for LLM, embedding, or semantic search scenarios.",
  "Input Parameters": [
    { "name": "@Event1",               "type": "NVARCHAR(20)", "default": null, "description": "First event name to compare." },
    { "name": "@Event2",               "type": "NVARCHAR(20)", "default": null, "description": "Second event name to compare against." },
    { "name": "@ScoreOnly",            "type": "BIT",           "default": "NULL", "description": "1 to request only the numeric score; 0 to allow an explanatory response." },
    { "name": "@CompareEvents",        "type": "BIT",           "default": "NULL", "description": "1 to include event comparison; reserved for future use." },
    { "name": "@CompareEventProperties","type": "BIT",          "default": "NULL", "description": "1 to include event‐property comparison; reserved for future use." },
    { "name": "@ContextWordCount",     "type": "TINYINT",       "default": "NULL", "description": "Number of top co‐occurring words to include as context for each event." }
  ],
  "Output Notes": [
    { "name": "Return Value", "type": "NVARCHAR(500)", "description": "Generated LLM prompt string, possibly including contextual word lists." }
  ],
  "Referenced objects": [
    { "name": "dbo.EventsFact", "type": "Table", "description": "Source of event occurrences used to build context word lists." }
  ]
}

Sample utilization:

--The events are named Event1 and Event2 instead of EventA and EventB because the latter is in the context of P(B|A).
SELECT [dbo].[PromptEventSimilarity]('raises','heavytraffic',1,NULL,NULL,NULL)

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

Notes:
    The events are named Event1 and Event2 instead of EventA and EventB because the latter is in the context of P(B|A).
    Co-occurring context words are drawn from EventsFact by frequency, with a minimum occurrence threshold of 2.

	See MDMComparisonTypes.MDMComparisonTypeID=3. This UDF is a good example of such a prompt.
*/


CREATE FUNCTION [dbo].[PromptEventSimilarity]
(
@Event1 NVARCHAR(50), -- One of the Events we're comparing.
@Event2 NVARCHAR(50), -- The Event we're comparing Event1 to.
@ScoreOnly BIT,	-- Set to 1 if we're asking the LLM for just the answer to use at Thinking Time. 0 will allow for an explanation.
@CompareEvents BIT,
@CompareEventProperties BIT,
@ContextWordCount TINYINT --The number of words to offer as context for each event. 
)
RETURNS NVARCHAR(500)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @ResultVar NVARCHAR(500)='On a scale of -1.0 to 1.0, -1.0 being perfect antonyms and 1.0 being the perfect synonyms, how similar in semantics is “'+@Event1+'” (which often occurs with {context1}) versus the word “'+@Event2+'” (which often occurrs with the words {context2})?'
	
	--Set default values.
	SET @ScoreOnly=COALESCE(@ScoreOnly,1)
	SET @CompareEvents=COALESCE(@CompareEvents,1)
	SET @CompareEventProperties=COALESCE(@CompareEventProperties,0)
	SET @ContextWordCount=COALESCE(@ContextWordCount,10)
	DECLARE @MinimumCount INT=2

	IF @ScoreOnly=1 
	BEGIN
		SET @ResultVar +=' Return just the score with no explanation at all.'
	END
	ELSE
	BEGIN
		 SET @ResultVar = 'In 150 words or less, '+@ResultVar
	END

	DECLARE @wordlist NVARCHAR(200)=
		(
			SELECT
				STRING_AGG([Event],', ')
			FROM
				(
					SELECT
						[Event],
						RANK() OVER (ORDER BY Occurrences) AS [Rank]
					FROM
						 (
							SELECT 
								e.[Event],
								COUNT(*) AS [Occurrences]
							FROM
								[dbo].[EventsFact] e
							WHERE
								EXISTS (SELECT e1.EventID FROM [dbo].[EventsFact] e1 WHERE e1.CaseID=e.CaseID AND e1.[Event]=@Event1)
								AND e.[Event] != @Event1
							GROUP BY
								e.[Event]
							HAVING
								COUNT(*)>=@MinimumCount
						) e
				) e
			WHERE
				[Rank]<=@ContextWordCount
		)
	SET @ResultVar = REPLACE(@ResultVar,'{context1}',@wordlist)

	SET @wordlist=
		(
			SELECT
				STRING_AGG([Event],', ')
			FROM
				(
					SELECT
						[Event],
						RANK() OVER (ORDER BY Occurrences) AS [Rank]
					FROM
						 (
							SELECT 
								e.[Event],
								COUNT(*) AS [Occurrences]
							FROM
								[dbo].[EventsFact] e
							WHERE
								EXISTS (SELECT e1.EventID FROM [dbo].[EventsFact] e1 WHERE e1.CaseID=e.CaseID AND e1.[Event]=@Event2)
								AND e.[Event] != @Event2
							GROUP BY
								e.[Event]
							HAVING
								COUNT(*) >= @MinimumCount
						) e
				) e
			WHERE
				[Rank]<=@ContextWordCount
		)
	SET @ResultVar = REPLACE(@ResultVar,'{context2}',@wordlist)

	RETURN @ResultVar

END
GO
/****** Object:  UserDefinedFunction [dbo].[PropertySource]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "PropertySource",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-14",
  "Description": "Translates a numeric PropertySourceKey into its corresponding property category name for use in property metadata.",
  "Utilization": "Use when you need to standardize or decode where a property came from, such as distinguishing raw source-derived properties from transformed or derived ones.",
  "Input Parameters": [
    { "name": "@PropertySourceKey", "type": "TINYINT", "default": null, "description": "0 = InputProperties, 1 = OutputProperties, 2 = AggregationProperties." }
  ],
  "Output Notes": [
    { "name": "Return Value", "type": "NVARCHAR(30)", "description": "The matching property source name, or NULL if the key is unrecognized." }
  ],
  "Referenced objects": []
}

Sample utilization:

  SELECT dbo.PropertySource(2);  -- returns 'AggregationProperties'

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE FUNCTION [dbo].[PropertySource]
(
@PropertySourceKey TINYINT --0 = InputProperties, 1=OutputProperties, 2=AggregationProperties
)
RETURNS NVARCHAR(30)
AS
BEGIN

	RETURN CASE
		WHEN @PropertySourceKey=0 THEN 'InputProperties'
		WHEN @PropertySourceKey=1 THEN 'OutputProperties'
		WHEN @PropertySourceKey=2 THEN 'AggregationProperties'
		ELSE NULL
		END

END
GO
/****** Object:  UserDefinedFunction [dbo].[SelectedEvents]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
*** THIS TVF is deprecated as it cannot be ported to Azure Synapse. Use the sproc, sp_SelectedEvents.***

Metadata JSON:
{
  "Table-Valued Function": "SelectedEvents",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-19",
  "Description": "Retrieves a time-ordered, ranked sequence of events filtered and transformed per user parameters, supporting event-set selection, date windowing, case and event property filters, custom transforms, metric extraction, and optional enumeration of repeated events.",
  "Input Parameters": [
    { "name": "@EventSet",               "type": "NVARCHAR(MAX)",  "default": "NULL", "description": "Comma-delimited events or code referencing dbo.ParseEventSet; required." },
    { "name": "@enumerate_multiple_events","type": "INT",           "default": "NULL", "description": "If >0, appends sequence numbers to repeated event names; otherwise duplicates remain identical." },
    { "name": "@StartDateTime",          "type": "DATETIME",      "default": "NULL", "description": "Inclusive lower bound for event dates; defaults to '1900-01-01' if NULL." },
    { "name": "@EndDateTime",            "type": "DATETIME",      "default": "NULL", "description": "Inclusive upper bound for event dates; defaults to '2050-12-31' if NULL." },
    { "name": "@transforms",             "type": "NVARCHAR(MAX)",  "default": "NULL", "description": "JSON mapping of event renames (fromKey→toKey)." },
    { "name": "@ByCase",                 "type": "BIT",           "default": "1",    "description": "1 to partition by CaseID; 0 to treat all events as a single synthetic case." },
    { "name": "@metric",                 "type": "NVARCHAR(20)",  "default": "NULL", "description": "Metric name in dbo.Metrics; defaults to 'Time Between' if NULL." },
    { "name": "@CaseFilterProperties",   "type": "NVARCHAR(MAX)",  "default": "NULL", "description": "JSON object to filter which cases to include." },
    { "name": "@EventFilterProperties",  "type": "NVARCHAR(MAX)",  "default": "NULL", "description": "JSON object to filter which events to include." }
  ],
  "Output Notes": [
    { "name": "CaseID",                 "type": "INT",           "description": "Case identifier (or –1 if @ByCase = 0)." },
    { "name": "Event",                  "type": "NVARCHAR(20)",  "description": "Event name after transform, with optional enumeration suffix." },
    { "name": "EventDate",              "type": "DATETIME2",     "description": "Timestamp of the event, including milliseconds." },
    { "name": "Rank",                   "type": "INT",           "description": "Position of the event within its case (1 = first)." },
    { "name": "EventOccurence",         "type": "INT",           "description": "Ordinal count of repeated occurrences of that event name in the case." },
    { "name": "EventID",                "type": "INT",           "description": "Surrogate key from EventsFact." },
    { "name": "MetricActualValue",      "type": "FLOAT",         "description": "Observed metric input value (if @metric ≠ 'Time Between')." },
    { "name": "MetricExpectedValue",    "type": "FLOAT",         "description": "Expected metric value (if @metric ≠ 'Time Between')." }
  ],
  "Referenced objects": [
    { "name": "dbo.ParseEventSet",          "type": "TVF",        "description": "Splits event-set codes into individual event names." },
    { "name": "dbo.ParseTransforms",        "type": "TVF",        "description": "Parses JSON transforms into fromKey→toKey mappings." },
    { "name": "dbo.UserAccessBitmap",       "type": "Scalar Function", "description": "Retrieves the current user's access bitmap for filtering." },
    { "name": "dbo.EventPropertiesParsed",  "type": "Table",      "description": "Parsed event-level properties." },
    { "name": "dbo.CasePropertiesParsed",   "type": "Table",      "description": "Parsed case-level properties." },
    { "name": "OPENJSON",                   "type": "Built-in Function", "description": "Parses JSON text into rows." }
  ]
}

Sample utilization:

-- Retrieve commute sequence for a given event set:
SELECT *
  FROM dbo.SelectedEvents(
    'leavehome,heavytraffic,moderatetraffic,lighttraffic,arrivework,returnhome',
    0, '1900-01-01','2050-12-31', NULL, 1, NULL, NULL, NULL
  )
ORDER BY CaseID, [Rank];

SELECT * FROM [dbo].[SelectedEvents]('leavehome,heavytraffic,moderatetraffic,lighttraffic,arrivework,returnhome',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL,NULL)
SELECT * FROM [dbo].[SelectedEvents](NULL,0,'01/01/1900','12/31/2050',NULL,1,NULL,'{"EmployeeID":2,"CustomerID":2}',NULL)
SELECT * FROM dbo.SelectedEvents('commute',0,'01/01/1900','12/31/2050',NULL,1,'Fuel',NULL,NULL) ORDER BY CaseID,[Rank]
SELECT * FROM dbo.SelectedEvents('pickuproute',0,'01/01/1900','12/31/2050',NULL,1,'Fuel',NULL,NULL) ORDER BY CaseID,[Rank]
SELECT * FROM dbo.SelectedEvents('pickuproute',0,'01/01/1900','12/31/2050',NULL,1,'Fuel',NULL,NULL) ORDER BY CaseID,[Rank]

SELECT * FROM dbo.SelectedEvents('poker',0,'01/01/2000','01/04/2050',NULL,1,NULL,NULL,NULL)
SELECT * FROM dbo.SelectedEvents('NEW_GAME,collected,GameState-0,GameState-1,GameState-2,GameState-3,GameState-4,calls,bets,raises,folds,checks',0,'01/01/2000','01/04/2050',NULL,1,NULL,NULL,NULL)
SELECT * FROM dbo.SelectedEvents('NEW_GAME,collected,GameState-0,GameState-1,GameState-2,GameState-3,GameState-4,calls,bets,raises,folds,checks',0,'01/01/2000','01/04/2050',NULL,1,'current_leader_chips',NULL)
SELECT * FROM dbo.SelectedEvents('NEW_GAME,collected,GameState-0,GameState-1,GameState-2,GameState-3,GameState-4,calls,bets,raises,folds,checks',0,'01/01/2000','01/04/2050',NULL,1,'current_leader_chips','{"TournamentNumber":206815194}',NULL)
SELECT * FROM dbo.SelectedEvents('NEW_GAME,collected,GameState-0,GameState-1,GameState-2,GameState-3,GameState-4,calls,bets,raises,folds,checks',0,'01/01/2000','01/04/2050',NULL,1,'current_leader_chips','{"TournamentNumber":206815194}','{"Player":"RaminWho"}')

SELECT * FROM dbo.SelectedEvents('TIA',0,NULL,NULL,NULL,1,'Fuel','{"age":"Elderly"}',NULL) ORDER BY CaseID,[Rank]
SELECT * FROM dbo.SelectedEvents('TIA',0,NULL,NULL,NULL,1,'Fuel','{"age":"Young","Diabetic":"No"}',NULL) ORDER BY CaseID,[Rank]

SELECT * FROM dbo.SelectedEvents('restaurantguest',0,'01/01/1900','12/31/2050',NULL,1,NULL,NULL,NULL) ORDER BY CaseID,[Rank]


Notes:
    • @EventSet is mandatory; function returns nothing if NULL.
    • @Metric defaults to 'Time Between' when omitted.

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, concurrency, indexing, query-plan tuning, and partitioning have been simplified or omitted.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/







CREATE FUNCTION [dbo].[SelectedEvents]
(
	@EventSet NVARCHAR(MAX), --An Event Set MUST be specified. This is the primary key.
	@enumerate_multiple_events INT,
	@StartDateTime DATETIME,
	@EndDateTime DATETIME,
	@transforms NVARCHAR(MAX),
	@ByCase BIT=1, -- 1 should be the Default. If 0, consider everything to be one case.
	@metric NVARCHAR(20), -- Metric are Event-Level properties (EventPropertiesParsed).
	@CaseFilterProperties NVARCHAR(MAX),
	@EventFilterProperties NVARCHAR(MAX)
)
RETURNS 

@result TABLE (
	CaseID INT,
	[Event] NVARCHAR(50),
	[EventDate] DATETIME2, -- Need this for miliseconds
	[Rank] INT,
	EventOccurence INT,
	EventID INT,
	MetricActualValue FLOAT, -- Only used if metric is other than Time Between.
	MetricExpectedValue FLOAT,
	UNIQUE (CaseID,[Rank])

)
AS
BEGIN

	DECLARE @DefaultMetric NVARCHAR(20)='Time Between'
	SET @ByCase=COALESCE(@ByCase,1) --1 is default.
	SET @metric=COALESCE(@metric,@DefaultMetric) -- Default metric.
	DECLARE @IsSequence BIT=0
	SET @StartDateTime=COALESCE(@StartDateTime,'01/01/1900')
	SET @EndDateTime=COALESCE(@EndDateTime,'12/31/2050')

	DECLARE @ex TABLE ([event] NVARCHAR(50))
	IF @EventSet IS NOT NULL -- @EventSet=0 means essentially means all events.
	BEGIN
		INSERT INTO @ex([event])
			SELECT DISTINCT [event] FROM dbo.ParseEventSet(@EventSet, @IsSequence)  --@EventSet could reference a code (IncludedEvents.Code). IsSequence=0, it's a set.
	END
	ELSE
	BEGIN
		RETURN --Error
	END

	DECLARE @trans TABLE (fromKey NVARCHAR(20),tokey NVARCHAR(20), UNIQUE (fromkey))
	IF @transforms IS NOT NULL
	BEGIN
		INSERT INTO @trans
			SELECT [fromkey],[tokey] FROM dbo.ParseTransforms(@transforms)
	END

	DECLARE @Properties TABLE (property NVARCHAR(50), property_numeric FLOAT,property_alpha NVARCHAR(1000),[rank] INT, UNIQUE (property,[rank]))
	IF @CaseFilterProperties IS NOT NULL
	BEGIN
		INSERT INTO @Properties
		SELECT 
			[key],
			CASE WHEN ISNUMERIC([value])=1 THEN CAST([value] AS FLOAT) ELSE NULL END,
			CASE WHEN ISNUMERIC([value])=0 THEN [value] ELSE NULL END,
			ROW_NUMBER() OVER(ORDER BY [key]) [rank]
		FROM 
			OPENJSON(@CaseFilterProperties)
	END
	DECLARE @MaxProps INT=(SELECT COUNT(*) FROM @Properties)

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

	--The underlying dbo.Users table should be denied any direct access. 
	--But access to the scalar function, dbo.UserAccessBitmap can call dbo.Users table.
	DECLARE @AccessBitmap BIGINT=dbo.UserAccessBitmap()

	IF @CaseFilterProperties IS NULL
	BEGIN
		INSERT INTO @result
			SELECT 
				e.CaseID, 
				e.[Event], 
				e.EventDate, 
				RANK() OVER (PARTITION BY e.CaseID ORDER BY e.EventDate) AS [Rank], 
				RANK() OVER (PARTITION BY e.CaseID, e.[Event] ORDER BY e.EventDate) AS [EventOccurence],--Event that occurs multiple times in a case.
				e.EventID,
				e.MetricInputValue AS MetricInputValue,
				e.MetricOutputValue AS MetricOutputValue
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
						JOIN @ex x ON x.[event]=e.[Event]
						JOIN [dbo].[Cases] (NOLOCK) c ON c.CaseID=e.CaseID 
						LEFT JOIN @trans tr ON tr.fromKey=e.[Event]
						LEFT JOIN [dbo].[EventPropertiesParsed] [pi] (NOLOCK) ON @metric<>@DefaultMetric AND [pi].EventID=e.EventID AND [pi].PropertySource=0 AND [pi].PropertyName=@metric
						LEFT JOIN [dbo].[EventPropertiesParsed] [po] (NOLOCK) ON @metric<>@DefaultMetric AND [po].EventID=e.EventID AND [po].PropertySource=1 AND [po].PropertyName=@metric
					WHERE 
						e.EventDate BETWEEN @StartDateTime AND @EndDateTime
						AND (@EventFilterProperties IS NULL OR (
							--Check the CASE properties.
							SELECT 
								COUNT(*) 
							FROM 
								[dbo].[EventPropertiesParsed] ep (NOLOCK)
								JOIN @EventProperties p ON 
									ep.PropertyName=p.property 
									AND ep.[PropertySource]=0
									AND (
										p.[property_numeric]  IS NOT NULL AND ep.PropertyValueNumeric=p.[property_numeric]
										OR p.[property_alpha]  IS NOT NULL AND ep.PropertyValueAlpha=p.property_alpha
									)
							WHERE 
								ep.EventID=e.EventID)=@EventMaxProps
							)
						AND (@AccessBitmap & c.AccessBitmap)=c.AccessBitmap
				) e
	END
	ELSE
	BEGIN
		INSERT INTO @result
			SELECT 
				e.CaseID, 
				e.[Event], 
				e.EventDate, 
				RANK() OVER (PARTITION BY e.CaseID ORDER BY e.EventDate) AS [Rank], 
				RANK() OVER (PARTITION BY e.CaseID, e.[Event] ORDER BY e.EventDate) AS [EventOccurence],--Event that occurs multiple times in a case.
				e.EventID,
				e.MetricInputValue AS MetricInputValue,
				e.MetricOutputValue AS MetricOutputValue
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
						JOIN @ex x ON x.[event]=e.[Event]
						JOIN (
							SELECT cp.CaseID, COUNT(*) AS MatchedProps
							FROM [dbo].[CasePropertiesParsed] cp (NOLOCK)
							JOIN @Properties p 
								ON cp.PropertyName = p.property
								AND (
									p.[property_numeric] IS NOT NULL AND cp.PropertyValueNumeric = p.[property_numeric]
									OR p.[property_alpha] IS NOT NULL AND cp.PropertyValueAlpha = p.[property_alpha]
								)
							GROUP BY cp.CaseID
						) FilteredCases
						ON (FilteredCases.CaseID = e.CaseID AND FilteredCases.MatchedProps = @MaxProps) 
						LEFT JOIN @trans tr ON tr.fromKey=e.[Event]
						LEFT JOIN [dbo].[EventPropertiesParsed] [pi] ON @metric<>@DefaultMetric AND [pi].EventID=e.EventID AND [pi].PropertySource=0 AND [pi].PropertyName=@metric
						LEFT JOIN [dbo].[EventPropertiesParsed] [po] ON @metric<>@DefaultMetric AND [po].EventID=e.EventID AND [po].PropertySource=1 AND [po].PropertyName=@metric
					WHERE 
						e.EventDate BETWEEN @StartDateTime AND @EndDateTime

						AND (@EventFilterProperties IS NULL OR (
							--Check the CASE properties.
							SELECT 
								COUNT(*) 
							FROM 
								[dbo].[EventPropertiesParsed] ep (NOLOCK)
								JOIN @EventProperties p ON 
									ep.PropertyName=p.property 
									AND ep.[PropertySource]=0
									AND (
										p.[property_numeric]  IS NOT NULL AND ep.PropertyValueNumeric=p.[property_numeric]
										OR p.[property_alpha]  IS NOT NULL AND ep.PropertyValueAlpha=p.property_alpha
									)
							WHERE 
								ep.EventID=e.EventID)=@EventMaxProps
							)
						AND (@AccessBitmap & c.AccessBitmap)=c.AccessBitmap

				) e
	END
			
	IF @enumerate_multiple_events>0
	BEGIN
		UPDATE @result
		SET
			[Event]=r.Event+CAST(CASE WHEN r.EventOccurence<=@enumerate_multiple_events THEN r.EventOccurence ELSE @enumerate_multiple_events END AS NVARCHAR(5))
		FROM
			@result r
		WHERE
			r.EventOccurence>1 -- Set event to event1, event2, event3, etc if the event occurs more than once in a case.
	END

	RETURN 
	
END

--SELECT *,ROW_NUMBER() OVER(ORDER BY [key]) [Rank] FROM OPENJSON('{"EmployeeID":1}')
GO
/****** Object:  UserDefinedFunction [dbo].[SequenceKey]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "SequenceKey",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-14",
  "Description": "Generates a 16-byte MD5 hash key for a given event sequence string and next-event value, providing a unique identifier for event‐transition sequences.",
  "Utilization": "Use when you need a stable key for an event sequence so it can be cached, compared, joined, or stored independently of the raw comma-separated text.",
  "Input Parameters": [
    { "name": "@Seq",       "type": "NVARCHAR(MAX)", "default": null, "description": "Comma-separated sequence of events." },
    { "name": "@NextEvent", "type": "NVARCHAR(20)",   "default": null, "description": "The next event in the sequence to be concatenated." }
  ],
  "Output Notes": [
    { "name": "Return Value", "type": "VARBINARY(16)", "description": "MD5 hash of the concatenated sequence and next-event string." }
  ],
  "Referenced objects": []
}

Sample utilization:

  SELECT dbo.SequenceKey('arrive,greeted,seated,intro', 'drinks');

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE FUNCTION [dbo].[SequenceKey]
(
@Seq NVARCHAR(MAX), --JSON of key/value pairs.
@NextEvent NVARCHAR(50)
)
RETURNS  VARBINARY(16)
AS
BEGIN

	RETURN HASHBYTES('MD5',CONCAT(@Seq,',',@NextEvent))

END
GO
/****** Object:  UserDefinedFunction [dbo].[SequenceProbability]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "SequenceProbability",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-14",
  "Description": "Computes the overall probability of observing a given event sequence under a Markov model by walking through the ModelEvents transition probabilities, starting from the stationary (eigenvector) probability of the first event and multiplying successive transition probabilities.",
  "Utilization": "Use when you want the probability of one or more sequences returned as a rowset, especially when comparing multiple sequences or joining sequence probabilities into larger analyses.",
  "Input Parameters": [
    { "name": "@Sequence", "type": "NVARCHAR(2000)", "default": null, "description": "Comma-separated list of events whose joint probability is to be computed." },
    { "name": "@ModelID",  "type": "INT",          "default": null, "description": "Identifier of the Markov model (in ModelEvents) to use for transition probabilities." }
  ],
  "Output Notes": [
    { "name": "Return Value", "type": "FLOAT", "description": "Computed probability of the full sequence; if the sequence is length 1, returns its stationary probability." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelEvents",                "type": "Table",                  "description": "First-order transition probabilities (EventA→EventB)." },
    { "name": "dbo.Model_Stationary_Distribution","type": "Table-Valued Function","description": "Provides stationary (eigenvector) probability for each event in the model." },
    { "name": "string_split",                    "type": "Built-in TVF",           "description": "Splits the input CSV sequence into individual event rows." }
  ]
}

Sample utilization:

SELECT dbo.SequenceProbability('heavytraffic,lighttraffic,moderatetraffic,heavytraffic,heavytraffic',10)
SELECT dbo.SequenceProbability('heavytraffic',10) -- Only gets the eigenvector value.

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

Notes:
    • Uses a recursive CTE to walk the sequence—watch out for SQL Server’s default MAXRECURSION limit (100).  
    • The ROW_NUMBER() over string_split assumes arbitrary ordering; consider enforcing a deterministic sort on the sequence input.  
    • Floating‐point underflow may occur for very long sequences—consider log‐space accumulation if needed.
*/

CREATE FUNCTION [dbo].[SequenceProbability]
(
@Sequence NVARCHAR(2000),
@ModelID INT
)
RETURNS FLOAT
AS
BEGIN
	DECLARE @prob TABLE (Prob FLOAT)

	--Convert the csv sequence into a table.
	DECLARE @i TABLE ([Event] NVARCHAR(50),[rank] INT)
	INSERT INTO @i
		SELECT 
			[event], 
			CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) as [rank]  
		FROM 
			(SELECT [value] AS [event] FROM string_split(@Sequence, ',')) t  
	DECLARE @ilen INT=@@ROWCOUNT

	;
	WITH m (EventA, EventB, Prob) AS -- The Model segments.
	(
		SELECT 
			EventA,
			EventB,
			Prob
		FROM
			[dbo].[ModelEvents] WITH (NOLOCK)
		WHERE
			ModelID=@ModelID
	), 
	p ([Event],[x],[Prob]) AS --Recursive CTE. Starts with the eigenvector probability of the first item in the sequence.
	(
		SELECT
			[Event],
			1 AS x,
			(SELECT Probability FROM [dbo].[Model_Stationary_Distribution] sd WITH (NOLOCK) WHERE sd.Modelid=@ModelID AND sd.[Event]=(SELECT [Event] FROM @i i WHERE i.[rank]=1))
		FROM
			@i i
		WHERE
			i.[rank]=1
		UNION ALL
		SELECT
			i.[Event],
			i.[rank] AS x,
			p.[Prob]*COALESCE((SELECT m.Prob FROM m WHERE m.[EventA]=p.[Event] AND m.[EventB]= i.[Event]),0.0)
		FROM
			p
			JOIN @i i ON i.[rank]=p.x+1
		WHERE
			p.[x]<@ilen

	)
	INSERT INTO @prob
		SELECT TOP 1 
			[Prob] 
		FROM 
			p 
		ORDER BY [x] DESC

	DECLARE @result FLOAT
	SELECT @result=[Prob] FROM @prob
	

	-- Return the result of the function
	RETURN @result

END
GO
/****** Object:  UserDefinedFunction [dbo].[Sequences]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
*** THIS TVF is deprecated as it cannot be ported to Azure Synapse. Use the sproc, sp_Sequences.***


Metadata JSON:
{
  "Table-Valued Function": "Sequences",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-16",
  "Description": "Computes all successive event‐sequence statistics (per‐sequence and per‐hop) for a given event set over a time window, optionally using cached results for performance.",
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
    SELECT * 
      FROM dbo.Sequences(
        'arrive,greeted,seated',  
         1, '1900-01-01','2050-12-31',
         NULL,1,NULL,NULL,NULL,0
      );

    SELECT * 
      FROM dbo.Sequences(
        'restaurantguest',  
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

CREATE FUNCTION [dbo].[Sequences]
(
	@EventSet NVARCHAR(MAX),
	@enumerate_multiple_events INT,
	@StartDateTime DATETIME,
	@EndDateTime DATETIME,
	@transforms NVARCHAR(MAX),
	@ByCase BIT=1,
	@Metric NVARCHAR(20),
	@CaseFilterProperties NVARCHAR(MAX),
	@EventFilterProperties NVARCHAR(MAX),
	@ForceRefresh BIT
)
RETURNS 

@seq1 TABLE (
	[Seq] NVARCHAR(2000), 
	lastEvent NVARCHAR(50),
	nextEvent NVARCHAR(50), 
	[SeqStDev] FLOAT, 
	[SeqMax] FLOAT, 
	[SeqAvg] FLOAT, 
	[SeqMin] FLOAT, --Max and min can help detect skew.
	[SeqSum] FLOAT, -- This lets us calculate an AVG across any way we reach the last event.
	[HopStDev] FLOAT,
	[HopMax] FLOAT,
	[HopAvg] FLOAT,
	[HopMin] FLOAT,
	TotalRows INT,
	[Rows] INT, 
	Prob FLOAT,
	ExitRows INT,
	Cases INT,
	ModelID INT,
	FromCache BIT, -- This tells whether the sequence was found in ModelSequences or calculated on the fly.
	[length] INT
)
AS
BEGIN

	DECLARE @ModelType NVARCHAR(50)='MarkovChain'

    SELECT
		@StartDateTime=StartDateTime,
		@EndDateTime=EndDateTime,
		@metric=[metric]
      FROM dbo.SetDefaultModelParameters(
             @StartDateTime,    -- @StartDateTime
             @EndDateTime,    -- @EndDateTime
             NULL,    -- @Order
             NULL,    -- @enumerate_multiple_events
             @metric     -- @metric
           );

	SET @ByCase=COALESCE(@ByCase,1)
	SET @ForceRefresh=COALESCE(@ForceRefresh,0) --Default to do not force refresh. This way, if the model is cached, it is used.
	DECLARE @ModelID INT=dbo.[ModelID]
	(
		@EventSet,
		@enumerate_multiple_events,
		@StartDateTime,
		@EndDateTime ,
		@transforms,
		@ByCase,
		@Metric,
		@CaseFilterProperties,
		@EventFilterProperties,
		@ModelType
	)

	IF @ForceRefresh=0 AND @ModelID IS NOT NULL
	BEGIN
		INSERT INTO @seq1
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
				,[TermRows]
				,[Cases]
				,[ModelID]
				,1 --This is from cache.
				,[length]
				FROM 
					[dbo].[ModelSequences]
				WHERE
					modelid=@ModelID
		RETURN
	END

	DECLARE @raw TABLE
	(
		CaseID int, 
		[Event] NVARCHAR(50), 
		EventDate datetime, 
		[Rank] INT NULL, 
		EventOccurence bigint,
		UNIQUE (CaseID,[Rank]) --Supposed to create index. However, it's in-memory, so I probably need to move this to sproc.
	)
	INSERT INTO @raw
		SELECT
			e.CaseID,
			e.[Event],
			e.EventDate,
			[Rank],
			[EventOccurence]
		FROM
			SelectedEvents(@EventSet,@enumerate_multiple_events,@StartDateTime,@EndDateTime,@transforms,@ByCase,@Metric,@CaseFilterProperties,@EventFilterProperties) e
	

	DECLARE @c TABLE (c INT)
	INSERT INTO @c SELECT DISTINCT [Rank] FROM @raw

	DECLARE @seq TABLE (CaseID INT,StartEventDate DATETIME,c INT, [Seq] NVARCHAR(2000),[length] INT)
	DELETE FROM @seq
	
	INSERT INTO @seq
		SELECT
			e.[CaseID],
			e1.EventDate AS StartEventDate,
			c.c,
			STRING_AGG(e.[Event],',') WITHIN GROUP (ORDER BY e.[EventDate]) AS [Seq],
			COUNT(*) AS [length]
		FROM
			@raw e
			JOIN @raw e1 On e1.CaseID=e.CaseID AND e1.[Rank]=1
			CROSS APPLY @c c
		WHERE
			e.[Rank] BETWEEN 1 AND c.c
		GROUP BY
			e.[CaseID],
			c.c,
			e1.EventDate

	INSERT INTO @seq1
		SELECT
			s.Seq AS Seq,
			l.[Event] AS lastEvent,
			e.[Event] as nextEvent,
			ROUND(CAST(STDEV(DATEDIFF(ss,s.StartEventDate,e.EventDate)) AS FLOAT)/60.0,4) AS SeqStDev,
			ROUND(MAX(DATEDIFF(ss,s.StartEventDate,e.EventDate))/60,4) AS SeqMax,
			ROUND(CAST(AVG(DATEDIFF(ss,s.StartEventDate,e.EventDate)) AS FLOAT),4)/60.0 AS SeqAvg,
			ROUND(MIN(DATEDIFF(ss,s.StartEventDate,e.EventDate))/60,4) AS SeqMin,
			SUM(DATEDIFF(ss,s.StartEventDate,e.EventDate))/60 AS SeqSum,
			ROUND(CAST(STDEV(DATEDIFF(ss,l.EventDate,e.EventDate)) AS FLOAT)/60.0,4) AS HopStDev,
			MAX(DATEDIFF(ss,l.EventDate,e.EventDate))/60 AS HopMax,
			ROUND(CAST(AVG(DATEDIFF(ss,l.EventDate,e.EventDate)) AS FLOAT)/60.0,4) AS HopAvg,
			MIN(DATEDIFF(ss,l.EventDate,e.EventDate))/60 AS HopMin,
			s1.[Rows] AS TotalRows,
			COUNT(*) AS [Rows],
			ROUND(COUNT(*)/CAST(s1.[Rows] AS FLOAT),4) AS Prob,
			SUM(CASE WHEN twoout.CaseID IS NULL THEN 1 ELSE NULL END) AS ExitRows, -- Number of rows where this is the terminal event.
			COUNT(DISTINCT s.CaseID) AS Cases,
			@ModelID,
			0, --Not from cache.
			s.[length]
		FROM
			@seq s
			JOIN
			(
				SELECT
					s1.[Seq],
					COUNT(*) AS [Rows]
				FROM
					@seq s1
				GROUP BY
					s1.[Seq]
			) AS s1 ON s1.[Seq]=s.[Seq]
			LEFT JOIN @raw twoout ON twoout.CaseID=s.CaseID AND twoout.[Rank]=s.c+2 -- get two out so we know if this is a terminal event.
			LEFT JOIN @raw e ON e.CaseID=s.CaseID AND e.[Rank]=s.c+1 -- row of the next event. This is the PREDICTED event following the Seq.
			LEFT JOIN @raw l ON l.CaseID=s.CaseID AND l.[Rank]=s.c		--row of the last event of the sequence.
		WHERE
			e.CaseID IS NOT NULL
		GROUP BY
			s.Seq,
			l.[Event],
			e.[Event],
			s1.[Rows],
			s.[length]



	RETURN 
END
GO
/****** Object:  UserDefinedFunction [dbo].[SequenceSegments]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
*** THIS TVF is deprecated as it cannot be ported to Azure Synapse. Use the sproc, sp_SequenceSegments.***


Metadata JSON:
{
  "Table-Valued Function": "SequenceSegments",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-19",
  "Description": "Identifies and aggregates all event sequences in raw event data that begin with a specified start event and end with a specified end event, computing basic statistics (min, max, avg, stdev, sum) on the elapsed time between those events and listing the cases in which they occur.",
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

SELECT * FROM dbo.[SequenceSegments]('greeted','order','arrive,greeted,seated,intro,drinks,ccdeclined,charged,order,check,seated,served,bigtip,depart',1,'01/01/1900','12/31/2050',NULL,1,NULL,NULL)
SELECT * FROM dbo.[SequenceSegments]('drinks','depart','arrive,greeted,seated,intro,drinks,ccdeclined,charged,order,check,seated,served,bigtip,depart',1,'01/01/1900','12/31/2050',NULL,1,NULL,NULL)


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
CREATE FUNCTION [dbo].[SequenceSegments]
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
	@FilterProperties NVARCHAR(MAX)
)
RETURNS 

@seq TABLE (
	[Seq] NVARCHAR(2000), 
	[SeqStDev] FLOAT, 
	[SeqMax] FLOAT, 
	[SeqAvg] FLOAT, 
	[SeqMin] FLOAT, --Max and min can help detect skew.
	[SeqSum] FLOAT, -- This lets us calculate an AVG across any way we reach the last event.
	Cases INT,
	CaseID_List NVARCHAR(MAX)
)
AS
BEGIN
	SET @metric=COALESCE(@metric,'Time Between')

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

	DECLARE @raw TABLE(CaseID int, [Event] NVARCHAR(50), EventDate datetime, [Rank] INT NULL, EventOccurence bigint)
	INSERT INTO @raw
		SELECT
			e.CaseID,
			e.[Event],
			e.EventDate,
			[Rank],
			EventOccurence
		FROM
			SelectedEvents(@EventSet,@enumerate_multiple_events,@StartDateTime,@EndDateTime,@transforms,@ByCase,@Metric,@FilterProperties,NULL) e


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

	RETURN 
END
GO
/****** Object:  UserDefinedFunction [dbo].[SortKeyValueJSON]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "SortKeyValueJSON",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-14",
  "Description": "Accepts a JSON object and returns a new JSON string with its key/value pairs sorted by key, preserving values as strings.",
  "Utilization": "Use when you need a canonical ordering of JSON key/value pairs before hashing, comparison, storage, or transform-key generation.",
  "Input Parameters": [
    { "name": "@JSON", "type": "NVARCHAR(4000)", "default": "NULL", "description": "A JSON-formatted string representing an object of key/value pairs." }
  ],
  "Output Notes": [
    { "name": "Return Value", "type": "NVARCHAR(MAX)", "description": "A JSON string with entries sorted lexically by key, e.g. '{\"ally\":\"smith\",\"barry\":\"carter\",\"harry\":\"Carry\"}'. Returns NULL if input is not valid JSON." }
  ],
  "Referenced objects": [
    { "name": "OPENJSON", "type": "Built-in TVF", "description": "Used to parse the input JSON into key/value rows." }
  ]
}

Sample utilization:

    SELECT dbo.SortKeyValueJSON('{"harry":"Carry","ally":"smith","barry":"carter"}');

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

/* 
Advice:
- Currently returns NULL if input fails ISJSON; consider raising an error or returning '{}' for robustness.
*/

CREATE FUNCTION [dbo].[SortKeyValueJSON]
(
@JSON NVARCHAR(4000)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
	DECLARE @result NVARCHAR(MAX)
	IF ISJSON(@JSON) = 1
	BEGIN
		SELECT @result = 
			STRING_AGG('"' + [key] + '":"' + CAST([value] AS NVARCHAR(MAX)) + '"', ',') 
			WITHIN GROUP (ORDER BY [key])
		FROM OPENJSON(@JSON) 
	END
	RETURN '{'+@result+'}'
END
GO
/****** Object:  UserDefinedFunction [dbo].[SourceID]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "SourceID",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-14",
  "Description": "Looks up and returns the SourceID for a given server and database combination from the Sources table, or NULL if not found.",
  "Utilization": "Use when you know the server and database names and want to resolve the corresponding SourceID for inserts, metadata joins, or ETL setup.",
  "Input Parameters": [
    { "name": "@ServerName",   "type": "NVARCHAR(400)", "default": "NULL", "description": "Name of the SQL Server instance (e.g., 'DESKTOP-N5ISJJF\\MSSQLSERVER01')." },
    { "name": "@DatabaseName", "type": "NVARCHAR(400)", "default": "NULL", "description": "Name of the database within the server (e.g., 'Stocks')." }
  ],
  "Output Notes": [
    { "name": "Return Value", "type": "INT", "description": "The matching SourceID from dbo.Sources, or NULL if no matching row exists." }
  ],
  "Referenced objects": [
    { "name": "dbo.Sources", "type": "Table", "description": "Stores registered data sources, keyed by ServerName and DatabaseName." }
  ]
}

Sample utilization:

    SELECT dbo.SourceID('EAA2024','Stocks',NULL);
    SELECT dbo.SourceID('EAA2024','EHR','Orders');

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

/*
Advice:
- Consider returning 0 or raising an error if no match is found, rather than NULL, depending on downstream handling.
- Add an index on (ServerName, DatabaseName) for faster lookups if the table grows large.
*/

CREATE FUNCTION [dbo].[SourceID]
(
@ServerName NVARCHAR(400),
@DatabaseName NVARCHAR(400),
@DefaultTableName NVARCHAR(128)
)
RETURNS INT
AS
BEGIN
	RETURN (
	--[TODO] This TOP 1 is just a hack for now.
	SELECT TOP 1
		SourceID 
	FROM 
		[dbo].[Sources] s 
	WHERE 
		s.DatabaseName=@DatabaseName AND 
		s.ServerName=@ServerName AND
		(@DefaultTableName IS NULL OR COALESCE(@DefaultTableName,'')=COALESCE(s.DefaultTableName,''))
	)

END
GO
/****** Object:  UserDefinedFunction [dbo].[TransformsKey]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "TransformsKey",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-14",
  "Description": "Generates a stable 16-byte MD5 hash for a JSON mapping of event transforms by sorting key/value pairs to ensure consistent ordering regardless of input order.",
  "Utilization": "Use when you need a stable canonical key for a transforms JSON payload so logically identical mappings resolve to the same identifier even if the JSON property order differs. Helpful for deduplicating transform definitions, looking up cached models by transforms set, or storing transform metadata consistently.",
  "Input Parameters": [
    { "name": "@Transforms", "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON object of event transform mappings (e.g. {\"source\":\"target\",…})." }
  ],
  "Output Notes": [
    { "name": "Return Value", "type": "VARBINARY(16)", "description": "MD5 hash of the sorted, concatenated key:value pairs." }
  ],
  "Referenced objects": [
    { "name": "dbo.ParseTransforms", "type": "Table-Valued Function", "description": "Splits the JSON into rows of fromkey and tokey." }
  ]
}

Sample utilization:

    SELECT dbo.TransformsKey('{"lighttraffic":"traffic","moderatetraffic":"traffic","heavytraffic":"traffic"}');
    SELECT dbo.TransformsKey('{"heavytraffic":"traffic","lighttraffic":"traffic","moderatetraffic":"traffic"}');
	--heavytraffic shows up twice, second one with a different value.
    SELECT dbo.TransformsKey('{"moderatetraffic":"traffic","heavytraffic":"traffic","lighttraffic":"traffic","heavytraffic":"vtraffce"}');
    SELECT dbo.TransformsKey('{"moderatetraffic":"traffic","heavytraffic":"traffic","lighttraffic":"traffic","LAtraffic":"reallybadtraffce"}');

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

/*
Advice:
- Ensure ParseTransforms handles nested or invalid JSON gracefully.
- Consider using SHA2_256 for stronger hashing if security is a concern.
- Add an index on TransformsKey column in the Transforms table for faster lookups.
*/

CREATE FUNCTION [dbo].[TransformsKey]
(
@Transforms NVARCHAR(MAX) --JSON of key/value pairs. Key is the from event, Value is the to Event.
)
RETURNS  VARBINARY(16)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @result VARBINARY(16)=NULL
	IF @Transforms IS NOT NULL
	BEGIN

		DECLARE @kv TABLE (k nvarchar(50),v nvarchar(50),r int)
		-- The json is sorted by key (from event) and value (to event). This way, when we're doing a lookup,
		-- we get the same answer.
		insert into @kv
			SELECT [fromkey],[tokey],DENSE_RANK() OVER (ORDER BY [fromkey]) as [r] FROM ParseTransforms(@Transforms) order by [fromkey]
		SELECT 
			@result=HASHBYTES('MD5',STRING_AGG(CAST([k] +':'+[v] AS NVARCHAR(50)),','))
			FROM 
				@kv o
	END
	RETURN @result

END
GO
/****** Object:  UserDefinedFunction [dbo].[UserAccessBitmap]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "dbo.UserAccessBitmap",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": "Returns the access bitmap for the current SQL Server login (SUSER_NAME or SUSER_SID). Encapsulates access control logic by hiding the Users table from direct queries.",
  "Utilization": "Use when enforcing row-level or model-level access rules based on the current user’s bitmap permissions inside queries or procedures.",
  "Input Parameters": [],
  "Output Notes": [
    { "name": "Return Value", "type": "BIGINT", "description": "Bitmap representing the access rights granted to the current user." }
  ],
  "Referenced objects": [
    { "name": "dbo.Users", "type": "Table", "description": "Stores user records with an AccessBitmap column keyed by SUSER_NAME." }
  ]
}

Sample utilization:

    SELECT dbo.UserAccessBitmap();

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

Security Notes:
    - This function is intended to be the **only permitted interface** for retrieving access rights.
    - It relies on **ownership chaining**, so both this function and dbo.Users must be owned by the same schema (dbo).
    - Permissions:
        • GRANT EXECUTE on this function to appropriate roles or users
        • DENY or REVOKE SELECT on dbo.Users for those same roles/users
    - Uses SUSER_NAME() (or SUSER_SID) to map the login to its row in dbo.Users.

    Ownership chaining allows this function to access dbo.Users without requiring the caller to have direct SELECT rights.


*/

CREATE FUNCTION [dbo].[UserAccessBitmap]
(
)
RETURNS BIGINT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @accessbitmap BIGINT

	-- Add the T-SQL statements to compute the return value here
	SELECT @accessbitmap=accessbitmap FROM dbo.Users WHERE [SUSER_NAME]=SUSER_NAME()

	-- Return the result of the function
	RETURN @accessbitmap

END
GO
/****** Object:  UserDefinedFunction [dbo].[UserID]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "UserID",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-14",
  "Description": "Looks up the numeric UserID for a given Windows login; if none is passed, uses the current session’s login.",
  "Utilization": "Use when you need the internal user identifier for the current or supplied user in joins, access checks, or audit logic.",
  "Input Parameters": [
    { "name": "@SUSER_NAME", "type": "NVARCHAR(50)", "default": "NULL", "description": "Windows login name; NULL to use CURRENT_USER via SUSER_NAME()." }
  ],
  "Output Notes": [
    { "name": "Return Value", "type": "INT", "description": "The matching UserID from dbo.Users, or NULL if not found." }
  ],
  "Referenced objects": [
    { "name": "dbo.Users", "type": "Table", "description": "Holds application user records with SUSER_NAME and UserID columns." }
  ]
}

Sample utilization:

    SELECT dbo.UserID(NULL);       -- Your own UserID
    SELECT dbo.UserID('DOMAIN\\Joe');  -- Specific login

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

Notes:
    • If the provided login does not exist in dbo.Users, the function returns NULL. You may wish to raise an error or insert a default user.
    • Consider adding an index on Users.SUSER_NAME for lookup performance.
*/

CREATE FUNCTION [dbo].[UserID]
(
@SUSER_NAME NVARCHAR(50) --NULL will get the current user.
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @UserID INT

	-- Add the T-SQL statements to compute the return value here
	SELECT @UserID=UserID FROM dbo.Users WHERE [SUSER_NAME]=COALESCE(@SUSER_NAME,SUSER_NAME())

	-- Return the result of the function
	RETURN @userid

END
GO
/****** Object:  UserDefinedFunction [ETL].[StockMove]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Scalar Function": "ETL.StockMove",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-14",
  "Description": "Evaluates two successive stock values and classifies the movement as a big jump, big drop, or no move based on a configurable threshold.",
  "Utilization": "Use when classifying or summarizing stock-price movement in a consistent way for analytics, transforms, or downstream event generation.",
  "Input Parameters": [
    { "name": "@Value0",                "type": "FLOAT", "default": null, "description": "Current stock value." },
    { "name": "@Value1",                "type": "FLOAT", "default": null, "description": "Prior stock value." },
    { "name": "@Big_Jump_Threshold",    "type": "FLOAT", "default": null, "description": "Fractional threshold (e.g., 0.10 for 10%) to consider a jump or drop big." }
  ],
  "Output Notes": [
    { "name": "Return Value", "type": "NVARCHAR(20)", "description": "Classification string: 'Big Jump+X%', 'Big Drop-X%', or 'No Move'." }
  ],
  "Referenced objects": []
}

Sample utilization:

    SELECT ETL.StockMove(105.0, 100.0, 0.05);  
	   SELECT ETL.StockMove(105.0, 200.0, 0.05); 

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/

CREATE FUNCTION [ETL].[StockMove]
(
@Value0 FLOAT,
@Value1 FLOAT,
@Big_Jump_Threshold FLOAT
)
RETURNS NVARCHAR(20)
AS
BEGIN
	RETURN
    CASE
        WHEN (@Value0 - @Value1) / @Value1 > @Big_Jump_Threshold THEN 'Big Jump+'+CAST(@Big_Jump_Threshold*100 AS VARCHAR(10))+'%'
        WHEN (@Value0 - @Value1) / @Value1 < -(@Big_Jump_Threshold) THEN 'Big Drop-'+CAST(@Big_Jump_Threshold*100 AS VARCHAR(10))+'%'
        ELSE 'No Move'
    END


END
GO
/****** Object:  UserDefinedFunction [dbo].[ModelsWithProperties]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Table-Valued Function": "ModelsWithProperties",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-16",
  "Description": "Retrieves models that have at least one of the specified custom properties, returning up to five property names and their numeric or alpha values for each model.",
  "Utilization": "Use when you need to pivot a small set of model properties into a wide row per model so those properties can be filtered, displayed, or joined more easily. Helpful for browsing models by custom metadata, exporting model catalogs, or combining selected model properties with other model-level result sets.",
  "Input Parameters": [
    { "name": "@SelectedProperties", "type": "NVARCHAR(MAX)", "default": "NULL", "description": "Comma-separated list of property names to include; if NULL, returns a placeholder row with ModelID = -1." }
  ],
  "Output Notes": [
    { "name": "ModelID",                    "type": "INT",           "description": "Identifier of the model." },
    { "name": "ModelType",                  "type": "NVARCHAR(50)",  "description": "Category/type of the model." },
    { "name": "Property1",                  "type": "NVARCHAR(20)",  "description": "First custom property name." },
    { "name": "Property1ValueNumeric",      "type": "FLOAT",         "description": "Numeric value for the first property." },
    { "name": "Property1ValueAlpha",        "type": "NVARCHAR(1000)","description": "Alpha value for the first property." },
    { "name": "Property2",                  "type": "NVARCHAR(20)",  "description": "Second custom property name." },
    { "name": "Property2ValueNumeric",      "type": "FLOAT",         "description": "Numeric value for the second property." },
    { "name": "Property2ValueAlpha",        "type": "NVARCHAR(1000)","description": "Alpha value for the second property." },
    { "name": "Property3",                  "type": "NVARCHAR(20)",  "description": "Third custom property name." },
    { "name": "Property3ValueNumeric",      "type": "FLOAT",         "description": "Numeric value for the third property." },
    { "name": "Property3ValueAlpha",        "type": "NVARCHAR(1000)","description": "Alpha value for the third property." },
    { "name": "Property4",                  "type": "NVARCHAR(20)",  "description": "Fourth custom property name." },
    { "name": "Property4ValueNumeric",      "type": "FLOAT",         "description": "Numeric value for the fourth property." },
    { "name": "Property4ValueAlpha",        "type": "NVARCHAR(1000)","description": "Alpha value for the fourth property." },
    { "name": "Property5",                  "type": "NVARCHAR(20)",  "description": "Fifth custom property name." },
    { "name": "Property5ValueNumeric",      "type": "FLOAT",         "description": "Numeric value for the fifth property." },
    { "name": "Property5ValueAlpha",        "type": "NVARCHAR(1000)","description": "Alpha value for the fifth property." }
  ],
  "Referenced objects": [
    { "name": "dbo.Models",                 "type": "Table",                  "description": "Stores model definitions and metadata." },
    { "name": "dbo.ModelProperties",        "type": "Table",                  "description": "Holds custom property values for each model." },
    { "name": "STRING_SPLIT",               "type": "Table-Valued Function",  "description": "Built-in function to split CSV input into rows." }
  ]
}

Sample utilization:
    SELECT * 
      FROM dbo.ModelsWithProperties('EmployeeID,CustomerID');


Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

Notes:
    Differs from ModelsByParameters in that this searches by Case and event properties used for slicing.
    Example:
        SELECT * FROM [dbo].[ModelsWithProperties]('EmployeeID,CustomerID');
*/


CREATE FUNCTION [dbo].[ModelsWithProperties]
(
    @SelectedProperties NVARCHAR(MAX) -- CSV of properties
)
RETURNS TABLE
AS
RETURN
(
    WITH CurrentUser AS
    (
        SELECT CAST(dbo.UserAccessBitmap() AS BIGINT) AS UserAccessBitmap
    ),
    Properties AS
    (
        SELECT
            LTRIM(RTRIM([value])) AS [property],
            ROW_NUMBER() OVER (ORDER BY LTRIM(RTRIM([value]))) AS [rank]
        FROM string_split(@SelectedProperties, ',')
        WHERE @SelectedProperties IS NOT NULL
    ),
    PropKeys AS
    (
        SELECT
            MAX(CASE WHEN [rank] = 1 THEN [property] END) AS PropKey1,
            MAX(CASE WHEN [rank] = 2 THEN [property] END) AS PropKey2,
            MAX(CASE WHEN [rank] = 3 THEN [property] END) AS PropKey3,
            MAX(CASE WHEN [rank] = 4 THEN [property] END) AS PropKey4,
            MAX(CASE WHEN [rank] = 5 THEN [property] END) AS PropKey5
        FROM Properties
    )
    SELECT
        -1 AS ModelID,
        CAST(NULL AS NVARCHAR(50)) AS ModelType,
        CAST(NULL AS NVARCHAR(50)) AS Property1,
        CAST(NULL AS FLOAT) AS Property1ValueNumeric,
        CAST(NULL AS NVARCHAR(1000)) AS Property1ValueAlpha,
        CAST(NULL AS NVARCHAR(50)) AS Property2,
        CAST(NULL AS FLOAT) AS Property2ValueNumeric,
        CAST(NULL AS NVARCHAR(1000)) AS Property2ValueAlpha,
        CAST(NULL AS NVARCHAR(50)) AS Property3,
        CAST(NULL AS FLOAT) AS Property3ValueNumeric,
        CAST(NULL AS NVARCHAR(1000)) AS Property3ValueAlpha,
        CAST(NULL AS NVARCHAR(50)) AS Property4,
        CAST(NULL AS FLOAT) AS Property4ValueNumeric,
        CAST(NULL AS NVARCHAR(1000)) AS Property4ValueAlpha,
        CAST(NULL AS NVARCHAR(50)) AS Property5,
        CAST(NULL AS FLOAT) AS Property5ValueNumeric,
        CAST(NULL AS NVARCHAR(1000)) AS Property5ValueAlpha
    WHERE
        @SelectedProperties IS NULL

    UNION ALL

    SELECT
        c.ModelID,
        c.ModelType,
        cp1.PropertyName,
        cp1.PropertyValueNumeric,
        cp1.PropertyValueAlpha,
        cp2.PropertyName,
        cp2.PropertyValueNumeric,
        cp2.PropertyValueAlpha,
        cp3.PropertyName,
        cp3.PropertyValueNumeric,
        cp3.PropertyValueAlpha,
        cp4.PropertyName,
        cp4.PropertyValueNumeric,
        cp4.PropertyValueAlpha,
        cp5.PropertyName,
        cp5.PropertyValueNumeric,
        cp5.PropertyValueAlpha
    FROM
        [dbo].[Models] c
        CROSS JOIN PropKeys pk
        CROSS JOIN CurrentUser cu
        LEFT JOIN [dbo].[ModelProperties] cp1
            ON pk.PropKey1 IS NOT NULL
           AND cp1.ModelID = c.ModelID
           AND cp1.PropertyName = pk.PropKey1
        LEFT JOIN [dbo].[ModelProperties] cp2
            ON pk.PropKey2 IS NOT NULL
           AND cp2.ModelID = c.ModelID
           AND cp2.PropertyName = pk.PropKey2
        LEFT JOIN [dbo].[ModelProperties] cp3
            ON pk.PropKey3 IS NOT NULL
           AND cp3.ModelID = c.ModelID
           AND cp3.PropertyName = pk.PropKey3
        LEFT JOIN [dbo].[ModelProperties] cp4
            ON pk.PropKey4 IS NOT NULL
           AND cp4.ModelID = c.ModelID
           AND cp4.PropertyName = pk.PropKey4
        LEFT JOIN [dbo].[ModelProperties] cp5
            ON pk.PropKey5 IS NOT NULL
           AND cp5.ModelID = c.ModelID
           AND cp5.PropertyName = pk.PropKey5
    WHERE
        (
            c.AccessBitmap = -1
            OR c.AccessBitmap IS NULL
            OR (cu.UserAccessBitmap & c.AccessBitmap) <> 0
        )
        AND @SelectedProperties IS NOT NULL
        AND
        (
            cp1.PropertyValueNumeric IS NOT NULL OR cp1.PropertyValueAlpha IS NOT NULL OR
            cp2.PropertyValueNumeric IS NOT NULL OR cp2.PropertyValueAlpha IS NOT NULL OR
            cp3.PropertyValueNumeric IS NOT NULL OR cp3.PropertyValueAlpha IS NOT NULL OR
            cp4.PropertyValueNumeric IS NOT NULL OR cp4.PropertyValueAlpha IS NOT NULL OR
            cp5.PropertyValueNumeric IS NOT NULL OR cp5.PropertyValueAlpha IS NOT NULL
        )
);
GO
/****** Object:  UserDefinedFunction [dbo].[ModelEventsFull]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "ModelEventsFull",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Returns the full set of transition metrics (stats, probabilities, entry/exit flags, and up to five custom properties) for all model segments, filtered by user access and optionally by selected model properties.",
  "Utilization": "Use when you want a richer version of model-event output than the basic segment table, especially for reporting, auditing, or exporting fuller model detail.",
  "Input Parameters": [
    {
      "name": "@SelectedProperties",
      "type": "NVARCHAR(MAX)",
      "default": null,
      "description": "JSON or comma-delimited list of model property names to include; if null or empty, properties are still joined but only non-null values will appear."
    }
  ],
  "Output Notes": [
    { "name": "ModelID",                  "type": "INT",           "description": "Identifier of the Markov model." },
    { "name": "EventA",                   "type": "NVARCHAR(20)",  "description": "From-event in the transition." },
    { "name": "EventB",                   "type": "NVARCHAR(20)",  "description": "To-event in the transition." },
    { "name": "Max",                      "type": "FLOAT",         "description": "Maximum observed metric value." },
    { "name": "Avg",                      "type": "FLOAT",         "description": "Average observed metric value." },
    { "name": "Min",                      "type": "FLOAT",         "description": "Minimum observed metric value." },
    { "name": "StDev",                    "type": "FLOAT",         "description": "Standard deviation of the metric." },
    { "name": "Sum",                      "type": "FLOAT",         "description": "Sum of metric values across all occurrences." },
    { "name": "CoefVar",                  "type": "FLOAT",         "description": "Coefficient of variation (StDev/Avg)." },
    { "name": "Rows",                     "type": "INT",           "description": "Count of transition occurrences." },
    { "name": "Prob",                     "type": "FLOAT",         "description": "Observed transition probability." },
    { "name": "EventAIsEntry",            "type": "BIT",           "description": "Flag: this transition starts a case." },
    { "name": "EventBIsExit",             "type": "BIT",           "description": "Flag: this transition ends a case." },
    { "name": "Metric",                   "type": "NVARCHAR(20)",  "description": "Name of the metric used." },
    { "name": "UoM",                      "type": "NVARCHAR(20)",  "description": "Unit of measure for the metric." },
    { "name": "ModelType",                "type": "NVARCHAR(50)",  "description": "Type/category of the model." },
    { "name": "StartDateTime",            "type": "DATETIME",      "description": "Model effective start date." },
    { "name": "EndDateTime",              "type": "DATETIME",      "description": "Model effective end date." },
    { "name": "ByCase",                   "type": "BIT",           "description": "Flag: events were grouped by case." },
    { "name": "enumerate_multiple_events","type": "INT",           "description": "Flag controlling repeated-event enumeration." },
    { "name": "Property1",                "type": "NVARCHAR(50)",  "description": "First custom property name." },
    { "name": "Property1ValueNumeric",    "type": "FLOAT",         "description": "Numeric value for the first custom property." },
    { "name": "Property1ValueAlpha",      "type": "NVARCHAR(50)",  "description": "Alpha value for the first custom property." },
    { "name": "Property2",                "type": "NVARCHAR(50)",  "description": "Second custom property name." },
    { "name": "Property2ValueNumeric",    "type": "FLOAT",         "description": "Numeric value for the second custom property." },
    { "name": "Property2ValueAlpha",      "type": "NVARCHAR(50)",  "description": "Alpha value for the second custom property." },
    { "name": "Property3",                "type": "NVARCHAR(50)",  "description": "Third custom property name." },
    { "name": "Property3ValueNumeric",    "type": "FLOAT",         "description": "Numeric value for the third custom property." },
    { "name": "Property3ValueAlpha",      "type": "NVARCHAR(50)",  "description": "Alpha value for the third custom property." },
    { "name": "Property4",                "type": "NVARCHAR(50)",  "description": "Fourth custom property name." },
    { "name": "Property4ValueNumeric",    "type": "FLOAT",         "description": "Numeric value for the fourth custom property." },
    { "name": "Property4ValueAlpha",      "type": "NVARCHAR(50)",  "description": "Alpha value for the fourth custom property." },
    { "name": "Property5",                "type": "NVARCHAR(50)",  "description": "Fifth custom property name." },
    { "name": "Property5ValueNumeric",    "type": "FLOAT",         "description": "Numeric value for the fifth custom property." },
    { "name": "Property5ValueAlpha",      "type": "NVARCHAR(50)",  "description": "Alpha value for the fifth custom property." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelEvents",           "type": "Table",               "description": "Stores first-order transition metrics." },
    { "name": "dbo.Models",                "type": "Table",               "description": "Model configuration and metadata." },
    { "name": "dbo.Metrics",               "type": "Table",               "description": "Defines metric names and units." },
    { "name": "dbo.ModelsWithProperties",  "type": "Table-Valued Function","description": "Returns up to five properties per model when joined." },
    { "name": "dbo.UserAccessBitmap",      "type": "Scalar Function",     "description": "Retrieves the current user’s access bitmap for filtering." }
  ]
}

Sample utilization:
    SELECT * FROM dbo.ModelEventsFull('["Property1","Property3"]');

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/


CREATE FUNCTION [dbo].[ModelEventsFull]
(	
@SelectedProperties NVARCHAR(MAX)
)
RETURNS TABLE 
AS
RETURN 
(
	-- Add the SELECT statement with parameter references here
	SELECT
		m.[ModelID]
		,[EventA]
		,[EventB]
		,[Max]
		,[Avg]
		,[Min]
		,[StDev]
		,[Sum]
		,[CoefVar]
		,[Rows]
		,[Prob]
		,[IsEntry] AS EventAIsEntry
		,[IsExit] AS EventBIsExit
		,mt.Metric
		,mt.UoM
		,m.ModelType
		,m.StartDateTime
		,m.EndDateTime
		,m.ByCase
		,m.enumerate_multiple_events,
		mp.Property1 AS Property1,
		mp.Property1ValueNumeric AS Property1ValueNumeric,
		mp.Property1ValueAlpha AS Property1ValueAlpha,
		mp.Property2 AS Property2,
		mp.Property2ValueNumeric AS Property2ValueNumeric,
		mp.Property2ValueAlpha AS Property2ValueAlpha,
		mp.Property3 AS Property3,
		mp.Property3ValueNumeric AS Property3ValueNumeric,
		mp.Property3ValueAlpha AS Property3ValueAlpha,
		mp.Property4 AS Property4,
		mp.Property4ValueNumeric AS Property4ValueNumeric,
		mp.Property4ValueAlpha AS Property4ValueAlpha,
		mp.Property5 AS Property5,
		mp.Property5ValueNumeric AS Property5ValueNumeric,
		mp.Property5ValueAlpha AS Property5ValueAlpha
	FROM	
		[dbo].[ModelEvents] me ( NOLOCK)
		JOIN Models m (NOLOCK) ON me.ModelID=m.modelid
		JOIN [dbo].[Metrics] mt (NOLOCK) ON mt.MetricID=m.MetricID
		LEFT JOIN [dbo].[ModelsWithProperties](@SelectedProperties) mp ON mp.ModelID=m.modelid
	WHERE
		(dbo.UserAccessBitmap() & m.AccessBitmap)=m.AccessBitmap AND
		(
			mp.Property1ValueNumeric IS NOT NULL OR mp.Property1ValueAlpha IS NOT NULL OR
			mp.Property2ValueNumeric IS NOT NULL OR mp.Property2ValueAlpha IS NOT NULL OR
			mp.Property3ValueNumeric IS NOT NULL OR mp.Property3ValueAlpha IS NOT NULL OR
			mp.Property4ValueNumeric IS NOT NULL OR mp.Property4ValueAlpha IS NOT NULL OR
			mp.Property5ValueNumeric IS NOT NULL OR mp.Property5ValueAlpha IS NOT NULL
		)
)
GO
/****** Object:  View [dbo].[vwSourceColumnsFull]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vwSourceColumnsFull]
AS
SELECT sc.SourceColumnID, sc.SourceID, sc.TableName, sc.ColumnName, sc.IsKey, sc.IsOrdinal, sc.DataType, sc.Description AS ColumnDescription, sc.IRI AS ColumnIRI, sc.ObserverID, s.DatabaseName, s.DefaultTableName, s.IRI AS SourceIRI, s.Description AS SourceDescription
FROM  dbo.SourceColumns AS sc INNER JOIN
         dbo.Sources AS s ON s.SourceID = sc.SourceID
GO
/****** Object:  View [dbo].[vwSimiliarSourceColumnPairs_Full]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vwSimiliarSourceColumnPairs_Full]
AS
SELECT scp.SourceColumnID1, scp.SourceColumnID2, scp.SimilarityScore, scp.Reason, s1.TableName AS TableName1, s1.ColumnName AS ColumnName1, s1.ColumnDescription AS ColumnDescription1, s2.TableName AS TableName2, s2.ColumnName, s2.ColumnDescription AS ColumnDescription2
FROM  dbo.SimilarSourceColumnPairs AS scp WITH (NOLOCK) INNER JOIN
         dbo.vwSourceColumnsFull AS s1 ON s1.SourceColumnID = scp.SourceColumnID1 INNER JOIN
         dbo.vwSourceColumnsFull AS s2 ON s2.SourceColumnID = scp.SourceColumnID2
GO
/****** Object:  UserDefinedFunction [dbo].[ParseEventSet]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "ParseEventSet",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-19",
  "Description": "Parses a named event set code (or literal comma-delimited list) into individual event names, resolving sequence sets and trimming whitespace.",
  "Utilization": "Use when you want to resolve an event-set code into its underlying events, or treat a literal comma-separated event list the same way. Helpful for normalizing event-set inputs so downstream logic can work with a rowset of event names regardless of whether the caller passed a code or a literal list.",
  "Input Parameters": [
    { "name": "@EventSet",    "type": "NVARCHAR(MAX)", "default": "NULL", "description": "EventSetCode or comma-delimited list of events; if value matches a code in EventSets and IsSequence matches, uses that definition." },
    { "name": "@IsSequence",   "type": "BIT",           "default": "0",    "description": "Flag indicating whether to resolve sequence definitions (1) or simple sets (0)." }
  ],
  "Output Notes": [
    { "name": "event", "type": "NVARCHAR(20)", "description": "Each event name from the resolved event set." }
  ],
  "Referenced objects": [
    { "name": "dbo.EventSets",   "type": "Table",           "description": "Lookup of named event sets and their comma-delimited definitions." },
    { "name": "STRING_SPLIT",    "type": "Built-in Function","description": "Splits the comma-delimited string into rows." }
  ]
}

Sample utilization:

SELECT * FROM dbo.ParseEventSet('kitchenorder', 0);
SELECT * FROM dbo.ParseEventSet('restaurantguest', 0);



Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, indexing, performance tuning, and partitioning have been simplified or omitted.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/



CREATE FUNCTION [dbo].[ParseEventSet]
(
    @EventSet NVARCHAR(MAX),
    @IsSequence BIT
)
RETURNS TABLE
AS
RETURN
(
    WITH resolved AS
    (
        SELECT
            COALESCE
            (
                (
                    SELECT TOP 1 es.[EventSet]
                    FROM [dbo].[EventSets] es
                    WHERE es.[EventSetCode] = @EventSet
                      AND es.[IsSequence] = COALESCE(@IsSequence, 0)
                ),
                @EventSet
            ) AS EventSetValue
    )
    SELECT
        TRIM(s.[value]) AS [event]
    FROM
        resolved r
        CROSS APPLY string_split(r.EventSetValue, ',') s
);
GO
/****** Object:  UserDefinedFunction [dbo].[EntryAndExitPoints]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "EntryAndExitPoints",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Identifies the entry and exit handoff points for a given event set by comparing each event in a case to its predecessor and successor, counting how often an event enters or exits the defined process.",
  "Utilization": "Use when you want to find where a defined process tends to begin and end relative to surrounding events. Helpful for boundary discovery, handoff analysis, and understanding how a process connects to upstream and downstream workflows.",
  "Input Parameters": [
    { "name": "@EventSet",               "type": "NVARCHAR(MAX)", "default": null, "description": "CSV or code defining the set of events to analyze." },
    { "name": "@enumerate_multiple_events","type": "INT",         "default": null, "description": "Flag (0/1) indicating whether to treat repeated events separately." },
    { "name": "@StartDateTime",          "type": "DATETIME",      "default": null, "description": "Lower bound of event date filter." },
    { "name": "@EndDateTime",            "type": "DATETIME",      "default": null, "description": "Upper bound of event date filter." },
    { "name": "@transforms",             "type": "NVARCHAR(MAX)", "default": null, "description": "Optional JSON transformations to apply to event names." },
    { "name": "@ByCase",                 "type": "BIT",           "default": 1,    "description": "Whether to analyze entry/exit per case (1) or across all cases (0)." },
    { "name": "@metric",                 "type": "NVARCHAR(20)",  "default": null, "description": "Metric to compute between handoff events (e.g., 'Time Between')." },
    { "name": "@CaseFilterProperties",   "type": "NVARCHAR(MAX)", "default": null, "description": "JSON filter for case-level properties." },
    { "name": "@EventFilterProperties",  "type": "NVARCHAR(MAX)", "default": null, "description": "JSON filter for event-level properties." }
  ],
  "Output Notes": [
    { "name": "EventA",       "type": "NVARCHAR(20)", "description": "Name of the preceding (entry or exit) event." },
    { "name": "EventB",       "type": "NVARCHAR(20)", "description": "Name of the succeeding (handoff or pickup) event." },
    { "name": "Mode",         "type": "NVARCHAR(10)", "description": "Either 'Entry' or 'Exit' to indicate the direction of the handoff." },
    { "name": "Description",  "type": "NVARCHAR(1000)","description": "Natural-language description of the handoff." },
    { "name": "Count",        "type": "INT",           "description": "Number of times this handoff occurs in the data." }
  ],
  "Referenced objects": [
    { "name": "dbo.EventsFact",           "type": "Table",                "description": "Raw event fact table storing case-level event sequences." },
    { "name": "dbo.ParseEventSet",        "type": "Table-Valued Function","description": "Splits and optionally codes an EventSet definition into individual events." }
  ]
}

Sample utilization:
    SELECT * 
      FROM dbo.EntryAndExitPoints('kitchenorder', 0, '2024-01-01', '2025-01-01', NULL, 1, NULL, NULL, NULL);

Note that this sproc looks at the events of the restaurantguest (dining area) and the kitchenorder event set to be under
a single case. The two event sets split the events of a case into two groups.

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/


CREATE FUNCTION [dbo].[EntryAndExitPoints]
(
    @EventSet NVARCHAR(MAX),
    @enumerate_multiple_events INT,
    @StartDateTime DATETIME,
    @EndDateTime DATETIME,
    @transforms NVARCHAR(MAX),
    @ByCase BIT = 1,
    @metric NVARCHAR(20),
    @CaseFilterProperties NVARCHAR(MAX),
    @EventFilterProperties NVARCHAR(MAX)
)
RETURNS TABLE
AS
RETURN
(
    WITH ex AS
    (
        SELECT DISTINCT
            p.[event]
        FROM dbo.ParseEventSet(@EventSet, 0) p
        WHERE @EventSet IS NOT NULL
    ),
    combined AS
    (
        SELECT
            f0.[Event] AS EventA,
            f.[Event] AS EventB,
            CAST('Entry' AS NVARCHAR(10)) AS Mode,
            COUNT(*) AS [Count]
        FROM
            dbo.EventsFact f
            JOIN dbo.EventsFact f0
                ON f0.CaseID = f.CaseID
               AND f0.CaseOrdinal = f.CaseOrdinal - 1
            JOIN ex x
                ON x.[event] = f.[Event]
            LEFT JOIN ex x0
                ON x0.[event] = f0.[Event]
        WHERE
            x0.[event] IS NULL
        GROUP BY
            f0.[Event],
            f.[Event]

        UNION ALL

        SELECT
            f.[Event] AS EventA,
            f1.[Event] AS EventB,
            CAST('Exit' AS NVARCHAR(10)) AS Mode,
            COUNT(*) AS [Count]
        FROM
            dbo.EventsFact f
            JOIN dbo.EventsFact f1
                ON f1.CaseID = f.CaseID
               AND f1.CaseOrdinal = f.CaseOrdinal + 1
            JOIN ex x
                ON x.[event] = f.[Event]
            LEFT JOIN ex x1
                ON x1.[event] = f1.[Event]
        WHERE
            x1.[event] IS NULL
        GROUP BY
            f.[Event],
            f1.[Event]
    )
    SELECT
        c.EventA,
        c.EventB,
        c.Mode,
        CASE
            WHEN c.Mode = 'Entry' THEN
                'The ' + c.EventA + ' event hands off to the ' + c.EventB + ' event as entry INTO the ' + @EventSet + ' process.'
            WHEN c.Mode = 'Exit' THEN
                'The ' + c.EventA + ' event exits the ' + @EventSet + ' process, handing off to the ' + c.EventB + ' event'
        END AS [Description],
        c.[Count]
    FROM combined c
);
GO
/****** Object:  UserDefinedFunction [dbo].[EventSetInclusion]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "EventSetInclusion",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-03-31",
  "Description": "Determines which defined event sets include all of the events from the provided EventSet expression, returning metadata about each matching set. Rewritten as an inline table-valued function for better Azure Synapse compatibility.",
  "Utilization": "Use when you have a candidate event set and want to know which named event sets already contain those events. Helpful for reuse discovery, taxonomy cleanup, and mapping a new process fragment to existing definitions.",
  "Input Parameters": [
    { "name": "@EventSet", "type": "NVARCHAR(MAX)", "default": null, "description": "Comma-separated list or code of events to test for inclusion in existing EventSets." }
  ],
  "Output Notes": [
    { "name": "EventSetKey",   "type": "VARBINARY(16)", "description": "Unique MD5-based key identifying the event set." },
    { "name": "EventSet",      "type": "NVARCHAR(MAX)", "description": "Comma-separated definition of the event set." },
    { "name": "EventSetCode",  "type": "NVARCHAR(20)",  "description": "Short code for the event set." },
    { "name": "Description",   "type": "NVARCHAR(500)", "description": "Human-readable description of the event set." },
    { "name": "IsSequence",    "type": "BIT",           "description": "Flag indicating whether the EventSet should be treated as an ordered sequence (1) or unordered set (0)." }
  ],
  "Referenced objects": [
    { "name": "dbo.EventSets",     "type": "Table",                 "description": "Master list of defined event sets with metadata." },
    { "name": "dbo.ParseEventSet", "type": "Table-Valued Function", "description": "Parses an EventSet string or code into individual event rows." }
  ]
}

Sample utilization:

    SELECT *
    FROM dbo.EventSetInclusion('served,order');

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/
CREATE   FUNCTION [dbo].[EventSetInclusion]
(
    @EventSet NVARCHAR(MAX)
)
RETURNS TABLE
AS
RETURN
(
    WITH InputEvents AS
    (
        SELECT DISTINCT
            e.[Event]
        FROM dbo.ParseEventSet(@EventSet, 0) e
    ),
    InputEventCount AS
    (
        SELECT COUNT(*) AS EventCount
        FROM InputEvents
    )
    SELECT
        es.EventSetKey,
        es.EventSet,
        es.EventSetCode,
        es.[Description],
        es.IsSequence
    FROM
        [dbo].[EventSets] es
        CROSS APPLY dbo.ParseEventSet(es.EventSet, 0) e
        CROSS JOIN InputEventCount c
    WHERE
        e.[Event] IN (SELECT [Event] FROM InputEvents)
    GROUP BY
        es.EventSetKey,
        es.EventSet,
        es.EventSetCode,
        es.[Description],
        es.IsSequence,
        c.EventCount
    HAVING
        COUNT(DISTINCT e.[Event]) = c.EventCount
);
GO
/****** Object:  View [dbo].[vwEventsFact]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vwEventsFact]
AS
SELECT e.CaseID, e.Event, e.EventDate, CONVERT(INT, CONVERT(VARCHAR(8), e.EventDate, 112)) AS DateKey, CONVERT(INT, REPLACE(CONVERT(VARCHAR(8), e.EventDate, 108), ':', '')) AS TimeKey, e.CaseOrdinal, e.EventID, e.SourceID, e.AggregationTypeID, at.Description AS AggDesc, e.CreateDate
FROM  dbo.EventsFact AS e WITH (NOLOCK) LEFT OUTER JOIN
         dbo.AggregationTypes AS at WITH (NOLOCK) ON at.AggregationTypeID = e.AggregationTypeID
GO
/****** Object:  UserDefinedFunction [dbo].[IntersegmentEvents]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Table-Valued Function": "IntersegmentEvents",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-16",
  "Description": "Retrieves all events (across any case) that occur in the timespan defined by two anchor events (EventA → EventB) for a given model or for all models if @ModelID is NULL.",
  "Utilization": "Use when you want to inspect the events that happened between two important events or segments, such as what occurred between a trigger and an outcome. Helpful for root-cause analysis, delay inspection, and story reconstruction.",
  "Input Parameters": [
    { "name": "@ModelID",  "type": "INT",            "default": NULL, "description": "Identifier of the model whose segments to inspect; NULL to search all models with that A→B segment." },
    { "name": "@EventA",   "type": "NVARCHAR(20)",    "default": NULL, "description": "Name of the 'start' event in the segment." },
    { "name": "@EventB",   "type": "NVARCHAR(20)",    "default": NULL, "description": "Name of the 'end' event in the segment." }
  ],
  "Output Notes": [
    { "name": "Seg_ModelID",     "type": "INT",       "description": "ModelID of the segment." },
    { "name": "Seg_CaseID",      "type": "INT",       "description": "CaseID where the segment occurs." },
    { "name": "Seg_EventA",      "type": "NVARCHAR(20)","description": "Anchor start event name." },
    { "name": "Seg_EventA_ID",   "type": "INT",       "description": "EventID of the start anchor." },
    { "name": "Seg_EventADate",  "type": "DATETIME2", "description": "Timestamp of the start anchor." },
    { "name": "Seg_EventB",      "type": "NVARCHAR(20)","description": "Anchor end event name." },
    { "name": "Seg_EventB_ID",   "type": "INT",       "description": "EventID of the end anchor." },
    { "name": "Seg_EventBDate",  "type": "DATETIME2", "description": "Timestamp of the end anchor." },
    { "name": "CaseID",          "type": "INT",       "description": "CaseID of any intervening event." },
    { "name": "EventID",         "type": "INT",       "description": "EventID of the intervening event." },
    { "name": "Event",           "type": "NVARCHAR(20)","description": "Name of the intervening event." },
    { "name": "EventDate",       "type": "DATETIME",  "description": "Timestamp of the intervening event." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelEvents",       "type": "Table",               "description": "Defines first-order transition segments for each model." },
    { "name": "dbo.ModelDrillThrough", "type": "Table-Valued Function","description": "Returns detailed segment boundaries (EventA → EventB) per model." },
    { "name": "dbo.vwEventsFact",      "type": "View",                "description": "Enriched EventsFact for querying event timelines." }
  ]
}

Sample utilization:

	This is a classic use case. What happened between the time someone left work to come home but ended up at the bar?

	This sample looks for all cases with a segment lv-csv1 to homedepot1. It gets the timespan between each and finds any other events from
	any other case that happens between those segments.


    -- For a specific model:
    SELECT * FROM dbo.IntersegmentEvents(24, 'lv-csv1', 'homedepot1');

    -- Across all models that contain that A→B segment:
    SELECT * FROM dbo.IntersegmentEvents(NULL, 'lv-csv1', 'homedepot1');

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, concurrency, indexing, query plan tuning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/



CREATE FUNCTION [dbo].[IntersegmentEvents]
(
    @ModelID INT,
    @EventA NVARCHAR(50),
    @EventB NVARCHAR(50)
)
RETURNS TABLE
AS
RETURN
(
    WITH ModelIDs AS
    (
        SELECT DISTINCT
            me.ModelID
        FROM
            [dbo].[ModelEvents] me (NOLOCK)
        WHERE
            @ModelID IS NULL
            AND me.EventA = @EventA
            AND me.EventB = @EventB

        UNION ALL

        SELECT
            @ModelID
        WHERE
            @ModelID IS NOT NULL
    ),
    seg AS
    (
        SELECT
            m.ModelID,
            dt.CaseID,
            dt.EventA_ID,
            dt.EventB_ID,
            dt.EventDate_A,
            dt.EventDate_B
        FROM
            ModelIDs m (NOLOCK)
            CROSS APPLY dbo.ModelDrillThrough(m.ModelID, @EventA, @EventB) dt
    )
    SELECT
        seg.ModelID AS Seg_ModelID,
        seg.CaseID AS Seg_CaseID,
        @EventA AS Seg_EventA,
        seg.EventA_ID AS Seg_EventA_ID,
        seg.EventDate_A AS Seg_EventADate,
        @EventB AS Seg_EventB,
        seg.EventB_ID AS Seg_EventB_ID,
        seg.EventDate_B AS Seg_EventBDate,
        f.CaseID,
        f.EventID,
        f.[Event],
        f.[EventDate]
    FROM
        seg
        JOIN [dbo].[vwEventsFact] f
            ON f.EventDate BETWEEN seg.EventDate_A AND seg.EventDate_B
    WHERE
        f.EventID NOT IN (seg.EventA_ID, seg.EventB_ID)
);
GO
/****** Object:  UserDefinedFunction [dbo].[EventSegments]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "EventSegments",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Finds the starting positions (CaseOrdinal indices) in each case where a given sequence of events (EventSegment) occurs within the allowed EventSet and date range.",
  "Utilization": "Use when you want to locate where an exact event segment begins inside cases, based on raw event order within a date range and event set. Helpful for finding repeated sub-processes, validating whether a known pattern occurs in cases, or using segment start positions as input to deeper drillthrough or sequence analysis.",
  "Input Parameters": [
    { "name": "@EventSegment", "type": "NVARCHAR(1000)", "default": null, "description": "Comma-separated list of events defining the target segment to locate." },
    { "name": "@EventSet",     "type": "NVARCHAR(1000)", "default": null, "description": "Comma-separated list or code of all valid events for context; used to filter EventsFact before matching." },
    { "name": "@StartDate",    "type": "DATETIME",      "default": null, "description": "Inclusive lower bound for event dates; defaults to '1900-01-01' if NULL." },
    { "name": "@EndDate",      "type": "DATETIME",      "default": null, "description": "Inclusive upper bound for event dates; defaults to '2600-12-31' if NULL." }
  ],
  "Output Notes": [
    { "name": "CaseID",     "type": "INT", "description": "Identifier of the case containing the matching segment." },
    { "name": "StartIndex","type": "INT", "description": "CaseOrdinal index where the sequence begins (1-based within the case)." }
  ],
  "Referenced objects": [
    { "name": "dbo.EventsFact",      "type": "Table",                  "description": "Stores all raw event occurrences with CaseID, Event, EventDate, CaseOrdinal." },
    { "name": "dbo.ParseEventSet",   "type": "Table-Valued Function",  "description": "Parses an event-set string or code into individual events." },
    { "name": "STRING_SPLIT",        "type": "Built-in TVF",           "description": "Splits a comma-separated string into rows." }
  ]
}

Sample utilization:

SELECT * FROM [dbo].EventSegments('greeted,seated,intro','restaurantguest',NULL,NULL)


Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/

CREATE FUNCTION [dbo].[EventSegments]
(
    @EventSegment NVARCHAR(1000), -- Comma-separated list of events to search for
    @EventSet NVARCHAR(1000),    -- Comma-separated list of all valid events in the event set
    @StartDate DATETIME,         -- Start date for filtering events
    @EndDate DATETIME            -- End date for filtering events
)
RETURNS TABLE
AS
RETURN
(

    WITH EventList AS
    (
        -- Split the comma-separated list into a table of events with their sequence numbers
        SELECT 
            TRIM(VALUE) AS EventName,
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS SequenceNumber
        FROM STRING_SPLIT(@EventSegment, ',')
    ),
    EventSet AS
    (
        -- Split the comma-separated list into a table of events with their sequence numbers
        SELECT 
            TRIM([event]) AS Event
        FROM dbo.ParseEventSet(@EventSet, NULL)
    ),
	Segs AS
	(
		SELECT 
			ef1.CaseID,elx.SequenceNumber,efx.CaseOrdinal
		FROM 
			dbo.EventsFact ef1 (NOLOCK)
			JOIN EventSet es1 ON es1.[Event] = ef1.[Event]
			JOIN EventList el1 ON el1.SequenceNumber = 1 AND el1.EventName = ef1.[Event]
			JOIN dbo.EventsFact (NOLOCK) efx ON efx.CaseID = ef1.CaseID
			JOIN EventSet esx ON esx.[Event] = efx.[Event]
			JOIN EventList elx ON elx.EventName = efx.[Event] 
								 AND elx.SequenceNumber = efx.CaseOrdinal - ef1.CaseOrdinal + 1
		WHERE
			ef1.EventDate >= COALESCE(@StartDate,'01/01/1900') 
			AND ef1.EventDate <= COALESCE(@EndDate,'12/31/2600')
	)
	SELECT
		CaseID,
		CaseOrdinal-(SELECT COUNT(*) FROM EventList)+1 AS StartIndex
	FROM
		Segs
	WHERE 
		SequenceNumber=(SELECT COUNT(*) FROM EventList)

);
GO
/****** Object:  UserDefinedFunction [dbo].[AdjacencyMatrix]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*

*** THIS TVF is deprecated as it cannot be ported to Azure Synapse. Use the sproc, sp_AdjacencyMatrix.***

Metadata JSON:
{
  "Table-Valued Function": "dbo.AdjacencyMatrix",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": "Generates an adjacency matrix from a given event set by computing, for each EventA→EventB pair, the conditional probability P(B|A), total occurrences of A, and raw counts.",
  "Utilization": "Use when you want a compact transition matrix showing how often each event in a selected event set leads to each other event, along with P(B|A), total outgoing volume from EventA, and raw transition counts. Helpful for quick process-shape inspection, adjacency-style graph building, and comparing the relative strength of event-to-event handoffs. This TVF is deprecated for Azure Synapse portability; prefer dbo.sp_AdjacencyMatrix for the supported stored-procedure path.",
  "Input Parameters": [
    { "name": "@EventSet",                "type": "NVARCHAR(MAX)", "default": "—",    "description": "Comma-separated list or code defining the set of events to include." },
    { "name": "@enumerate_multiple_events","type": "INT",            "default": "—",    "description": "1 to treat repeated events separately; 0 to collapse duplicates." },
    { "name": "@transforms",               "type": "NVARCHAR(MAX)", "default": "NULL", "description": "Optional event-mapping JSON or code for normalizing event names." }
  ],
  "Output Notes": [
    { "name": "EventA",             "type": "NVARCHAR(??)", "description": "The source event of the transition." },
    { "name": "EventB",             "type": "NVARCHAR(??)", "description": "The target event of the transition." },
    { "name": "probability",        "type": "FLOAT",         "description": "P(B|A) = count(A→B)/total count of A." },
    { "name": "Event1A_Rows",       "type": "FLOAT",         "description": "Total number of occurrences of EventA." },
    { "name": "count",              "type": "FLOAT",         "description": "Raw count of EventA→EventB transitions." }
  ],
  "Referenced objects": [
    { "name": "dbo.MarkovProcess",       "type": "Table-Valued Function", "description": "Provides raw transition rows (Rows) for given order, event set, filters, and transforms." }
  ]
}

Sample utilization:

    SELECT * FROM dbo.AdjacencyMatrix('poker', 1, NULL);
SELECT * FROM  [dbo].[AdjacencyMatrix]('restaurantguest',1,NULL)

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/

CREATE FUNCTION [dbo].[AdjacencyMatrix]
(
	@EventSet NVARCHAR(MAX),
	@enumerate_multiple_events INT,
	@transforms NVARCHAR(MAX)
)
RETURNS TABLE
	RETURN
		SELECT 
			Event1A AS [EventA],
			EventB,
			CAST(SUM([Rows]) AS FLOAT) / SUM(SUM([Rows])) OVER (PARTITION BY [Event1A]) AS probability,
			SUM(SUM([Rows])) OVER (PARTITION BY [Event1A]) as Event1A_Rows,
			CAST(SUM([Rows]) AS FLOAT) as [count]
		FROM 
			MarkovProcess(0,@EventSet,@enumerate_multiple_events,NULL,NULL,@transforms,1,NULL,NULL,NULL,NULL) mp
		GROUP BY
			Event1A,
			EventB


GO
/****** Object:  UserDefinedFunction [dbo].[BayesianRelationships_Full]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "dbo.BayesianRelationships_Full",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": "Produces a flattened table of all Bayesian probability relationships, enriched with event-set labels, anomaly category codes, and metric metadata for use in downstream graph generation.",
  "Utilization": "Use when you want a flattened, analysis-ready list of Bayesian relationships across models, including the resolved event sets, anomaly-category labels, and metric names. Helpful for graph loading, metadata browsing, reporting, or downstream queries that need Bayesian relationships without repeatedly joining BayesianProbabilities to Models, EventSets, anomaly categories, and Metrics.",
  "Input Parameters": [],
  "Output Notes": [
    { "name": "ModelID",               "type": "INT",    "description": "Identifier of the Bayesian model." },
    { "name": "GroupType",             "type": "NVARCHAR",   "description": "Grouping dimension (CASEID/DAY/MONTH/YEAR)." },
    { "name": "EventSetA",             "type": "NVARCHAR",   "description": "Comma-separated events in sequence A." },
    { "name": "EventSetB",             "type": "NVARCHAR",   "description": "Comma-separated events in sequence B." },
    { "name": "ACount",                "type": "INT",    "description": "Count of cases containing sequence A." },
    { "name": "BCount",                "type": "INT",    "description": "Count of cases containing sequence B." },
    { "name": "A_Int_BCount",          "type": "INT",    "description": "Count of cases containing both A and B." },
    { "name": "PB|A",                  "type": "FLOAT",  "description": "P(B|A) conditional probability." },
    { "name": "PA|B",                  "type": "FLOAT",  "description": "P(A|B) conditional probability." },
    { "name": "TotalCases",            "type": "INT",    "description": "Total number of distinct cases." },
    { "name": "PA",                    "type": "FLOAT",  "description": "Marginal probability of A." },
    { "name": "PB",                    "type": "FLOAT",  "description": "Marginal probability of B." },
    { "name": "CreateDate",            "type": "DATETIME","description": "Timestamp when the probability row was created." },
    { "name": "LastUpdate",            "type": "DATETIME","description": "Timestamp of the last update." },
    { "name": "AnomalyCategoryIDA",    "type": "INT",    "description": "Foreign key to the first anomaly category." },
    { "name": "AnomalyCategoryA",      "type": "NVARCHAR","description": "Code of the first anomaly category." },
    { "name": "AnomalyCategoryIDB",    "type": "INT",    "description": "Foreign key to the second anomaly category." },
    { "name": "AnomalyCategoryB",      "type": "NVARCHAR","description": "Code of the second anomaly category." },
    { "name": "MetricID",              "type": "INT",    "description": "Identifier of the metric used." },
    { "name": "Metric",                "type": "NVARCHAR","description": "Name of the metric used." }
  ],
  "Referenced objects": [
    { "name": "dbo.BayesianProbabilities",   "type": "Table",                "description": "Stores computed Bayesian metrics." },
    { "name": "dbo.Models",                  "type": "Table",                "description": "Model metadata including metric references." },
    { "name": "dbo.DimAnomalyCategories",    "type": "Table",                "description": "Reference table of anomaly categories." },
    { "name": "dbo.EventSets",               "type": "Table",                "description": "Lookup of event-set definitions and keys." },
    { "name": "dbo.Metrics",                 "type": "Table",                "description": "Lookup of metric definitions." }
  ]
}

Sample utilization:

    SELECT * FROM dbo.BayesianRelationships_Full();

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/

CREATE FUNCTION [dbo].[BayesianRelationships_Full]
(	

)
RETURNS TABLE 
AS
RETURN 
(
SELECT bp.[ModelID]
      ,[GroupType]
      ,esA.EventSet AS EventSetA
      ,esB.EventSet AS EventSetB
      ,[ACount]
      ,[BCount]
      ,[A_Int_BCount]
      ,[PB|A]
      ,[PA|B]
      ,[TotalCases]
      ,[PA]
      ,[PB]
      ,bp.[CreateDate]
	  ,bp.[LastUpdate]
      ,bp.[AnomalyCategoryIDA]
	  ,acA.[Code] AS AnomalyCategoryA
      ,bp.[AnomalyCategoryIDB]
	  ,acB.[Code] AS AnomalyCategoryB
	  ,m.MetricID
	  ,met.Metric
  FROM [dbo].[BayesianProbabilities] bp (NOLOCK)
  JOIN Models m ON m.modelid=bp.ModelID
  JOIN [dbo].[DimAnomalyCategories] acA (NOLOCK) ON acA.[AmomalyCategoryID]=bp.[AnomalyCategoryIDA]
  JOIN [dbo].[DimAnomalyCategories] acB (NOLOCK) ON acB.[AmomalyCategoryID]=bp.[AnomalyCategoryIDB]
  JOIN [dbo].[EventSets] esA (NOLOCK) ON esA.EventSetKey=bp.EventSetAKey
  JOIN [dbo].[EventSets] esB (NOLOCK) ON esB.EventSetKey=bp.EventSetBKey
  JOIN [dbo].[Metrics] met (NOLOCK) ON met.MetricID=m.MetricID
)
GO
/****** Object:  UserDefinedFunction [dbo].[CaseTypeListForEventSets]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "dbo.CaseTypeListForEventSets",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": "Retrieves, for each EventSetKey, the distinct CaseType names that have events belonging to that event set, aggregated into a pipe-delimited list.",
  "Utilization": "Use when you want to know which case types are associated with which event sets, especially for metadata browsing, documentation, and event-set governance.",
  "Input Parameters": [],
  "Output Notes": [
    { "name": "EventSetKey",    "type": "VARBINARY(16)", "description": "Unique key identifying an event set." },
    { "name": "CaseTypeList",   "type": "NVARCHAR(MAX)",   "description": "Pipe ('|')-delimited list of case type names using events in the set." }
  ],
  "Referenced objects": [
    { "name": "dbo.EventSets",              "type": "Table",                 "description": "Holds event set definitions and keys." },
    { "name": "STRING_SPLIT",               "type": "Built-in TVF",           "description": "Splits comma-separated EventSet into individual events." },
    { "name": "dbo.EventsFact",             "type": "Table",                 "description": "Fact table of all events with CaseID and Event name." },
    { "name": "dbo.Cases",                  "type": "Table",                 "description": "Contains CaseID and CaseTypeID." },
    { "name": "dbo.CaseTypes",              "type": "Table",                 "description": "Lookup of case type names by CaseTypeID." },
    { "name": "STRING_AGG",                 "type": "Built-in Aggregate",    "description": "Aggregates case type names into a delimited string." }
  ]
}

Sample utilization:

    SELECT * FROM dbo.CaseTypeListForEventSets();

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing,
      query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE FUNCTION [dbo].[CaseTypeListForEventSets]
(	

)
RETURNS TABLE 
AS
RETURN 
(
WITH SplitEvents AS (
    SELECT 
		es.EventSetKey,
        [value] AS [Event]
    FROM
        [dbo].[EventSets] es
		CROSS APPLY STRING_SPLIT(es.EventSet, ',') -- Split the EventSet string into individual events

), ct AS (
SELECT
	se.EventSetKey,
	ct.[Name],
	COUNT(DISTINCT c.CaseID) AS [Count]
FROM
    SplitEvents se
JOIN
    [dbo].[EventsFact] f ON f.Event = se.Event -- Join with EventsFact on Event
JOIN
    [dbo].[Cases] c ON c.CaseID = f.CaseID -- Join Cases on CaseID
JOIN
    [dbo].[CaseTypes] ct ON ct.CaseTypeID = c.CaseTypeID -- Join CaseTypes on CaseTypeID
group by se.EventSetKey,ct.[Name]
)
SELECT
	ct.EventSetKey,
    STRING_AGG([Name], '|') AS CaseTypeList,
	ct.[Count] AS [CasesUsingEventSet],
	es.EventSet,
	es.EventSetCode
FROM
	ct ct
	JOIN EventSets es ON  es.EventSetKey=ct.EventSetKey
group by ct.eventsetkey,ct.[Count] ,	es.EventSet,
	es.EventSetCode

)
GO
/****** Object:  UserDefinedFunction [dbo].[DecodeAccessBitmap]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "dbo.DecodeAccessBitmap",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": "Takes a BIGINT bitmask and returns each AccessID with its description and whether that bit is set (granted).",
  "Utilization": "Use when you need to translate an access bitmap into a more readable form for debugging, auditing, administration, or user-explainer output.",
  "Input Parameters": [
    { "name": "@AccessBitmap", "type": "BIGINT", "default": null, "description": "Bitmap where each bit corresponds to an Access.AccessID." }
  ],
  "Output Notes": [
    { "name": "AccessID",     "type": "INT",   "description": "Identifier of the access right." },
    { "name": "Description",  "type": "NVARCHAR", "description": "Human-readable description of the access right." },
    { "name": "Granted",      "type": "BIT",    "description": "1 if the corresponding bit in @AccessBitmap is set; otherwise 0." }
  ],
  "Referenced objects": [
    { "name": "dbo.Access", "type": "Table", "description": "Lookup table of all possible access rights with AccessID and Description." }
  ]
}

Sample utilization:

    SELECT * FROM dbo.DecodeAccessBitmap(6);

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE FUNCTION [dbo].[DecodeAccessBitmap]
(	
@AccessBitmap BIGINT
)
RETURNS TABLE 
AS
RETURN 
(
	-- Add the SELECT statement with parameter references here
	SELECT
		a.AccessID,
		a.[Description],
		CASE WHEN @AccessBitmap & POWER(CAST(2 AS BIGINT),a.AccessID-1)=POWER(CAST(2 AS BIGINT),a.AccessID-1) THEN 1 ELSE 0 END AS Granted
	FROM
		[dbo].[Access] a
)
GO
/****** Object:  UserDefinedFunction [dbo].[EventPropertiesSource]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "EventPropertiesSource",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Retrieves all metadata about properties associated with a specific event, including property values, source table/column context, case natural key, and associated date column information.",
  "Utilization": "Use when you need to understand which source columns or source systems contribute particular event properties, especially for lineage, mapping, and semantic cleanup.",
  "Input Parameters": [
    { "name": "@EventID", "type": "BIGINT", "default": null, "description": "Identifier of the event whose properties are to be returned." }
  ],
  "Output Notes": [
    { "name": "EventID",               "type": "BIGINT",      "description": "Identifier of the event." },
    { "name": "Event",                 "type": "NVARCHAR(20)", "description": "Name of the event." },
    { "name": "EventDate",             "type": "DATETIME",     "description": "Timestamp when the event occurred." },
    { "name": "CaseID",                "type": "INT",          "description": "Identifier of the case containing the event." },
    { "name": "PropertyName",          "type": "NVARCHAR(50)", "description": "Name of the property." },
    { "name": "PropertyValueNumeric",  "type": "FLOAT",        "description": "Numeric value of the property, if applicable." },
    { "name": "PropertyValueAlpha",    "type": "NVARCHAR(50)", "description": "Alphanumeric value of the property, if applicable." },
    { "name": "Property_Table_Name",   "type": "NVARCHAR(128)","description": "Name of the source table for the property." },
    { "name": "Property_Column",       "type": "NVARCHAR(128)","description": "Name of the source column for the property." },
    { "name": "Property_DBName",       "type": "NVARCHAR(400)", "description": "Database name where the property source resides." },
    { "name": "Case_NaturalKey",       "type": "NVARCHAR(100)", "description": "Natural key of the case for lookup." },
    { "name": "NaturalKey_Table_Name", "type": "NVARCHAR(128)", "description": "Source table name for the case natural key." },
    { "name": "NaturalKey_Column",     "type": "NVARCHAR(128)", "description": "Source column name for the case natural key." },
    { "name": "NaturalKey_DBName",     "type": "NVARCHAR(400)", "description": "Database name where the case natural key source resides." },
    { "name": "NaturalKey_ServerName", "type": "NVARCHAR(400)", "description": "Server name where the case natural key source resides." },
    { "name": "Date_Column",           "type": "NVARCHAR(128)", "description": "Source column name for the case date field." }
  ],
  "Referenced objects": [
    { "name": "dbo.EventPropertiesParsed", "type": "Table",                  "description": "Parsed property values per event." },
    { "name": "dbo.EventsFact",            "type": "Table",                  "description": "Raw event occurrences." },
    { "name": "dbo.Cases",                 "type": "Table",                  "description": "Case header information including natural key and date source columns." },
    { "name": "dbo.SourceColumns",         "type": "Table",                  "description": "Metadata about source table columns." },
    { "name": "dbo.Sources",               "type": "Table",                  "description": "Metadata about data sources (server, database, table)." }
  ]
}

Sample utilization:

  SELECT *
    FROM dbo.EventPropertiesSource(435820);

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/

CREATE FUNCTION [dbo].[EventPropertiesSource]
(	
@EventID BIGINT
)
RETURNS TABLE 
AS
RETURN 
(

	SELECT 
		e.EventID,
		e.[Event],
		e.[EventDate],
		e.CaseID,
		ep.PropertyName,
		ep.PropertyValueNumeric,
		ep.PropertyValueAlpha,
		scc.TableName AS [Property_Table_Name],
		scc.ColumnName AS [Property_Column],
		sc.DatabaseName AS Property_DBName,
		c.NaturalKey AS [Case_NaturalKey],
		sc.ServerName AS [Property_ServerName],
		scn.TableName AS [NaturalKey_Table_Name],
		scn.ColumnName AS [NaturalKey_Column],
		sn.DatabaseName AS NaturalKey_DBName,
		sn.ServerName AS [NaturalKey_ServerName],
		sdc.ColumnName AS [Date_Column]
	FROM 
		EventPropertiesParsed ep
		JOIN EventsFact e ON e.EventID=ep.EventID
		JOIN Cases c ON c.CaseID=e.CaseID
		LEFT JOIN SourceColumns scn ON scn.SourceColumnID=c.[NaturalKey_SourceColumnID]
		LEFT JOIN Sources sn ON sn.SourceID=scn.SourceID
		LEFT JOIN SourceColumns scc ON scc.SourceColumnID=ep.SourceColumnID
		LEFT JOIN Sources sc ON sc.SourceID=scc.SourceID
		LEFT JOIN SourceColumns sdc ON sdc.SourceColumnID=c.Date_SourceColumnID
		LEFT JOIN Sources sd ON sd.SourceID=sdc.SourceID
	WHERE 
		ep.EventID=@EventID
)
GO
/****** Object:  UserDefinedFunction [dbo].[FindModelSequence_retire]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Eugene Asahara
-- Create date: March 13, 2023
-- Description:	Return rows from the ModelSequences table, filtered by a portion of the sequence.
-- =============================================
/*

January 14, 2025 - retired in favor of EventSegments. The ModelSequences feature is optional because it
takes a lot of time to process and there's much to store. EventSegments gets information from EventsFacts and avoids the
LIKE function this uses.

In order to be performant, this looks through ModelSequences, sequences we've cached.

SELECT * FROM [dbo].[FindModelSequence]('intro,order')
*/
CREATE FUNCTION [dbo].[FindModelSequence_retire]
(	
	@SeqFragment NVARCHAR(2000)
)
RETURNS TABLE 
AS
RETURN 
(

	-- Add the SELECT statement with parameter references here
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
		,[TermRows]
		,[Cases]
		,ms.[ModelID]
	FROM	
		[dbo].[ModelSequences] ms
		JOIN Models m ON ms.ModelID=m.modelid
		JOIN [dbo].[Metrics] mt ON mt.MetricID=m.MetricID
	WHERE
		ms.[Seq] LIKE '%'+@SeqFragment+'%'
)
GO
/****** Object:  UserDefinedFunction [dbo].[getTimeMoleculesObjectMetadata]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Table-Valued Function": "dbo.getTimeMoleculesObjectMetadata",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-04-03",
  "Description": "Scans SQL module definitions in the TimeSolution database, extracts embedded Metadata JSON blocks from object comments, and returns both the raw JSON and selected parsed fields for easier browsing and governance.",
  "Utilization": "Use when you want a searchable inventory of Time Molecules database objects and their embedded metadata. Helpful for documentation, governance, object catalogs, quality checks, and building tooling that can reason over object descriptions, parameters, and referenced objects.",
  "Input Parameters": [],
  "Output Notes": [
    { "name": "ObjectType", "type": "NVARCHAR(60)", "description": "SQL Server object type description from sys.objects, such as SQL_SCALAR_FUNCTION, SQL_TABLE_VALUED_FUNCTION, or SQL_STORED_PROCEDURE." },
    { "name": "ObjectName", "type": "NVARCHAR(258)", "description": "Two-part object name in [schema].[object] form." },
    { "name": "RawJson", "type": "NVARCHAR(MAX)", "description": "The raw Metadata JSON text extracted from the module definition between the markers." },
    { "name": "Author", "type": "NVARCHAR(4000)", "description": "Author value parsed from the metadata JSON." },
    { "name": "Contact", "type": "NVARCHAR(4000)", "description": "Contact value parsed from the metadata JSON." },
    { "name": "Last Update", "type": "NVARCHAR(4000)", "description": "Last update value parsed from the metadata JSON." },
    { "name": "Description", "type": "NVARCHAR(MAX)", "description": "Description value parsed from the metadata JSON, returned either as a scalar string or JSON array text." },
    { "name": "Utilization", "type": "NVARCHAR(4000)", "description": "Utilization value parsed from the metadata JSON." },
    { "name": "ParametersJson", "type": "NVARCHAR(MAX)", "description": "JSON array of input parameters from the metadata block." },
    { "name": "OutputNotes", "type": "NVARCHAR(MAX)", "description": "Output notes from the metadata block, returned either as JSON array text or scalar text." },
    { "name": "ReferencedObjectsJson", "type": "NVARCHAR(MAX)", "description": "JSON array describing referenced objects from the metadata block." }
  ],
  "Referenced objects": [
    { "name": "sys.objects", "type": "System Catalog View", "description": "Provides object metadata, including object type and object_id." },
    { "name": "sys.sql_modules", "type": "System Catalog View", "description": "Provides the SQL definition text for programmable objects." },
    { "name": "JSON_VALUE", "type": "Built-in Function", "description": "Extracts scalar values from the embedded Metadata JSON." },
    { "name": "JSON_QUERY", "type": "Built-in Function", "description": "Extracts JSON arrays or objects from the embedded Metadata JSON." },
    { "name": "ISJSON", "type": "Built-in Function", "description": "Validates whether the extracted text is valid JSON before parsing." },
    { "name": "CHARINDEX", "type": "Built-in Function", "description": "Finds the metadata markers inside object definitions." },
    { "name": "SUBSTRING", "type": "Built-in Function", "description": "Extracts the raw metadata JSON text from the module definition." }
  ]
}
Sample Utilization:
    SELECT *
    FROM dbo.getTimeMoleculesObjectMetadata()
    ORDER BY ObjectType, ObjectName;
    SELECT *
    FROM dbo.getTimeMoleculesObjectMetadata()
    WHERE [Utilization] IS NOT NULL;
Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: metadata parsing depends on comment conventions and marker text remaining consistent across object definitions.
    • Objects without both 'Metadata JSON:' and 'Sample Utilization:' markers, or with invalid JSON between them, are excluded.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).
License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
Notes:
Remember that the start and end tags of the JSON cannot be mentioned or the metadata will not be found.
*/
CREATE FUNCTION [dbo].[getTimeMoleculesObjectMetadata]()
RETURNS TABLE
AS
RETURN
(
    WITH BaseMetadata AS
    (
        SELECT
            meta.ObjectType,
            meta.ObjectName,
            meta.RawJson,
            JSON_VALUE(meta.RawJson, '$.Author') AS Author,
            JSON_VALUE(meta.RawJson, '$.Contact') AS Contact,
            JSON_VALUE(meta.RawJson, '$."Last Update"') AS [Last Update],
            CASE
                WHEN meta.ObjectType='SQL_STORED_PROCEDURE' THEN 'Stored procedure, '
                WHEN meta.ObjectType IN ('SQL_INLINE_TABLE_VALUED_FUNCTION','SQL_TABLE_VALUED_FUNCTION') THEN 'Table-valued function'
                WHEN meta.ObjectType='VIEW' THEN 'View'
                WHEN meta.ObjectType='SQL_SCALAR_FUNCTION' THEN 'Scalar function'
                ELSE 'Database object '
            END +
            ', '+meta.ObjectName+': '+
            COALESCE(
                JSON_QUERY(meta.RawJson, '$.Description'),
                JSON_VALUE(meta.RawJson, '$.Description')
            ) AS Description,
            CASE
                WHEN ISJSON(meta.RawJson) = 1 THEN JSON_VALUE(meta.RawJson, '$.Utilization')
                ELSE NULL
            END AS [Utilization],
            JSON_QUERY(meta.RawJson, '$."Input Parameters"') AS ParametersJson,
            CASE
                WHEN JSON_QUERY(meta.RawJson, '$."Output Notes"') IS NOT NULL
                    THEN JSON_QUERY(meta.RawJson, '$."Output Notes"')
                ELSE JSON_VALUE(meta.RawJson, '$."Output Notes"')
            END AS OutputNotes,
            JSON_QUERY(meta.RawJson, '$."Referenced objects"') AS ReferencedObjectsJson,
            meta.SampleCode                                   -- ← NEW COLUMN
        FROM
        (
            SELECT
                o.type_desc AS ObjectType,
                QUOTENAME(OBJECT_SCHEMA_NAME(o.object_id)) + '.' + QUOTENAME(o.name) AS ObjectName,
                CASE
                    WHEN CHARINDEX('Metadata JSON:', m.definition) > 0
                     AND CHARINDEX(
                            'Sample Utilization:',
                            m.definition,
                            CHARINDEX('Metadata JSON:', m.definition)
                         ) > CHARINDEX('Metadata JSON:', m.definition)
                    THEN LTRIM(RTRIM(
                        SUBSTRING(
                            m.definition,
                            CHARINDEX('Metadata JSON:', m.definition) + LEN('Metadata JSON:'),
                            CHARINDEX(
                                'Sample Utilization:',
                                m.definition,
                                CHARINDEX('Metadata JSON:', m.definition)
                            ) - (
                                CHARINDEX('Metadata JSON:', m.definition) + LEN('Metadata JSON:')
                            )
                        )
                    ))
                    ELSE NULL
                END AS RawJson,

                -- ================== NEW: SampleCode extraction ==================
                CASE
                    WHEN CHARINDEX('Sample Utilization:', m.definition) > 0
                     AND CHARINDEX(
                            'Context:',
                            m.definition,
                            CHARINDEX('Sample Utilization:', m.definition)
                         ) > CHARINDEX('Sample Utilization:', m.definition)
                    THEN LTRIM(RTRIM(
                        SUBSTRING(
                            m.definition,
                            CHARINDEX('Sample Utilization:', m.definition) + LEN('Sample Utilization:'),
                            CHARINDEX(
                                'Context:',
                                m.definition,
                                CHARINDEX('Sample Utilization:', m.definition)
                            ) - (
                                CHARINDEX('Sample Utilization:', m.definition) + LEN('Sample Utilization:')
                            )
                        )
                    ))
                    ELSE NULL
                END AS SampleCode
            FROM sys.objects o
            INNER JOIN sys.sql_modules m
                ON m.object_id = o.object_id
            WHERE
                o.is_ms_shipped = 0
                AND o.type IN ('P','FN','TF','IF')
        ) meta
        WHERE
            meta.RawJson IS NOT NULL
            AND ISJSON(meta.RawJson) = 1
    ),
    ParameterEntries AS
    (
        SELECT
            CAST('INPUT_PARAMETER' AS NVARCHAR(60)) AS ObjectType,
            CAST(
                b.ObjectName + '.' +
                COALESCE(JSON_VALUE(p.value, '$.name'), '[unknown]')
                AS NVARCHAR(258)
            ) AS ObjectName,
            CAST(NULL AS NVARCHAR(MAX)) AS RawJson,
            CAST(NULL AS NVARCHAR(4000)) AS Author,
            CAST(NULL AS NVARCHAR(4000)) AS Contact,
            CAST(NULL AS NVARCHAR(4000)) AS [Last Update],
            CAST(
                'Parent Object: ' + b.ObjectName +
                CHAR(10) + 'Parameter: ' + COALESCE(JSON_VALUE(p.value, '$.name'), '[unknown]') +
                CHAR(10) + 'Type: ' + COALESCE(JSON_VALUE(p.value, '$.type'), '[unknown]') +
                CHAR(10) + 'Default: ' + COALESCE(JSON_VALUE(p.value, '$.default'), '[none]') +
                CHAR(10) + 'Description: ' + COALESCE(JSON_VALUE(p.value, '$.description'), '[none]')
                AS NVARCHAR(MAX)
            ) AS Description,
            CAST(NULL AS NVARCHAR(4000)) AS Utilization,
            CAST(NULL AS NVARCHAR(MAX)) AS ParametersJson,
            CAST(NULL AS NVARCHAR(MAX)) AS OutputNotes,
            CAST(NULL AS NVARCHAR(MAX)) AS ReferencedObjectsJson,
            CAST(NULL AS NVARCHAR(MAX)) AS SampleCode          -- ← NEW
        FROM BaseMetadata b
        CROSS APPLY OPENJSON(b.ParametersJson) p
        WHERE JSON_VALUE(p.value, '$.description') IS NOT NULL
    ),
    OutputEntries AS
    (
        SELECT
            CAST('OUTPUT_PARAMETER' AS NVARCHAR(60)) AS ObjectType,
            CAST(
                b.ObjectName + '.' +
                COALESCE(JSON_VALUE(o.value, '$.name'), '[unknown]')
                AS NVARCHAR(258)
            ) AS ObjectName,
            CAST(NULL AS NVARCHAR(MAX)) AS RawJson,
            CAST(NULL AS NVARCHAR(4000)) AS Author,
            CAST(NULL AS NVARCHAR(4000)) AS Contact,
            CAST(NULL AS NVARCHAR(4000)) AS [Last Update],
            CAST(
                'Parent Object: ' + b.ObjectName +
                CHAR(10) + 'Output: ' + COALESCE(JSON_VALUE(o.value, '$.name'), '[unknown]') +
                CHAR(10) + 'Type: ' + COALESCE(JSON_VALUE(o.value, '$.type'), '[unknown]') +
                CHAR(10) + 'Description: ' + COALESCE(JSON_VALUE(o.value, '$.description'), '[none]')
                AS NVARCHAR(MAX)
            ) AS Description,
            CAST(NULL AS NVARCHAR(4000)) AS Utilization,
            CAST(NULL AS NVARCHAR(MAX)) AS ParametersJson,
            CAST(NULL AS NVARCHAR(MAX)) AS OutputNotes,
            CAST(NULL AS NVARCHAR(MAX)) AS ReferencedObjectsJson,
            CAST(NULL AS NVARCHAR(MAX)) AS SampleCode          -- ← NEW
        FROM BaseMetadata b
        CROSS APPLY OPENJSON(b.OutputNotes) o
        WHERE JSON_VALUE(o.value, '$.description') IS NOT NULL
    ),
    ReferencedObjectEntries AS
    (
        SELECT
            CAST('REFERENCED_OBJECT' AS NVARCHAR(60)) AS ObjectType,
            CAST(
                b.ObjectName + '.' +
                COALESCE(JSON_VALUE(r.value, '$.name'), '[unknown]')
                AS NVARCHAR(258)
            ) AS ObjectName,
            CAST(NULL AS NVARCHAR(MAX)) AS RawJson,
            CAST(NULL AS NVARCHAR(4000)) AS Author,
            CAST(NULL AS NVARCHAR(4000)) AS Contact,
            CAST(NULL AS NVARCHAR(4000)) AS [Last Update],
            CAST(
                'Parent Object: ' + b.ObjectName +
                CHAR(10) + 'Referenced Object: ' + COALESCE(JSON_VALUE(r.value, '$.name'), '[unknown]') +
                CHAR(10) + 'Type: ' + COALESCE(JSON_VALUE(r.value, '$.type'), '[unknown]') +
                CHAR(10) + 'Description: ' + COALESCE(JSON_VALUE(r.value, '$.description'), '[none]')
                AS NVARCHAR(MAX)
            ) AS Description,
            CAST(NULL AS NVARCHAR(4000)) AS Utilization,
            CAST(NULL AS NVARCHAR(MAX)) AS ParametersJson,
            CAST(NULL AS NVARCHAR(MAX)) AS OutputNotes,
            CAST(NULL AS NVARCHAR(MAX)) AS ReferencedObjectsJson,
            CAST(NULL AS NVARCHAR(MAX)) AS SampleCode          -- ← NEW
        FROM BaseMetadata b
        CROSS APPLY OPENJSON(b.ReferencedObjectsJson) r
        WHERE JSON_VALUE(r.value, '$.description') IS NOT NULL
    ),
    ViewMetadata AS
    (
        SELECT
            CAST(v.type_desc AS NVARCHAR(60)) AS ObjectType,
            QUOTENAME(s.name) + '.' + QUOTENAME(v.name) AS ObjectName,
            CAST(NULL AS NVARCHAR(MAX)) AS RawJson,
            CAST(NULL AS NVARCHAR(4000)) AS Author,
            CAST(NULL AS NVARCHAR(4000)) AS Contact,
            CAST(NULL AS NVARCHAR(4000)) AS [Last Update],
            CAST(v.type_desc COLLATE DATABASE_DEFAULT AS NVARCHAR(MAX)) + ' Name: ' +
				CAST(s.name COLLATE DATABASE_DEFAULT AS NVARCHAR(MAX)) +
				CAST(N'.' AS NVARCHAR(MAX)) +
				CAST(v.name COLLATE DATABASE_DEFAULT AS NVARCHAR(MAX)) +
				CAST(N': ' AS NVARCHAR(MAX)) +
				CAST(COALESCE(CAST(ep.[value] AS NVARCHAR(MAX)), N'') COLLATE DATABASE_DEFAULT AS NVARCHAR(MAX)) + 
				COALESCE(dbo.GetViewColumns(QUOTENAME(s.name) + '.' + QUOTENAME(v.name) ),'')
			AS [Description],
            CAST(NULL  AS NVARCHAR(4000)) AS Utilization,
            CAST(NULL AS NVARCHAR(MAX)) AS ParametersJson,
            CAST(NULL AS NVARCHAR(MAX)) AS OutputNotes,
            CAST(NULL AS NVARCHAR(MAX)) AS ReferencedObjectsJson,
            CAST(NULL AS NVARCHAR(MAX)) AS SampleCode          -- ← NEW
        FROM sys.views v
        INNER JOIN sys.schemas s
            ON s.schema_id = v.schema_id
        LEFT JOIN sys.extended_properties ep
            ON ep.major_id = v.object_id
           AND ep.minor_id = 0
           AND ep.name = 'MS_Description'
        WHERE
            v.is_ms_shipped = 0
    )
    SELECT
        ObjectType,
        ObjectName,
        RawJson,
        Author,
        Contact,
        [Last Update],
        Description,
        Utilization,
        ParametersJson,
        OutputNotes,
        ReferencedObjectsJson,
        SampleCode                                          -- ← NEW
    FROM BaseMetadata
    UNION ALL
    SELECT
        ObjectType,
        ObjectName,
        RawJson,
        Author,
        Contact,
        [Last Update],
        Description,
        Utilization,
        ParametersJson,
        OutputNotes,
        ReferencedObjectsJson,
        SampleCode                                          -- ← NEW
    FROM ParameterEntries
    UNION ALL
    SELECT
        ObjectType,
        ObjectName,
        RawJson,
        Author,
        Contact,
        [Last Update],
        Description,
        Utilization,
        ParametersJson,
        OutputNotes,
        ReferencedObjectsJson,
        SampleCode                                          -- ← NEW
    FROM OutputEntries
    UNION ALL
    SELECT
        ObjectType,
        ObjectName,
        RawJson,
        Author,
        Contact,
        [Last Update],
        Description,
        Utilization,
        ParametersJson,
        OutputNotes,
        ReferencedObjectsJson,
        SampleCode                                          -- ← NEW
    FROM ReferencedObjectEntries
    UNION ALL
    SELECT
        ObjectType,
        ObjectName,
        RawJson,
        Author,
        Contact,
        [Last Update],
        Description,
        Utilization,
        ParametersJson,
        OutputNotes,
        ReferencedObjectsJson,
        SampleCode                                          -- ← NEW
    FROM ViewMetadata
);
GO
/****** Object:  UserDefinedFunction [dbo].[HiddenMarkovModels]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "HiddenMarkovModels",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-03-31",
  "Description": "Returns a unified list of transition probabilities for both Bayesian and standard Markov models, filtered to single-event sequences for hidden Markov model comparison. Rewritten as an inline table-valued function for better Azure Synapse compatibility.",
  "Utilization": "Use when you want a Hidden Markov-style view or related state-sequence output for analysis, especially when exploring latent-state interpretations of observed event sequences.",
  "Input Parameters": [],
  "Output Notes": [
    { "name": "ModelID",       "type": "INT",           "description": "Identifier of the model." },
    { "name": "ModelType",     "type": "NVARCHAR(50)",  "description": "Type of the model (e.g., 'BayesianProbability' or other Markov type)." },
    { "name": "ParamHash",     "type": "VARBINARY(16)", "description": "Hash key representing the model parameters (e.g., event set and transforms keys)." },
    { "name": "EventA",        "type": "NVARCHAR(50)",  "description": "Source event in the transition." },
    { "name": "EventB",        "type": "NVARCHAR(50)",  "description": "Target event in the transition." },
    { "name": "Probability",   "type": "FLOAT",         "description": "Transition probability P(B|A)." }
  ],
  "Referenced objects": [
    { "name": "dbo.BayesianProbabilities", "type": "Table", "description": "Stores computed Bayesian probabilities between event sets." },
    { "name": "dbo.Models",                "type": "Table", "description": "Model metadata including type and parameter hash." },
    { "name": "dbo.EventSets",             "type": "Table", "description": "Defines event sets and their keys." },
    { "name": "dbo.ModelEvents",           "type": "Table", "description": "Stores standard Markov transition probabilities between events." }
  ]
}

Sample utilization:

    SELECT *
    FROM dbo.HiddenMarkovModels()
    ORDER BY ParamHash;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/
CREATE   FUNCTION [dbo].[HiddenMarkovModels]
(
)
RETURNS TABLE
AS
RETURN
(
    WITH Bayes AS
    (
        SELECT
            m.ModelID,
            m.ModelType,
            m.ParamHash,
            esa.[EventSet] AS EventA,
            esb.[EventSet] AS EventB,
            bp.[PB|A] AS Probability
        FROM
            [dbo].[BayesianProbabilities] bp
            JOIN [dbo].[Models] m
                ON m.ModelID = bp.ModelID
            JOIN [dbo].[EventSets] esa
                ON esa.EventSetKey = bp.EventSetAKey
            JOIN [dbo].[EventSets] esb
                ON esb.EventSetKey = bp.EventSetBKey
        WHERE
            esa.[Length] = 1
            AND esb.[Length] = 1
    )
    SELECT
        b.ModelID,
        b.ModelType,
        b.ParamHash,
        b.EventA,
        b.EventB,
        b.Probability
    FROM
        Bayes b

    UNION ALL

    SELECT
        m.ModelID,
        m.ModelType,
        m.ParamHash,
        me.EventA,
        me.EventB,
        me.Prob AS Probability
    FROM
        [dbo].[ModelEvents] me
        JOIN [dbo].[Models] m
            ON m.ModelID = me.ModelID
    WHERE
        NOT EXISTS
        (
            SELECT 1
            FROM Bayes b
            WHERE
                b.ModelType = 'BayesianProbability'
                AND b.ParamHash = m.ParamHash
                AND b.EventA = me.EventA
                AND b.EventB = me.EventB
        )
);
GO
/****** Object:  UserDefinedFunction [dbo].[ModelEventAnomalies]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "ModelEventAnomalies",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-16",
  "Description": "Returns all detected anomalies (metric outliers and low-prob transitions) for each event pair in the specified Markov model, including observed metric values, z-scores, and transition probabilities.",
  "Utilization": "Use when you want anomaly-oriented model event output, especially to find unusual transitions, outlier timing, or segments whose behavior differs from expectations.",
  "Input Parameters": [
    { "name": "@ModelID", "type": "INT", "default": null, "description": "Identifier of the Markov model whose anomalies should be retrieved." }
  ],
  "Output Notes": [
    { "name": "ModelID",        "type": "INT",           "description": "Markov model identifier." },
    { "name": "CaseID",         "type": "INT",           "description": "Case identifier where the anomaly occurred." },
    { "name": "EventIDA",       "type": "INT",           "description": "Internal ID of the prior event in the transition." },
    { "name": "EventIDB",       "type": "INT",           "description": "Internal ID of the subsequent event in the transition." },
    { "name": "AnomalyCode",    "type": "NVARCHAR(50)",  "description": "Code indicating the type of anomaly ('Metric Outlier' or 'Low Prob')." },
    { "name": "EventA",         "type": "NVARCHAR(20)",  "description": "Name of the prior event." },
    { "name": "EventB",         "type": "NVARCHAR(20)",  "description": "Name of the subsequent event." },
    { "name": "MetricAvg",      "type": "FLOAT",         "description": "Average metric value for this transition from the model." },
    { "name": "MetricStDev",    "type": "FLOAT",         "description": "Standard deviation of metric values for this transition." },
    { "name": "metric_value",   "type": "FLOAT",         "description": "Observed metric value for this specific case transition." },
    { "name": "metric_zscore",  "type": "FLOAT",         "description": "Z-score of the observed metric relative to the model distribution." },
    { "name": "transistion_prob","type": "FLOAT",        "description": "Transition probability for this event pair in the model." },
    { "name": "Metric",         "type": "NVARCHAR(20)",  "description": "Name of the metric used." },
    { "name": "EventAIsEntry",  "type": "BIT",           "description": "Flag indicating if the transition starts a case." },
    { "name": "EventBIsExit",   "type": "BIT",           "description": "Flag indicating if the transition ends a case." }
  ],
  "Referenced objects": [
    { "name": "dbo.EventPairAnomalies", "type": "Table",                  "description": "Stores computed anomalies for each event pair and case." },
    { "name": "dbo.Models",             "type": "Table",                  "description": "Stores model definitions and metadata, including metric selection." },
    { "name": "dbo.Metrics",            "type": "Table",                  "description": "Lookup of metric names and calculation methods." },
    { "name": "dbo.ModelEvents",        "type": "Table",                  "description": "Contains transition statistics (Avg, StDev, Prob, etc.) for each event pair in a model." }
  ]
}

Sample utilization:

	DECLARE @ModelID INT = 1
	SELECT  
		[CaseID], [AnomalyCode], [EventA], [EventB],
		MetricAvg, MetricStDev, metric_value, metric_zscore,
		[transistion_prob]
	FROM 
		ModelEventAnomalies(@ModelID)

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE FUNCTION [dbo].[ModelEventAnomalies]
(	
@ModelID INT
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT  
		epa.[ModelID],[CaseID],[EventIDA],[EventIDB],[AnomalyCode],epa.[EventA],epa.[EventB],
		me.[Avg] AS MetricAvg,me.[StDev] AS MetricStDev,epa.metric_value,epa.metric_zscore,
		[transistion_prob],met.Metric,[EventAIsEntry],[EventBIsExit]
	FROM 
		[dbo].[EventPairAnomalies] epa (NOLOCK)
		JOIN [dbo].[Models] m (NOLOCK) ON m.modelid=epa.ModelID
		JOIN dbo.Metrics met (NOLOCK) ON met.MetricID=m.MetricID
		JOIN dbo.ModelEvents me (NOLOCK) ON 
			me.ModelID=m.ModelID AND me.EventA=epa.EventA AND me.EventB=epa.EventB
	WHERE
		epa.ModelID=@ModelID
)
GO
/****** Object:  UserDefinedFunction [dbo].[ModelEventsByOrdinalMean]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "ModelEventsByOrdinalMean",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-16",
  "Description": "Aggregates transition statistics by source event, computing total occurrences and average ordinal metrics for each EventA in the specified Markov model.",
  "Utilization": "Use when you want a compact summary of how often each source event appears in a model and roughly where in the process it tends to occur. Helpful for identifying early-, middle-, and late-stage events, comparing process shape by EventA, or building simplified visualizations from ModelEvents.",
  "Input Parameters": [
    { "name": "@ModelID", "type": "INT", "default": "NULL", "description": "Identifier of the Markov model whose events should be aggregated." }
  ],
  "Output Notes": [
    { "name": "EventA",        "type": "NVARCHAR(20)", "description": "The originating event in the transition." },
    { "name": "Rows",          "type": "BIGINT",       "description": "Total number of observed transitions starting from EventA." },
    { "name": "OrdinalMean",   "type": "FLOAT",        "description": "Average position (rank) of the transition occurrences." },
    { "name": "OrdinalStDev",  "type": "FLOAT",        "description": "Standard deviation of the transition rank positions." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelEvents", "type": "Table", "description": "Stores detailed transition metrics (Rows, Avg, StDev, OrdinalMean, OrdinalStDev) for each ModelID, EventA→EventB pair." }
  ]
}

Sample utilization:

	DECLARE @ModelID INT=1
    SELECT * 
      FROM dbo.ModelEventsByOrdinalMean(@ModelID)
	ORDER BY OrdinalMean

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE FUNCTION [dbo].[ModelEventsByOrdinalMean]
(	
@ModelID INT
)
RETURNS TABLE 
AS
RETURN 
(
SELECT EventA, SUM(Rows) AS Rows, AVG(OrdinalMean) AS OrdinalMean, AVG(OrdinalStDev) AS OrdinalStDev
FROM  dbo.ModelEvents WITH (NOLOCK)
WHERE ModelID=@ModelID
GROUP BY EventA
)

GO
/****** Object:  UserDefinedFunction [dbo].[ModelMatrix]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "ModelMatrix",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-14",
  "Description": "Returns the first-order transition matrix for a given Markov model, listing each EventA→EventB transition and its associated probability.",
  "Utilization": "Use when you want the first-order transition matrix for a single Markov model in its simplest form: EventA, EventB, and probability. Helpful for adjacency-style graphing, exporting model edges to other tools, or quickly inspecting the transition structure of a model without the extra statistics stored in ModelEvents.",
  "Input Parameters": [
    { "name": "@ModelID", "type": "INT", "default": "NULL", "description": "Identifier of the Markov model whose transitions should be retrieved." }
  ],
  "Output Notes": [
    { "name": "EventA", "type": "NVARCHAR(20)", "description": "Source event of the transition." },
    { "name": "EventB", "type": "NVARCHAR(20)", "description": "Target event of the transition." },
    { "name": "Prob",   "type": "FLOAT",         "description": "Probability of transitioning from EventA to EventB." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelEvents", "type": "Table", "description": "Stores first-order transition probabilities (EventA→EventB) for each model." }
  ]
}

Sample utilization:

    SELECT * FROM dbo.ModelMatrix(10);

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE FUNCTION [dbo].[ModelMatrix]
(
    @ModelID INT  -- Input parameter to filter by ModelID
)
RETURNS TABLE 
AS
RETURN
(
    -- Insert transitions for the specified ModelID into the result table
        SELECT EventA, EventB, Prob 
        FROM [dbo].[ModelEvents] WITH (NOLOCK)
        WHERE ModelID = @ModelID

)

GO
/****** Object:  UserDefinedFunction [dbo].[ParseCSV]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "ParseCSV",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-16",
  "Description": "Splits a comma- or delimiter-separated NVARCHAR string into rows of individual values using STRING_SPLIT.",
  "Utilization": "Use when you need a lightweight helper to split a delimited string into rows inside SQL. Helpful for reusable parameter parsing, especially when other functions or procedures accept comma-separated lists and you want a simple rowset for filtering or joining.",
  "Input Parameters": [
    { "name": "@csv",       "type": "NVARCHAR(MAX)", "default": "NULL", "description": "Delimited string to parse into individual values." },
    { "name": "@delimiter", "type": "CHAR(1)",       "default": "','",   "description": "Single-character delimiter; defaults to comma if NULL." }
  ],
  "Output Notes": [
    { "name": "value", "type": "NVARCHAR(4000)", "description": "Each substring between delimiters from the input CSV." }
  ],
  "Referenced objects": [
    { "name": "STRING_SPLIT", "type": "Built-in Function", "description": "SQL Server function used to split the string by the given delimiter." }
  ]
}

Sample utilization:

SELECT * FROM dbo.ParseCSV('a,b,c', ',');

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, indexing, performance tuning, etc., have been simplified.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE FUNCTION [dbo].[ParseCSV]
(	
@csv NVARCHAR(MAX),
@delimiter CHAR(1)
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT [value] FROM string_split(@csv,COALESCE(@delimiter,','))
)
GO
/****** Object:  UserDefinedFunction [dbo].[ParseFilterProperties]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Table-Valued Function": "dbo.ParseFilterProperties",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Description": [
    "Parses filter JSON into a normalized rowset for use by procedures such as sp_SelectedEvents.",
    "Supports scalar equality, array IN-lists, and object start/end ranges."
  ],
  "Input Parameters": [
    {"name":"@FilterProperties","type":"NVARCHAR(MAX)","default":null,"description":"JSON filter specification."}
  ],
  "JSON Shapes Supported": [
    {"shape":"{\"Fuel\":1,\"Weight\":1}","meaning":"Equality"},
    {"shape":"{\"Fuel\":[1,2,3],\"Weight\":1}","meaning":"IN list"},
    {"shape":"{\"Fuel\":{\"start\":1,\"end\":3},\"Weight\":1}","meaning":"BETWEEN inclusive"}
  ],
  "Output Notes": [
    {"name":"property","type":"NVARCHAR(20)","description":"Property name."},
    {"name":"operator_type","type":"NVARCHAR(20)","description":"eq | in | between"},
    {"name":"property_numeric","type":"FLOAT","description":"Numeric scalar equality value when operator_type='eq'."},
    {"name":"property_alpha","type":"NVARCHAR(1000)","description":"Alpha scalar equality value when operator_type='eq'."},
    {"name":"property_json","type":"NVARCHAR(MAX)","description":"Raw JSON array when operator_type='in'."},
    {"name":"range_start_numeric","type":"FLOAT","description":"Start value when operator_type='between'."},
    {"name":"range_end_numeric","type":"FLOAT","description":"End value when operator_type='between'."},
    {"name":"rank","type":"INT","description":"Stable ordinal for the top-level properties."}
  ]
}
*/
CREATE  FUNCTION [dbo].[ParseFilterProperties]
(
    @FilterProperties NVARCHAR(MAX)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        j.[key] AS property,
        CASE 
            WHEN j.[type] IN (1,2) THEN 'eq'       -- string or number
            WHEN j.[type] = 4 THEN 'in'            -- array
            WHEN j.[type] = 5 THEN 'between'       -- object with start/end
            ELSE 'unknown'
        END AS operator_type,
        CASE 
            WHEN j.[type] = 2 THEN TRY_CAST(j.[value] AS FLOAT)
            ELSE NULL
        END AS property_numeric,
        CASE 
            WHEN j.[type] = 1 THEN j.[value]
            ELSE NULL
        END AS property_alpha,
        CASE 
            WHEN j.[type] = 4 THEN j.[value]
            ELSE NULL
        END AS property_json,
        CASE 
            WHEN j.[type] = 5 THEN TRY_CAST(JSON_VALUE(j.[value], '$.start') AS FLOAT)
            ELSE NULL
        END AS range_start_numeric,
        CASE 
            WHEN j.[type] = 5 THEN TRY_CAST(JSON_VALUE(j.[value], '$.end') AS FLOAT)
            ELSE NULL
        END AS range_end_numeric,
        ROW_NUMBER() OVER (ORDER BY j.[key]) AS [rank]
    FROM OPENJSON(@FilterProperties) j
);
GO
/****** Object:  UserDefinedFunction [dbo].[ParseTransforms]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "ParseTransforms",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2026-03-31",
  "Description": "Parses and validates a JSON object of key→value event mappings, ensuring each source key appears only once and selecting the alphabetically first target if duplicates occur. Rewritten as an inline table-valued function for better Azure Synapse compatibility.",
  "Utilization": "Use when you want to turn a transforms JSON object into a normalized rowset of source-event to target-event mappings. Helpful for validating transform definitions, generating stable transform keys, inspecting event-name remapping rules, or feeding transform logic into downstream modeling functions in a Synapse-friendly way.",
  "Input Parameters": [
    { "name": "@transforms", "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON object of mappings from original event keys to transformed keys, or a Code referencing the Transforms table." }
  ],
  "Output Notes": [
    { "name": "fromkey", "type": "NVARCHAR(20)", "description": "Original event key as specified in the JSON or looked up from Transforms." },
    { "name": "tokey",   "type": "NVARCHAR(20)", "description": "Selected target key for that fromkey; if multiple values exist, the alphabetically first is chosen." }
  ],
  "Referenced objects": [
    { "name": "dbo.Transforms", "type": "Table", "description": "Optional lookup of stored transform JSON by Code." },
    { "name": "OPENJSON",       "type": "Built-in Function", "description": "Parses the JSON text into key/value pairs." }
  ]
}

Sample utilization:

    SELECT * FROM [dbo].[ParseTransforms]('{"heavytraffic":"traffic","heavytraffic":"bigtraffic"}');

    SELECT * FROM [dbo].[ParseTransforms]('{"moderatetraffic":"traffic","heavytraffic":"traffic","lighttraffic":"traffic","heavytraffic":"bigtraffic"}');
    SELECT * FROM [dbo].[ParseTransforms]('arnld');

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, indexing, and performance tuning have been simplified or omitted.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/
CREATE FUNCTION [dbo].[ParseTransforms]
(
    @transforms NVARCHAR(MAX)
)
RETURNS TABLE
AS
RETURN
(
    WITH resolved AS
    (
        SELECT
            CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM dbo.Transforms t
                    WHERE t.Code = @transforms
                )
                THEN
                (
                    SELECT TOP 1 t.transforms
                    FROM dbo.Transforms t
                    WHERE t.Code = @transforms
                )
                WHEN ISJSON(@transforms) = 1
                THEN @transforms
                ELSE NULL
            END AS transforms_json
    )
    SELECT
        j.[key] AS [fromkey],
        MIN(CAST(j.[value] AS NVARCHAR(20))) AS [tokey]
    FROM resolved r
    CROSS APPLY OPENJSON(r.transforms_json) j
    GROUP BY
        j.[key]
);
GO
/****** Object:  UserDefinedFunction [dbo].[SegmentComparison]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "SegmentComparison",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-19",
  "Description": "Filters and returns detailed transition metrics for a given event pair (EventA → EventB) across models sliced by specified property values, enabling comparative analysis of different segments.",
  "Utilization": "Use when you want to compare similar segments across models, slices, or conditions to see where probabilities, timing, or other metrics differ.",
  "Input Parameters": [
    { "name": "@EventA",           "type": "NVARCHAR(20)", "default": "NULL", "description": "First event in the transition pair; NULL returns all." },
    { "name": "@EventB",           "type": "NVARCHAR(20)", "default": "NULL", "description": "Second event in the pair; NULL returns all." },
    { "name": "@DiceProperties",   "type": "NVARCHAR(MAX)", "default": "NULL", "description": "JSON object of arrays defining values to slice models by (e.g. {\"Stock\":[\"INTC\",\"MSFT\"]})." },
    { "name": "@SliceProperties",  "type": "NVARCHAR(MAX)", "default": "NULL", "description": "Additional JSON filters for slicing on model properties; currently not applied." }
  ],
  "Output Notes": [
    { "name": "ModelID",            "type": "INT",       "description": "Identifier of the Markov model." },
    { "name": "StartDateTime",      "type": "DATETIME",  "description": "Model effective start date." },
    { "name": "EndDateTime",        "type": "DATETIME",  "description": "Model effective end date." },
    { "name": "PropertyName",       "type": "NVARCHAR(20)","description": "Name of the model property used for slicing." },
    { "name": "PropertyValueAlpha", "type": "NVARCHAR(MAX)","description": "Alpha value of the model property slice." },
    { "name": "PropertyValueNumeric","type": "FLOAT",      "description": "Numeric value of the model property slice." },
    { "name": "EventA",             "type": "NVARCHAR(20)","description": "From-event in the transition." },
    { "name": "EventB",             "type": "NVARCHAR(20)","description": "To-event in the transition." },
    { "name": "Max",                "type": "FLOAT",      "description": "Maximum observed metric value." },
    { "name": "Min",                "type": "FLOAT",      "description": "Minimum observed metric value." },
    { "name": "Sum",                "type": "FLOAT",      "description": "Sum of metric values across occurrences." },
    { "name": "Avg",                "type": "FLOAT",      "description": "Average observed metric value." },
    { "name": "StDev",              "type": "FLOAT",      "description": "Standard deviation of the metric." },
    { "name": "CoefVar",            "type": "FLOAT",      "description": "Coefficient of variation (StDev/Avg)." },
    { "name": "Prob",               "type": "FLOAT",      "description": "Transition probability (Rows/TotalRows)." },
    { "name": "Rows",               "type": "INT",        "description": "Count of observed transitions." },
    { "name": "IsEntry",            "type": "INT",        "description": "1 if this transition begins a case." },
    { "name": "IsExit",             "type": "INT",        "description": "1 if this transition ends a case." },
    { "name": "MetricID",           "type": "INT",        "description": "Identifier of the metric used." },
    { "name": "Metric",             "type": "NVARCHAR(50)","description": "Name of the metric used." },
    { "name": "DistinctCases",      "type": "INT",        "description": "Number of distinct cases in the model." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelEvents",    "type": "Table",                  "description": "Stores first-order transition metrics." },
    { "name": "dbo.Models",         "type": "Table",                  "description": "Model configuration and metadata." },
    { "name": "dbo.Metrics",        "type": "Table",                  "description": "Defines available metric types and units." },
    { "name": "dbo.ModelProperties","type": "Table",                  "description": "Holds arbitrary key/value pairs for models." },
    { "name": "OPENJSON",           "type": "Built-in Function",      "description": "Parses JSON text into key/value rows." }
  ]
}

Sample utilization:

-- Compare transitions for 'Big Drop-3%' to 'No Move' on specified stocks:
SELECT * 
  FROM dbo.SegmentComparison(
    'Big Drop-3%', 
    'No Move', 
    '{"Stock":["INTC","MSFT"]}', 
    '{"EmployeeID":1,"LocationID":1}'
  );

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production-hardened: error handling, security, indexing, and performance tuning have been simplified or omitted.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE FUNCTION [dbo].[SegmentComparison]
(	
@EventA NVARCHAR(50),
@EventB NVARCHAR(50),
@DiceProperties NVARCHAR(MAX),
@SliceProperties NVARCHAR(MAX)
)
RETURNS TABLE 
AS
RETURN 
(
    SELECT
        me.ModelID,
        m.StartDateTime,
        m.EndDateTime,
        mp.PropertyName,
        mp.PropertyValueAlpha AS PropertyValueAlpha,  -- Apply collation to match
        mp.PropertyValueNumeric,
        me.EventA,
        me.EventB,
        me.[Max],
        me.[Min],
        me.[Sum],
        me.[Avg],
        me.[StDev],
        me.CoefVar,
        me.Prob,
        me.[Rows],
        me.IsEntry,
        me.IsExit,
        met.MetricID,
        met.Metric,
        m.DistinctCases
    FROM
        [dbo].[ModelEvents] me (NOLOCK)
        JOIN [dbo].[Models] m (NOLOCK) ON m.ModelID = me.ModelID
        JOIN [dbo].[Metrics] met (NOLOCK) ON met.MetricID = COALESCE(m.MetricID, 1)
        JOIN [dbo].[ModelProperties] mp (NOLOCK) ON mp.ModelID = me.ModelID
        JOIN (
            -- Parse @DiceProperties JSON to extract key-value pairs
            SELECT t.[key] AS PropertyName, p.[value]  AS [Value]
            FROM OPENJSON(@DiceProperties) t
            CROSS APPLY OPENJSON(t.[value]) p
        ) dice ON mp.PropertyName = dice.PropertyName COLLATE SQL_Latin1_General_CP1_CI_AS
               AND
			   (
				(ISNUMERIC(dice.[Value])=0 AND mp.PropertyValueAlpha = dice.[Value] COLLATE SQL_Latin1_General_CP1_CI_AS)
				OR (ISNUMERIC(dice.[Value])=1 AND mp.PropertyValueNumeric = CAST(dice.[Value] AS FLOAT))
				)
	    WHERE
        (@EventA IS NULL OR me.EventA = @EventA)
        AND (@EventB IS NULL OR me.EventB = @EventB)
)
GO
/****** Object:  UserDefinedFunction [dbo].[SeqProb]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "SeqProb",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-19",
  "Description": "Calculates the probability of a given next event following any sequence that starts with the specified start event, for a particular model or across all models.",
  "Utilization": "Use when you need the probability of a specific sequence and want a scalar result that can be embedded in a larger query, scorecard, or rule.",
  "Input Parameters": [
    { "name": "@ModelID",     "type": "INT",           "default": "NULL", "description": "Identifier of the model to filter; NULL returns results for all models." },
    { "name": "@StartEvent",  "type": "NVARCHAR(20)",  "default": "NULL", "description": "Prefix of the sequence to match; e.g. 'arrive' matches any sequence starting with 'arrive...'." },
    { "name": "@EndEvent",    "type": "NVARCHAR(20)",  "default": "NULL", "description": "The subsequent event whose probability is being computed." }
  ],
  "Output Notes": [
    { "name": "ModelID",   "type": "INT",         "description": "Model identifier." },
    { "name": "SeqKey",    "type": "INT",         "description": "Surrogate key of the sequence within ModelSequences." },
    { "name": "Seq",       "type": "NVARCHAR(2000)","description": "The event sequence string (comma-delimited)." },
    { "name": "nextEvent", "type": "NVARCHAR(20)", "description": "The event that follows the sequence." },
    { "name": "Rows",      "type": "INT",         "description": "Count of occurrences of this particular sequence→nextEvent transition." },
    { "name": "Prob",      "type": "FLOAT",       "description": "Probability of the next event given the sequence = Rows / TotalRows." },
    { "name": "TotalRows", "type": "FLOAT",       "description": "Total count of all matching sequence→nextEvent transitions for the model." }
  ],
  "Referenced objects": [
    { "name": "dbo.ModelSequences", "type": "Table",                    "description": "Stores precomputed sequence statistics (Rows, SeqKey, etc.) for each model." },
    { "name": "STRING_AGG",         "type": "Built-in Function",        "description": "Used elsewhere to aggregate events into sequences." }
  ]
}

Sample utilization:

    -- For a specific model:
    SELECT * FROM dbo.SeqProb(1, 'arrive', 'order');
    -- Across all models:
    SELECT * FROM dbo.SeqProb(NULL, 'arrive', 'order');

    SELECT * FROM dbo.SeqProb(NULL, 'arrive,greeted', 'drinks');

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security, concurrency, indexing, and query-plan tuning have been simplified or omitted.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.

*/

CREATE FUNCTION [dbo].[SeqProb]
(	
@ModelID INT,
@StartEvent NVARCHAR(50),
@EndEvent NVARCHAR(50)
)
RETURNS TABLE 
AS
RETURN 
(

	WITH t1 ([Seq],[nextEvent],[Rows],[SeqKey],[ModelID]) AS
	(
		SELECT 
			sq.[Seq],
			sq.[nextEvent],
			sq.[Rows],
			sq.[SeqKey],
			sq.ModelID
		FROM 
			[dbo].[ModelSequences] sq (NOLOCK)
		WHERE
			sq.[Seq] LIKE CONCAT(@StartEvent,'%') And sq.nextEvent=@EndEvent
			AND (@ModelID IS NULL OR sq.ModelID=@ModelID)
	),
	t2 (ModelID,[TotalRows]) AS
	(
		SELECT
			ModelID,
			CAST(SUM(t1.[Rows]) AS FLOAT) AS [TotalRows]
		FROM
			t1
		GROUP BY
			ModelID
	)
	SELECT
			t1.ModelID AS ModelID,
			[SeqKey],
			[Seq],
			[nextEvent],
			[Rows],
			[Rows]/(SELECT TotalRows FROM t2 WHERE ModelID=t1.ModelID) AS [Prob],
			(SELECT TotalRows FROM t2 WHERE ModelID=t1.ModelID) AS TotalRows
	FROM
		t1
)
GO
/****** Object:  UserDefinedFunction [dbo].[SetDefaultModelParameters]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "SetDefaultModelParameters",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-15",
  "Description": "Returns a table of defaulted model parameter values, applying sensible defaults to order, metric, date range, and event enumeration flag when NULLs are provided.",
  "Input Parameters": [
    { "name": "@StartDateTime",             "type": "DATETIME",      "default": NULL, "description": "Lower bound of the time window; defaults to '1900-01-01' if NULL." },
    { "name": "@EndDateTime",               "type": "DATETIME",      "default": NULL, "description": "Upper bound of the time window; defaults to '2050-12-31' if NULL." },
    { "name": "@Order",                     "type": "INT",           "default": NULL, "description": "Markov chain order (1,2,3); defaults to 1 if NULL or ≤0." },
    { "name": "@enumerate_multiple_events", "type": "INT",           "default": NULL, "description": "Flag (0/1) for handling repeated events; defaults to 0 if NULL." },
    { "name": "@metric",                    "type": "NVARCHAR(20)",  "default": NULL, "description": "Metric name to compute between events; defaults to 'Time Between' if NULL." }
  ],
  "Output Notes": [
    { "name": "Order",                       "type": "INT",          "description": "Effective chain order after applying default." },
    { "name": "metric",                      "type": "NVARCHAR(20)", "description": "Effective metric name after applying default." },
    { "name": "StartDateTime",               "type": "DATETIME",     "description": "Effective start date after applying default." },
    { "name": "EndDateTime",                 "type": "DATETIME",     "description": "Effective end date after applying default." },
    { "name": "enumerate_multiple_events",   "type": "INT",          "description": "Effective enumeration flag after applying default." }
  ],
  "Referenced objects": []
}

Sample utilization:
    SELECT * 
      FROM dbo.SetDefaultModelParameters(
             NULL,    -- @StartDateTime
             NULL,    -- @EndDateTime
             NULL,    -- @Order
             NULL,    -- @enumerate_multiple_events
             NULL     -- @metric
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


CREATE FUNCTION [dbo].[SetDefaultModelParameters]
(	
@StartDateTime DATETIME ,
@EndDateTime DATETIME ,
@Order INT , -- 1, 2 or 3
@enumerate_multiple_events INT  ,
@metric NVARCHAR(20) 
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT
		CASE WHEN COALESCE(@Order,0)<=0 THEN 1 ELSE @Order END AS [Order],
		COALESCE(@metric,'Time Between') AS [metric],
		COALESCE(@StartDateTime,'01/01/1900') AS StartDateTime,
		COALESCE(@EndDateTime,'12/31/2050') AS EndDateTime,
		COALESCE(@enumerate_multiple_events,0) AS enumerate_multiple_events,
		'Time Between' AS DefaultMetric,
		dbo.UserAccessBitmap() AS AccessBitmap
)
GO
/****** Object:  UserDefinedFunction [dbo].[SourceColumnsByCaseType]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "SourceColumnsByCaseType",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-19",
  "Description": "Returns, for each case type, the count of cases and their associated data source columns (including keys and ordinals), by joining Cases → CaseTypes → Sources → SourceColumns filtered to those actually used in CasePropertiesParsed.",
  "Utilization": "Use when you want to see which source-system columns are actually populated for each case type, along with how many cases use them. Helpful for metadata discovery, source-to-case-type documentation, property-governance work, and understanding which case attributes are really present in loaded data.",
  "Input Parameters": [],
  "Output Notes": [
    { "name": "CaseTypeID",           "type": "INT",          "description": "Identifier of the case type." },
    { "name": "CaseTypeDescription",  "type": "NVARCHAR(500)", "description": "Human-readable description of the case type." },
    { "name": "Cases",                "type": "INT",          "description": "Number of cases of this type." },
    { "name": "SourceID",             "type": "INT",          "description": "Identifier of the data source." },
    { "name": "SourceName",           "type": "NVARCHAR(100)", "description": "Name of the data source." },
    { "name": "ServerName",           "type": "NVARCHAR(100)", "description": "Server hosting the source." },
    { "name": "DatabaseName",         "type": "NVARCHAR(100)", "description": "Database containing the source." },
    { "name": "SourceColumnID",       "type": "INT",          "description": "Identifier of the source column." },
    { "name": "TableName",            "type": "NVARCHAR(128)", "description": "Table name for the column (defaults to source default if null)." },
    { "name": "ColumnName",           "type": "NVARCHAR(128)", "description": "Name of the column." },
    { "name": "DataType",             "type": "NVARCHAR(50)",  "description": "Data type of the column." },
    { "name": "IsKey",                "type": "BIT",          "description": "Flag indicating if this column is part of the natural key." },
    { "name": "IsOrdinal",            "type": "BIT",          "description": "Flag indicating if this column represents an ordinal position or timestamp." }
  ],
  "Referenced objects": [
    { "name": "dbo.Cases",                 "type": "Table",               "description": "Fact table of individual cases." },
    { "name": "dbo.CaseTypes",             "type": "Table",               "description": "Lookup of case type definitions." },
    { "name": "dbo.Sources",               "type": "Table",               "description": "Lookup of configured data sources." },
    { "name": "dbo.SourceColumns",         "type": "Table",               "description": "Definition of columns for each data source." },
    { "name": "dbo.CasePropertiesParsed",  "type": "Table",               "description": "Parsed case‐level property values, used to filter only actually used columns." }
  ]
}

Sample utilization:

    SELECT *
      FROM dbo.SourceColumnsByCaseType()
     ORDER BY CaseTypeID, SourceID, TableName, ColumnName;

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query-plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE FUNCTION [dbo].[SourceColumnsByCaseType]
(	

)
RETURNS TABLE 
AS
RETURN 
(
	SELECT 
		c.CaseTypeID,
		ct.[Description] AS CaseTypeDescription,
		COUNT(*) AS Cases,
		s.SourceID,
		s.[Name] AS SourceName,
		s.ServerName,
		s.DatabaseName,
		sc.SourceColumnID,
		CASE WHEN sc.TableName IS NULL THEN s.DefaultTableName ELSE sc.TableName END AS TableName,
		sc.ColumnName,
		sc.DataType,
		sc.IsKey,
		sc.IsOrdinal
	FROM
		[dbo].[Cases] c (NOLOCK)
		JOIN [dbo].[CaseTypes] ct (NOLOCK) ON ct.CaseTypeID=c.CaseTypeID
		JOIN [dbo].[Sources] s (NOLOCK) ON s.SourceID=c.SourceID
		JOIN [dbo].[SourceColumns] sc (NOLOCK) ON sc.SourceID=s.SourceID
		JOIN [dbo].[CasePropertiesParsed] cp (NOLOCK) ON cp.CaseID=c.CaseID AND cp.SourceColumnID=sc.SourceColumnID
	GROUP BY
		c.CaseTypeID,
		ct.[Description],
		s.SourceID,
		s.[Name],
		s.ServerName,
		s.DatabaseName,
		sc.SourceColumnID,
		CASE WHEN sc.TableName IS NULL THEN s.DefaultTableName ELSE sc.TableName END,
		sc.ColumnName,
		sc.DataType,
		sc.IsKey,
		sc.IsOrdinal

)
GO
/****** Object:  UserDefinedFunction [dbo].[SourceColumnsByEventType]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Metadata JSON:
{
  "Table-Valued Function": "SourceColumnsByEventType",
  "Author": "Eugene Asahara",
  "Contact": "eugene@softcodedlogic.com",
  "Last Update": "2025-05-19",
  "Description": "Returns, for each event type, the count of event occurrences and their associated data source columns (including keys and ordinals), by joining EventsFact → DimEvents → Sources → SourceColumns filtered to those actually used in EventPropertiesParsed.",
  "Utilization": "Use when you want to see which source-system columns are actually populated for each event type, along with how many event rows use them. Helpful for metadata discovery, event-property governance, source-column documentation, and understanding which event attributes are truly present in the loaded event data.",
  "Input Parameters": [],
  "Output Notes": [
    { "name": "Event",               "type": "NVARCHAR(20)",   "description": "Event code." },
    { "name": "EventDescription",    "type": "NVARCHAR(500)",  "description": "Human-readable description of the event." },
    { "name": "Events",              "type": "INT",            "description": "Count of event occurrences." },
    { "name": "SourceID",            "type": "INT",            "description": "Identifier of the data source." },
    { "name": "SourceName",          "type": "NVARCHAR(100)",  "description": "Name of the data source." },
    { "name": "ServerName",          "type": "NVARCHAR(100)",  "description": "Server hosting the source." },
    { "name": "DatabaseName",        "type": "NVARCHAR(100)",  "description": "Database containing the source." },
    { "name": "SourceColumnID",      "type": "INT",            "description": "Identifier of the source column." },
    { "name": "TableName",           "type": "NVARCHAR(128)",  "description": "Table name for the column (defaults to source default if null)." },
    { "name": "ColumnName",          "type": "NVARCHAR(128)",  "description": "Name of the column." },
    { "name": "DataType",            "type": "NVARCHAR(50)",   "description": "Data type of the column." },
    { "name": "IsKey",               "type": "BIT",            "description": "Flag indicating if this column is part of the natural key." },
    { "name": "IsOrdinal",           "type": "BIT",            "description": "Flag indicating if this column represents an ordinal or sequence number." }
  ],
  "Referenced objects": [
    { "name": "dbo.EventsFact",            "type": "Table",               "description": "Fact table of individual event instances." },
    { "name": "dbo.DimEvents",             "type": "Table",               "description": "Lookup table of event definitions and descriptions." },
    { "name": "dbo.Sources",               "type": "Table",               "description": "Lookup of configured data sources." },
    { "name": "dbo.SourceColumns",         "type": "Table",               "description": "Definition of columns for each data source." },
    { "name": "dbo.EventPropertiesParsed", "type": "Table",               "description": "Parsed event‐level property values, used to filter only actually used columns." }
  ]
}

Sample utilization:

    SELECT *
      FROM dbo.SourceColumnsByEventType()
     ORDER BY [Event];

Context:
    • This code is provided as-is for teaching and demonstration of the Time Molecules concepts.
    • It is **not** production‐hardened: error handling, security (SQL injection), concurrency, indexing, query-plan tuning, partitioning, etc., have been omitted or simplified.
    • Performance and scale have not been fully addressed—use at your own risk.
    • Intended to accompany “Time Molecules” by Eugene Asahara (Technics Publications, 2025).

License:
    Licensed under the MIT License. See LICENSE.md for full terms.
    (c) 2025 Eugene Asahara. All rights reserved.
*/

CREATE FUNCTION [dbo].[SourceColumnsByEventType]
(	

)
RETURNS TABLE 
AS
RETURN 
(
	SELECT 
		e.[Event],
		e.[Description] AS EventDescription,
		COUNT(*) AS [Events],
		s.SourceID,
		s.[Name] AS SourceName,
		s.ServerName,
		s.DatabaseName,
		sc.SourceColumnID,
		CASE WHEN sc.TableName IS NULL THEN s.DefaultTableName ELSE sc.TableName END AS TableName,
		sc.ColumnName,
		sc.DataType,
		sc.IsKey,
		sc.IsOrdinal
	FROM
		[dbo].[EventsFact] f (NOLOCK)
		JOIN [dbo].[DimEvents] e (NOLOCK) ON f.[Event]=e.[Event]
		JOIN [dbo].[Sources] s (NOLOCK) ON s.SourceID=e.SourceID
		JOIN [dbo].[SourceColumns] sc (NOLOCK) ON sc.SourceID=s.SourceID
		JOIN [dbo].[EventPropertiesParsed] ep (NOLOCK) ON ep.EventID=f.EventID AND ep.SourceColumnID=sc.SourceColumnID
	GROUP BY
		e.[Event],
		e.[Description],
		s.SourceID,
		s.[Name] ,
		s.ServerName,
		s.DatabaseName,
		sc.SourceColumnID,
		CASE WHEN sc.TableName IS NULL THEN s.DefaultTableName ELSE sc.TableName END,
		sc.ColumnName,
		sc.DataType,
		sc.IsKey,
		sc.IsOrdinal

)
GO
/****** Object:  UserDefinedFunction [dbo].[TimeIntelligenceWindow]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Metadata JSON:
{
  "Table-Valued Function": "dbo.TimeIntelligenceWindow",
  "Author": "Eugene Asahara",
  "Description": "Returns a single-row time-intelligence window for a supplied as-of datetime, units value, and function code. Supports common business windows such as current period, to-date windows, previous and next full periods, lag and lead periods, and rolling windows.",
  "Utilization": "Use when a query, stored procedure, or other function needs a reusable time window such as MTD, QTD, YTD, previous month, next quarter, lag 7 days, or rolling 30 days. Designed as an inline table-valued function to be more optimizer-friendly and more portable toward MPP-oriented platforms than a multi-statement TVF.",
  "Input Parameters": [
    {
      "name": "@AsOfDateTime",
      "type": "DATETIME",
      "default": "NULL",
      "description": "Reference datetime used to calculate the requested time window."
    },
    {
      "name": "@Units",
      "type": "INT",
      "default": "0",
      "description": "Offset or magnitude depending on FuncCode. For lag and lead codes it is the number of periods to shift. For rolling codes it is the number of periods in the rolling window. Ignored for many current-period and to-date codes."
    },
    {
      "name": "@FuncCode",
      "type": "VARCHAR(30)",
      "default": "'DAY'",
      "description": "Code indicating the time window to return. Examples include HOUR, DAY, WEEK, MONTH, QUARTER, YEAR, DTD, WTD, MTD, QTD, YTD, PREVMONTH, PREVYEAR, NEXTMONTH, LAGDAY, LAGMONTH, LEADQTR, ROLLINGDAYS, ROLLINGMONTHS, NMTD, NQTD, and NYTD."
    }
  ],
  "Supported Function Codes": [
    { "code": "HOUR", "description": "Current full hour." },
    { "code": "DAY", "description": "Current full day." },
    { "code": "WEEK", "description": "Current full week." },
    { "code": "MONTH", "description": "Current full month." },
    { "code": "QUARTER", "description": "Current full quarter." },
    { "code": "YEAR", "description": "Current full year." },

    { "code": "DTD", "description": "Day to date." },
    { "code": "WTD", "description": "Week to date." },
    { "code": "MTD", "description": "Month to date." },
    { "code": "QTD", "description": "Quarter to date." },
    { "code": "YTD", "description": "Year to date." },

    { "code": "PREVHOUR", "description": "Previous full hour." },
    { "code": "PREVDAY", "description": "Previous full day." },
    { "code": "PREVWEEK", "description": "Previous full week." },
    { "code": "PREVMONTH", "description": "Previous full month." },
    { "code": "PREVQTR", "description": "Previous full quarter." },
    { "code": "PREVYEAR", "description": "Previous full year." },

    { "code": "NEXTHOUR", "description": "Next full hour." },
    { "code": "NEXTDAY", "description": "Next full day." },
    { "code": "NEXTWEEK", "description": "Next full week." },
    { "code": "NEXTMONTH", "description": "Next full month." },
    { "code": "NEXTQTR", "description": "Next full quarter." },
    { "code": "NEXTYEAR", "description": "Next full year." },

    { "code": "LAGHOUR", "description": "Full hour shifted backward by Units." },
    { "code": "LAGDAY", "description": "Full day shifted backward by Units." },
    { "code": "LAGWEEK", "description": "Full week shifted backward by Units." },
    { "code": "LAGMONTH", "description": "Full month shifted backward by Units." },
    { "code": "LAGQTR", "description": "Full quarter shifted backward by Units." },
    { "code": "LAGYEAR", "description": "Full year shifted backward by Units." },

    { "code": "LEADHOUR", "description": "Full hour shifted forward by Units." },
    { "code": "LEADDAY", "description": "Full day shifted forward by Units." },
    { "code": "LEADWEEK", "description": "Full week shifted forward by Units." },
    { "code": "LEADMONTH", "description": "Full month shifted forward by Units." },
    { "code": "LEADQTR", "description": "Full quarter shifted forward by Units." },
    { "code": "LEADYEAR", "description": "Full year shifted forward by Units." },

    { "code": "ROLLINGHOURS", "description": "Rolling trailing window of Units hours ending at AsOfDateTime." },
    { "code": "ROLLINGDAYS", "description": "Rolling trailing window of Units days ending at AsOfDateTime." },
    { "code": "ROLLINGWEEKS", "description": "Rolling trailing window of Units weeks ending at AsOfDateTime." },
    { "code": "ROLLINGMONTHS", "description": "Rolling trailing window of Units months ending at AsOfDateTime." },
    { "code": "ROLLINGQUARTERS", "description": "Rolling trailing window of Units quarters ending at AsOfDateTime." },
    { "code": "ROLLINGYEARS", "description": "Rolling trailing window of Units years ending at AsOfDateTime." },

    { "code": "NMTD", "description": "N months to date including current month based on Units." },
    { "code": "NQTD", "description": "N quarters to date including current quarter based on Units." },
    { "code": "NYTD", "description": "N years to date including current year based on Units." }
  ],
  "Output Notes": [
    {
      "name": "FuncCode",
      "type": "VARCHAR(30)",
      "description": "Normalized function code actually applied."
    },
    {
      "name": "AsOfDateTime",
      "type": "DATETIME",
      "description": "Reference datetime passed into the function."
    },
    {
      "name": "Units",
      "type": "INT",
      "description": "Units value passed into the function."
    },
    {
      "name": "WindowStart",
      "type": "DATETIME",
      "description": "Inclusive start of the computed time window."
    },
    {
      "name": "WindowEnd",
      "type": "DATETIME",
      "description": "Exclusive end of the computed time window."
    },
    {
      "name": "WindowLabel",
      "type": "VARCHAR(200)",
      "description": "Human-readable label describing the computed time window."
    },
    {
      "name": "Grain",
      "type": "VARCHAR(20)",
      "description": "Primary grain associated with the calculation, such as HOUR, DAY, WEEK, MONTH, QUARTER, YEAR, or ROLLING."
    }
  ],
  "Referenced objects": [],
  "Notes": [
    "WindowEnd is exclusive.",
    "Week boundaries follow SQL Server DATEADD/DATEDIFF week behavior unless your environment overrides it.",
    "Designed as an inline TVF for better optimization and easier migration than a multi-statement TVF."
  ]
}

Sample utilization:

	DECLARE @StartDateTime DATETIME
	DECLARE @EndDateTime DATETIME
	DECLARE @EventSet NVARCHAR(500)='restaurantguest'

    SELECT @StartDateTime=StartDateTime, @EndDateTime=EndDateTime
    FROM dbo.TimeIntelligenceWindow('02-28-2023', 0, 'MTD');

	EXEC sp_SelectedEvents @EventSet,0, @StartDateTime,@EndDateTime,NULL,1,NULL,NULL,NULL


    SELECT *
    FROM dbo.TimeIntelligenceWindow(GETDATE(), 1, 'PREVMONTH');

    SELECT *
    FROM dbo.TimeIntelligenceWindow(GETDATE(), 30, 'ROLLINGDAYS');

    SELECT *
    FROM dbo.TimeIntelligenceWindow(GETDATE(), 2, 'LEADQTR');

    SELECT e.*
    FROM dbo.EventsFact e
    CROSS APPLY dbo.TimeIntelligenceWindow(GETDATE(), 1, 'PREVMONTH') ti
    WHERE e.EventDate >= ti.WindowStart
      AND e.EventDate <  ti.WindowEnd;

Context:
    • This code is provided as-is for teaching and demonstration of TimeSolution concepts.
    • It is not production-hardened for all possible calendar conventions or regional week definitions.
    • Intended to provide a reusable time-window surface for event and case filtering.
*/
CREATE   FUNCTION [dbo].[TimeIntelligenceWindow]
(
    @AsOfDateTime DATETIME,
    @Units INT = 0,
    @FuncCode VARCHAR(30) = 'DAY'
)
RETURNS TABLE
AS
RETURN
WITH base AS
(
    SELECT
        UPPER(LTRIM(RTRIM(ISNULL(@FuncCode, 'DAY')))) AS Code,
        ISNULL(@Units, 0) AS Units,
        @AsOfDateTime AS AsOfDateTime,

        DATEADD(HOUR,    DATEDIFF(HOUR,    0, @AsOfDateTime), 0) AS HourStart,
        DATEADD(DAY,     DATEDIFF(DAY,     0, @AsOfDateTime), 0) AS DayStart,
        DATEADD(WEEK,    DATEDIFF(WEEK,    0, @AsOfDateTime), 0) AS WeekStart,
        DATEADD(MONTH,   DATEDIFF(MONTH,   0, @AsOfDateTime), 0) AS MonthStart,
        DATEADD(QUARTER, DATEDIFF(QUARTER, 0, @AsOfDateTime), 0) AS QuarterStart,
        DATEADD(YEAR,    DATEDIFF(YEAR,    0, @AsOfDateTime), 0) AS YearStart
),
calc AS
(
    SELECT
        Code,
        AsOfDateTime,
        Units,

        CASE
            WHEN Code = 'HOUR'    THEN HourStart
            WHEN Code = 'DAY'     THEN DayStart
            WHEN Code = 'WEEK'    THEN WeekStart
            WHEN Code = 'MONTH'   THEN MonthStart
            WHEN Code = 'QUARTER' THEN QuarterStart
            WHEN Code = 'YEAR'    THEN YearStart

            WHEN Code = 'DTD' THEN DayStart
            WHEN Code = 'WTD' THEN WeekStart
            WHEN Code = 'MTD' THEN MonthStart
            WHEN Code = 'QTD' THEN QuarterStart
            WHEN Code = 'YTD' THEN YearStart

            WHEN Code = 'PREVHOUR'  THEN DATEADD(HOUR,    -1, HourStart)
            WHEN Code = 'PREVDAY'   THEN DATEADD(DAY,     -1, DayStart)
            WHEN Code = 'PREVWEEK'  THEN DATEADD(WEEK,    -1, WeekStart)
            WHEN Code = 'PREVMONTH' THEN DATEADD(MONTH,   -1, MonthStart)
            WHEN Code = 'PREVQTR'   THEN DATEADD(QUARTER, -1, QuarterStart)
            WHEN Code = 'PREVYEAR'  THEN DATEADD(YEAR,    -1, YearStart)

            WHEN Code = 'NEXTHOUR'  THEN DATEADD(HOUR,     1, HourStart)
            WHEN Code = 'NEXTDAY'   THEN DATEADD(DAY,      1, DayStart)
            WHEN Code = 'NEXTWEEK'  THEN DATEADD(WEEK,     1, WeekStart)
            WHEN Code = 'NEXTMONTH' THEN DATEADD(MONTH,    1, MonthStart)
            WHEN Code = 'NEXTQTR'   THEN DATEADD(QUARTER,  1, QuarterStart)
            WHEN Code = 'NEXTYEAR'  THEN DATEADD(YEAR,     1, YearStart)

            WHEN Code = 'LAGHOUR'  THEN DATEADD(HOUR,    -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), HourStart)
            WHEN Code = 'LAGDAY'   THEN DATEADD(DAY,     -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), DayStart)
            WHEN Code = 'LAGWEEK'  THEN DATEADD(WEEK,    -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), WeekStart)
            WHEN Code = 'LAGMONTH' THEN DATEADD(MONTH,   -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), MonthStart)
            WHEN Code = 'LAGQTR'   THEN DATEADD(QUARTER, -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), QuarterStart)
            WHEN Code = 'LAGYEAR'  THEN DATEADD(YEAR,    -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), YearStart)

            WHEN Code = 'LEADHOUR'  THEN DATEADD(HOUR,     ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), HourStart)
            WHEN Code = 'LEADDAY'   THEN DATEADD(DAY,      ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), DayStart)
            WHEN Code = 'LEADWEEK'  THEN DATEADD(WEEK,     ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), WeekStart)
            WHEN Code = 'LEADMONTH' THEN DATEADD(MONTH,    ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), MonthStart)
            WHEN Code = 'LEADQTR'   THEN DATEADD(QUARTER,  ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), QuarterStart)
            WHEN Code = 'LEADYEAR'  THEN DATEADD(YEAR,     ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), YearStart)

            WHEN Code = 'ROLLINGHOURS'    THEN DATEADD(HOUR,    -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), AsOfDateTime)
            WHEN Code = 'ROLLINGDAYS'     THEN DATEADD(DAY,     -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), AsOfDateTime)
            WHEN Code = 'ROLLINGWEEKS'    THEN DATEADD(WEEK,    -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), AsOfDateTime)
            WHEN Code = 'ROLLINGMONTHS'   THEN DATEADD(MONTH,   -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), AsOfDateTime)
            WHEN Code = 'ROLLINGQUARTERS' THEN DATEADD(QUARTER, -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), AsOfDateTime)
            WHEN Code = 'ROLLINGYEARS'    THEN DATEADD(YEAR,    -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), AsOfDateTime)

            WHEN Code = 'NMTD' THEN DATEADD(MONTH,   -(ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END) - 1), MonthStart)
            WHEN Code = 'NQTD' THEN DATEADD(QUARTER, -(ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END) - 1), QuarterStart)
            WHEN Code = 'NYTD' THEN DATEADD(YEAR,    -(ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END) - 1), YearStart)

            ELSE DayStart
        END AS WindowStart,

        CASE
            WHEN Code = 'HOUR'    THEN DATEADD(HOUR,    1, HourStart)
            WHEN Code = 'DAY'     THEN DATEADD(DAY,     1, DayStart)
            WHEN Code = 'WEEK'    THEN DATEADD(WEEK,    1, WeekStart)
            WHEN Code = 'MONTH'   THEN DATEADD(MONTH,   1, MonthStart)
            WHEN Code = 'QUARTER' THEN DATEADD(QUARTER, 1, QuarterStart)
            WHEN Code = 'YEAR'    THEN DATEADD(YEAR,    1, YearStart)

            WHEN Code IN ('DTD','WTD','MTD','QTD','YTD')
                THEN AsOfDateTime

            WHEN Code = 'PREVHOUR'  THEN HourStart
            WHEN Code = 'PREVDAY'   THEN DayStart
            WHEN Code = 'PREVWEEK'  THEN WeekStart
            WHEN Code = 'PREVMONTH' THEN MonthStart
            WHEN Code = 'PREVQTR'   THEN QuarterStart
            WHEN Code = 'PREVYEAR'  THEN YearStart

            WHEN Code = 'NEXTHOUR'  THEN DATEADD(HOUR,    2, HourStart)
            WHEN Code = 'NEXTDAY'   THEN DATEADD(DAY,     2, DayStart)
            WHEN Code = 'NEXTWEEK'  THEN DATEADD(WEEK,    2, WeekStart)
            WHEN Code = 'NEXTMONTH' THEN DATEADD(MONTH,   2, MonthStart)
            WHEN Code = 'NEXTQTR'   THEN DATEADD(QUARTER, 2, QuarterStart)
            WHEN Code = 'NEXTYEAR'  THEN DATEADD(YEAR,    2, YearStart)

            WHEN Code = 'LAGHOUR'  THEN DATEADD(HOUR,    1, DATEADD(HOUR,    -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), HourStart))
            WHEN Code = 'LAGDAY'   THEN DATEADD(DAY,     1, DATEADD(DAY,     -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), DayStart))
            WHEN Code = 'LAGWEEK'  THEN DATEADD(WEEK,    1, DATEADD(WEEK,    -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), WeekStart))
            WHEN Code = 'LAGMONTH' THEN DATEADD(MONTH,   1, DATEADD(MONTH,   -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), MonthStart))
            WHEN Code = 'LAGQTR'   THEN DATEADD(QUARTER, 1, DATEADD(QUARTER, -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), QuarterStart))
            WHEN Code = 'LAGYEAR'  THEN DATEADD(YEAR,    1, DATEADD(YEAR,    -ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), YearStart))

            WHEN Code = 'LEADHOUR'  THEN DATEADD(HOUR,    1, DATEADD(HOUR,     ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), HourStart))
            WHEN Code = 'LEADDAY'   THEN DATEADD(DAY,     1, DATEADD(DAY,      ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), DayStart))
            WHEN Code = 'LEADWEEK'  THEN DATEADD(WEEK,    1, DATEADD(WEEK,     ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), WeekStart))
            WHEN Code = 'LEADMONTH' THEN DATEADD(MONTH,   1, DATEADD(MONTH,    ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), MonthStart))
            WHEN Code = 'LEADQTR'   THEN DATEADD(QUARTER, 1, DATEADD(QUARTER,  ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), QuarterStart))
            WHEN Code = 'LEADYEAR'  THEN DATEADD(YEAR,    1, DATEADD(YEAR,     ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), YearStart))

            WHEN Code IN ('ROLLINGHOURS','ROLLINGDAYS','ROLLINGWEEKS','ROLLINGMONTHS','ROLLINGQUARTERS','ROLLINGYEARS')
                THEN AsOfDateTime

            WHEN Code IN ('NMTD','NQTD','NYTD')
                THEN AsOfDateTime

            ELSE DATEADD(DAY, 1, DayStart)
        END AS WindowEnd,

        CASE
            WHEN Code IN ('HOUR','PREVHOUR','NEXTHOUR','LAGHOUR','LEADHOUR') THEN 'HOUR'
            WHEN Code IN ('DAY','DTD','PREVDAY','NEXTDAY','LAGDAY','LEADDAY') THEN 'DAY'
            WHEN Code IN ('WEEK','WTD','PREVWEEK','NEXTWEEK','LAGWEEK','LEADWEEK') THEN 'WEEK'
            WHEN Code IN ('MONTH','MTD','PREVMONTH','NEXTMONTH','LAGMONTH','LEADMONTH','NMTD') THEN 'MONTH'
            WHEN Code IN ('QUARTER','QTD','PREVQTR','NEXTQTR','LAGQTR','LEADQTR','NQTD') THEN 'QUARTER'
            WHEN Code IN ('YEAR','YTD','PREVYEAR','NEXTYEAR','LAGYEAR','LEADYEAR','NYTD') THEN 'YEAR'
            WHEN Code IN ('ROLLINGHOURS','ROLLINGDAYS','ROLLINGWEEKS','ROLLINGMONTHS','ROLLINGQUARTERS','ROLLINGYEARS') THEN 'ROLLING'
            ELSE 'DAY'
        END AS Grain,

        CASE
            WHEN Code = 'HOUR'    THEN 'Current Hour'
            WHEN Code = 'DAY'     THEN 'Current Day'
            WHEN Code = 'WEEK'    THEN 'Current Week'
            WHEN Code = 'MONTH'   THEN 'Current Month'
            WHEN Code = 'QUARTER' THEN 'Current Quarter'
            WHEN Code = 'YEAR'    THEN 'Current Year'

            WHEN Code = 'DTD' THEN 'Day To Date'
            WHEN Code = 'WTD' THEN 'Week To Date'
            WHEN Code = 'MTD' THEN 'Month To Date'
            WHEN Code = 'QTD' THEN 'Quarter To Date'
            WHEN Code = 'YTD' THEN 'Year To Date'

            WHEN Code = 'PREVHOUR'  THEN 'Previous Hour'
            WHEN Code = 'PREVDAY'   THEN 'Previous Day'
            WHEN Code = 'PREVWEEK'  THEN 'Previous Week'
            WHEN Code = 'PREVMONTH' THEN 'Previous Month'
            WHEN Code = 'PREVQTR'   THEN 'Previous Quarter'
            WHEN Code = 'PREVYEAR'  THEN 'Previous Year'

            WHEN Code = 'NEXTHOUR'  THEN 'Next Hour'
            WHEN Code = 'NEXTDAY'   THEN 'Next Day'
            WHEN Code = 'NEXTWEEK'  THEN 'Next Week'
            WHEN Code = 'NEXTMONTH' THEN 'Next Month'
            WHEN Code = 'NEXTQTR'   THEN 'Next Quarter'
            WHEN Code = 'NEXTYEAR'  THEN 'Next Year'

            WHEN Code = 'LAGHOUR'  THEN CONCAT('Lag ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Hour(s)')
            WHEN Code = 'LAGDAY'   THEN CONCAT('Lag ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Day(s)')
            WHEN Code = 'LAGWEEK'  THEN CONCAT('Lag ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Week(s)')
            WHEN Code = 'LAGMONTH' THEN CONCAT('Lag ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Month(s)')
            WHEN Code = 'LAGQTR'   THEN CONCAT('Lag ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Quarter(s)')
            WHEN Code = 'LAGYEAR'  THEN CONCAT('Lag ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Year(s)')

            WHEN Code = 'LEADHOUR'  THEN CONCAT('Lead ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Hour(s)')
            WHEN Code = 'LEADDAY'   THEN CONCAT('Lead ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Day(s)')
            WHEN Code = 'LEADWEEK'  THEN CONCAT('Lead ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Week(s)')
            WHEN Code = 'LEADMONTH' THEN CONCAT('Lead ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Month(s)')
            WHEN Code = 'LEADQTR'   THEN CONCAT('Lead ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Quarter(s)')
            WHEN Code = 'LEADYEAR'  THEN CONCAT('Lead ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Year(s)')

            WHEN Code = 'ROLLINGHOURS'    THEN CONCAT('Rolling Last ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Hours')
            WHEN Code = 'ROLLINGDAYS'     THEN CONCAT('Rolling Last ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Days')
            WHEN Code = 'ROLLINGWEEKS'    THEN CONCAT('Rolling Last ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Weeks')
            WHEN Code = 'ROLLINGMONTHS'   THEN CONCAT('Rolling Last ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Months')
            WHEN Code = 'ROLLINGQUARTERS' THEN CONCAT('Rolling Last ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Quarters')
            WHEN Code = 'ROLLINGYEARS'    THEN CONCAT('Rolling Last ', ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), ' Years')

            WHEN Code = 'NMTD' THEN CONCAT(ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), '-Month-To-Date')
            WHEN Code = 'NQTD' THEN CONCAT(ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), '-Quarter-To-Date')
            WHEN Code = 'NYTD' THEN CONCAT(ABS(CASE WHEN Units = 0 THEN 1 ELSE Units END), '-Year-To-Date')

            ELSE CONCAT('Unrecognized FuncCode (', Code, ') - defaulted to Current Day')
        END AS WindowLabel
    FROM base
)
SELECT
    Code AS FuncCode,
    AsOfDateTime,
    Units,
    WindowStart AS StartDateTime,
    WindowEnd AS EndDateTime,
    WindowLabel,
    Grain
FROM calc;
GO
/****** Object:  View [dbo].[vwBayesianProbabilities_TCW]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vwBayesianProbabilities_TCW]
AS
WITH ua AS (SELECT CAST(dbo.UserAccessBitmap() AS BIGINT) AS UserAccessBitmap)
    SELECT bp.ModelID, bp.GroupType, bp.EventSetAKey, es1.EventSet AS EventSetA, bp.EventSetBKey, es2.EventSet AS EventSetB, bp.ACount, bp.BCount, bp.A_Int_BCount, bp.[PB|A] AS PB_A, bp.[PA|B] AS PA_B, bp.TotalCases, bp.PA, bp.PB, bp.CreateDate, m.CaseFilterProperties, m.EventFilterProperties, m.StartDateTime, m.EndDateTime, @@SERVERNAME AS Server, DB_NAME() 
           AS [Database], HASHBYTES('SHA2_256', @@SERVERNAME + '-' + DB_NAME() + '-' + es1.EventSet) AS EventA_Hash, @@SERVERNAME + '-' + DB_NAME() + '-' + es1.EventSet AS EventA_Description, HASHBYTES('SHA2_256', @@SERVERNAME + '-' + DB_NAME() + '-' + es2.EventSet) AS EventB_Hash, @@SERVERNAME + '-' + DB_NAME() + '-' + es2.EventSet AS EventB_Description, 
           'EventSets' AS EventSetTable, 'EventSet' AS EventSetColumn
  FROM  dbo.BayesianProbabilities AS bp WITH (NOLOCK) INNER JOIN
           dbo.EventSets AS es1 WITH (NOLOCK) ON es1.EventSetKey = bp.EventSetAKey INNER JOIN
           dbo.EventSets AS es2 WITH (NOLOCK) ON es2.EventSetKey = bp.EventSetBKey INNER JOIN
           dbo.Models AS m WITH (NOLOCK) ON m.modelid = bp.ModelID CROSS JOIN
           ua AS ua_1
  WHERE (ua_1.UserAccessBitmap & ISNULL(m.AccessBitmap, 0) <> 0)
GO
/****** Object:  View [dbo].[vwCasePropertiesParsed]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vwCasePropertiesParsed]
AS
WITH ua AS (SELECT CAST(dbo.UserAccessBitmap() AS BIGINT) AS UserAccessBitmap)
    SELECT cp.CaseID, cp.PropertyName, cp.PropertyValueNumeric, cp.PropertyValueAlpha, CASE WHEN ISJSON(cp.PropertyValueAlpha) = 1 THEN 1 ELSE 0 END AS ValueIsJson, sc.SourceColumnID, sc.TableName, sc.ColumnName, s.SourceID, s.Description AS SourceDescription, s.Name AS SourceName
  FROM  dbo.CasePropertiesParsed AS cp WITH (NOLOCK) INNER JOIN
           dbo.SourceColumns AS sc WITH (NOLOCK) ON sc.SourceColumnID = cp.SourceColumnID INNER JOIN
           dbo.Sources AS s WITH (NOLOCK) ON s.SourceID = sc.SourceID CROSS JOIN
           ua AS ua_1
  WHERE (ua_1.UserAccessBitmap & ISNULL(cp.AccessBitmap, 0) <> 0)
GO
/****** Object:  View [dbo].[vwCaseTypeEventCounts]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vwCaseTypeEventCounts]
AS
WITH UserAccess AS (SELECT CAST(dbo.UserAccessBitmap() AS BIGINT) AS UserAccessBitmap)
    SELECT ct.CaseTypeID, ct.Name AS CaseTypeName, ct.Description AS CaseTypeDescription, ct.IRI AS CaseTypeIRI, e.Event, de.Description AS EventDescription, COUNT(*) AS Occurrences
  FROM  UserAccess AS ua INNER JOIN
           dbo.EventsFact AS e WITH (NOLOCK) ON 1 = 1 INNER JOIN
           dbo.DimEvents AS de WITH (NOLOCK) ON de.Event = e.Event INNER JOIN
           dbo.Cases AS c WITH (NOLOCK) ON c.CaseID = e.CaseID INNER JOIN
           dbo.CaseTypes AS ct WITH (NOLOCK) ON ct.CaseTypeID = c.CaseTypeID
  WHERE (c.AccessBitmap = - 1) OR
           (ua.UserAccessBitmap & c.AccessBitmap <> 0)
  GROUP BY ct.CaseTypeID, ct.Name, ct.Description, ct.IRI, e.Event, de.Description
GO
/****** Object:  View [dbo].[vwEventInputPropertiesFlattened]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vwEventInputPropertiesFlattened]
AS
SELECT e.[Event], p.EventID, e.eventdate, [key] AS property_name, [value] AS property_value
FROM  [dbo].[EventProperties] p JOIN
         [dbo].[EventsFact] e ON e.EventID = p.EventID CROSS APPLY OPENJSON([ActualProperties])
WHERE p.ActualProperties IS NOT NULL
GO
/****** Object:  View [dbo].[vwEventPropertiesParsed]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vwEventPropertiesParsed]
AS
SELECT e.EventID, e.PropertyName, dbo.PropertySource(e.PropertySource) AS PropertySource, e.PropertyValueNumeric, e.PropertyValueAlpha, e.IsJSON AS ValueIsJSON, e.SourceColumnID, s.SourceID, s.Description AS SourceDescription, s.Name AS SourceName, sc.ColumnName AS SourceColumnName
FROM  dbo.EventPropertiesParsed AS e INNER JOIN
         dbo.SourceColumns AS sc ON sc.SourceColumnID = e.SourceColumnID INNER JOIN
         dbo.Sources AS s ON s.SourceID = sc.SourceID
GO
/****** Object:  View [dbo].[vwModels]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vwModels]
AS
WITH ua AS (SELECT CAST(dbo.UserAccessBitmap() AS BIGINT) AS UserAccessBitmap)
    SELECT m.modelid, m.ModelType, m.StartDateTime, m.EndDateTime, m.EventSetKey, m.enumerate_multiple_events, m.transformskey, m.ByCase, m.MetricID, m.CaseFilterProperties, m.CreatedBy_AccessBitmap, m.[Order], m.CreateDate, m.EventFilterProperties, m.Description, m.IRI, m.DistinctCases, m.LastUpdate, m.CreationDuration, m.EventFactRows, m.ParamHash
  FROM  dbo.Models AS m CROSS JOIN
           ua AS ua_1
  WHERE (ua_1.UserAccessBitmap & ISNULL(m.AccessBitmap, 0) <> 0)
GO
/****** Object:  View [dbo].[vwTimeSolutionsMetadata]    Script Date: 4/21/2026 7:17:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vwTimeSolutionsMetadata]
AS
WITH ua AS (SELECT CAST(dbo.UserAccessBitmap() AS BIGINT) AS UserAccessBitmap)
    SELECT c.ObjectType, c.ObjectName, c.Description, c.Utilization, c.ParametersJson, c.OutputNotes, c.ReferencedObjectsJson, c.IRI, c.CodeColumn, c.Code, c.AccessBitmap, c.SampleCode
  FROM  dbo.TimeSolutionsMetadata AS c CROSS JOIN
           ua AS ua_1
  WHERE (ua_1.UserAccessBitmap & ISNULL(c.AccessBitmap, 0) <> 0)
GO
EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Dimensions created from case/event properties.' , @level0type=N'SCHEMA',@level0name=N'DIM'
GO
EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Schema for fact tables derived from case and event properties.' , @level0type=N'SCHEMA',@level0name=N'FACT'
GO
EXEC sys.sp_addextendedproperty @name=N'Description', @value=N'Temporary working table' , @level0type=N'SCHEMA',@level0name=N'WORK'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Returns Bayesian probability relationships for event‐set pairs in the Tuple Correlation Web (TCW), including raw counts, conditional probabilities (P(B|A), P(A|B)), model filter context, time bounds, and server/database identifiers.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwBayesianProbabilities_TCW'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "bp"
            Begin Extent = 
               Top = 12
               Left = 76
               Bottom = 259
               Right = 351
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "es1"
            Begin Extent = 
               Top = 12
               Left = 427
               Bottom = 259
               Right = 807
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "es2"
            Begin Extent = 
               Top = 12
               Left = 883
               Bottom = 259
               Right = 1263
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "m"
            Begin Extent = 
               Top = 12
               Left = 1339
               Bottom = 259
               Right = 1749
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ua_1"
            Begin Extent = 
               Top = 12
               Left = 1825
               Bottom = 157
               Right = 2133
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 28
         Width = 284
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwBayesianProbabilities_TCW'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane2', @value=N'         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwBayesianProbabilities_TCW'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=2 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwBayesianProbabilities_TCW'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Exposes parsed case‐level properties with their numeric or textual values, indicates if the value is valid JSON, and enriches each property with its source column and source metadata (SourceID, SourceName, Description).' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwCasePropertiesParsed'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "cp"
            Begin Extent = 
               Top = 12
               Left = 76
               Bottom = 259
               Right = 433
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "sc"
            Begin Extent = 
               Top = 12
               Left = 509
               Bottom = 259
               Right = 805
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "s"
            Begin Extent = 
               Top = 12
               Left = 881
               Bottom = 259
               Right = 1177
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ua_1"
            Begin Extent = 
               Top = 12
               Left = 1253
               Bottom = 157
               Right = 1561
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 9
         Width = 284
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwCasePropertiesParsed'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwCasePropertiesParsed'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Aggregates visible event occurrences by case type and event, returning counts along with case type metadata and event descriptions. Access is filtered through the current user''s access bitmap, while rows marked with AccessBitmap = -1 are treated as unrestricted.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwCaseTypeEventCounts'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "ua"
            Begin Extent = 
               Top = 12
               Left = 76
               Bottom = 157
               Right = 400
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "e"
            Begin Extent = 
               Top = 168
               Left = 76
               Bottom = 415
               Right = 415
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "de"
            Begin Extent = 
               Top = 420
               Left = 76
               Bottom = 667
               Right = 367
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "c"
            Begin Extent = 
               Top = 672
               Left = 76
               Bottom = 919
               Right = 515
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ct"
            Begin Extent = 
               Top = 924
               Left = 76
               Bottom = 1171
               Right = 401
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 12
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwCaseTypeEventCounts'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane2', @value=N'
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwCaseTypeEventCounts'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=2 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwCaseTypeEventCounts'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Flattens JSON event input properties into one row per property by joining EventProperties to EventsFact and expanding ActualProperties with OPENJSON, returning the event name, EventID, event date, property name, and property value.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwEventInputPropertiesFlattened'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 9
         Width = 284
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 1875
         Width = 750
         Width = 750
         Width = 750
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwEventInputPropertiesFlattened'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwEventInputPropertiesFlattened'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Presents parsed event properties together with source metadata by joining EventPropertiesParsed to SourceColumns and Sources, exposing property values, JSON flag, property-source label, source identifiers, and source column names in one result set.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwEventPropertiesParsed'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "e"
            Begin Extent = 
               Top = 12
               Left = 76
               Bottom = 259
               Right = 433
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "sc"
            Begin Extent = 
               Top = 12
               Left = 509
               Bottom = 259
               Right = 805
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "s"
            Begin Extent = 
               Top = 12
               Left = 881
               Bottom = 259
               Right = 1197
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 11
         Width = 284
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwEventPropertiesParsed'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwEventPropertiesParsed'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Provides a reporting-oriented view of EventsFact that exposes core event rows in a more browsable form, likely enriching the base fact records with descriptive attributes useful for downstream querying, metadata browsing, or ad hoc analysis.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwEventsFact'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "e"
            Begin Extent = 
               Top = 12
               Left = 76
               Bottom = 259
               Right = 399
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "at"
            Begin Extent = 
               Top = 12
               Left = 475
               Bottom = 259
               Right = 798
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 9
         Width = 284
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwEventsFact'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwEventsFact'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'End User access to the Models table. This enables the user to filter for models by any of the parameters of the model in ways that are more flexible than MarkovModelsByParameters, but not as comprehensive (MarkovModelsByParameters does more joining).

Notes on columns:

- CreatedBy_AccessBitmap - This is actually a parameter of the model since it was used restict events by the access of the user that created it.
- AccessBitMap - This is a bitmap granting access by role (dbo.Access table). This value is not returned to the end user. AccessBitmap could be more inclusive than CreatedBy_AccessBitmap, but it should never be more inclusive.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwModels'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "m"
            Begin Extent = 
               Top = 12
               Left = 76
               Bottom = 259
               Right = 486
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ua_1"
            Begin Extent = 
               Top = 12
               Left = 562
               Bottom = 157
               Right = 870
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 10
         Width = 284
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwModels'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwModels'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Provides a fuller view of similar source-column pairs, likely combining matched SourceColumns with additional descriptive metadata so related columns across sources can be reviewed, compared, and analyzed more easily.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwSimiliarSourceColumnPairs_Full'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "scp"
            Begin Extent = 
               Top = 12
               Left = 76
               Bottom = 259
               Right = 385
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "s1"
            Begin Extent = 
               Top = 12
               Left = 461
               Bottom = 259
               Right = 782
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "s2"
            Begin Extent = 
               Top = 12
               Left = 858
               Bottom = 259
               Right = 1179
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwSimiliarSourceColumnPairs_Full'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwSimiliarSourceColumnPairs_Full'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Provides an expanded view of SourceColumns by combining source-column metadata with related source-level descriptive information, making it easier to browse columns, their parent sources, and associated documentation in a single rowset.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwSourceColumnsFull'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "sc"
            Begin Extent = 
               Top = 12
               Left = 76
               Bottom = 259
               Right = 372
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "s"
            Begin Extent = 
               Top = 12
               Left = 448
               Bottom = 259
               Right = 1024
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwSourceColumnsFull'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwSourceColumnsFull'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'View the TimeSolutionsMetadata.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwTimeSolutionsMetadata'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "c"
            Begin Extent = 
               Top = 12
               Left = 76
               Bottom = 259
               Right = 440
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ua_1"
            Begin Extent = 
               Top = 12
               Left = 516
               Bottom = 157
               Right = 824
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 9
         Width = 284
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
         Width = 750
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwTimeSolutionsMetadata'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'vwTimeSolutionsMetadata'
GO
