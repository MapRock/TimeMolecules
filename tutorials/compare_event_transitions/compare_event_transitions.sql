/*
Compares the destination-event properties of two competing transitions from the same
source event within a Markov model.

Purpose:
    • This script is for branch comparison at a divergence point such as:
          leavehome -> arrivework
          leavehome -> heavytraffic
    • The goal is not merely to show that the process branches, but to identify what is
      different about the destination events reached by each branch.

How it works:
    • Runs dbo.sp_ModelDrillThrough twice for the same source event (@EventA), once for
      each competing destination event (@EventB_TransA and @EventB_TransB).
    • Uses separate SessionIDs so both drillthrough populations can coexist in
      WORK.ModelDrillThrough during analysis.
    • Compares only EventB_ID, because EventB is the divergent event and therefore the
      meaningful population to compare.
    • For numeric properties:
        - Pulls the matching property from both EventA and EventB.
        - Looks for the property name in dbo.Metrics.
        - Uses dbo.MetricValue with Metrics.Method to derive the correct per-row value.
        - Defaults Metrics.Method to 0 when the property is not found in dbo.Metrics,
          meaning the EventB numeric value is used as-is.
        - Aggregates the derived values by transition into count, average, standard
          deviation, minimum, and maximum.
    • For alpha properties:
        - Compares EventB categorical values by count across the two transition
          populations.

Why this is useful:
    • A Markov model shows where behavior diverges.
    • Drillthrough reveals the underlying cases behind each competing transition.
    • Property comparison helps explain why one branch occurred instead of the other by
      surfacing measurable differences in the destination-event populations.

Typical interpretation:
    • Large differences in numeric averages may indicate meaningful operational or
      contextual differences between the two outcomes.
    • Differences in standard deviation or min/max range may indicate one branch is more
      stable or more variable than the other.
    • Differences in categorical value counts may reveal different conditions,
      classifications, or contexts associated with each branch.

Outputs:
    • Final display 1: numeric property comparison between TransA and TransB.
    • Final display 2: alpha property comparison between TransA and TransB.

Cleanup:
    • Deletes the temporary drillthrough rows from WORK.ModelDrillThrough.
    • Drops temp tables #NumericAgg and #AlphaAgg.

Notes:
    • Assumes dbo.Metrics.Metric matches dbo.EventPropertiesParsed.PropertyName.
    • Assumes dbo.sp_ModelDrillThrough populates WORK.ModelDrillThrough using @SessionID.
    • Assumes dbo.MetricValue accepts:
          dbo.MetricValue(@metricmethod, @From_MetricActualValue, @From_MetricExpectedValue,
                          @To_MetricActualValue,   @To_MetricExpectedValue)
*/
DECLARE @ModelID BIGINT = 14;
DECLARE @EventA NVARCHAR(50) = 'leavehome';
DECLARE @EventB_TransA NVARCHAR(50) = 'arrivework';
DECLARE @EventB_TransB NVARCHAR(50) = 'heavytraffic';

DECLARE @DrillThroughSessionID_TransA UNIQUEIDENTIFIER = NEWID();
DECLARE @DrillThroughSessionID_TransB UNIQUEIDENTIFIER = NEWID();

SELECT *
FROM dbo.ModelEvents
WHERE ModelID = @ModelID;

EXEC dbo.sp_ModelDrillThrough
    @ModelID = @ModelID,
    @EventA = @EventA,
    @EventB = @EventB_TransA,
    @SessionID = @DrillThroughSessionID_TransA;

EXEC dbo.sp_ModelDrillThrough
    @ModelID = @ModelID,
    @EventA = @EventA,
    @EventB = @EventB_TransB,
    @SessionID = @DrillThroughSessionID_TransB;

SELECT *
FROM WORK.ModelDrillThrough
WHERE SessionID = @DrillThroughSessionID_TransA;

SELECT *
FROM WORK.ModelDrillThrough
WHERE SessionID = @DrillThroughSessionID_TransB;

IF OBJECT_ID('tempdb..#NumericAgg') IS NOT NULL DROP TABLE #NumericAgg;
IF OBJECT_ID('tempdb..#AlphaAgg') IS NOT NULL DROP TABLE #AlphaAgg;

-------------------------------------------------------------------------------
-- Numeric comparison
-- Uses Metrics.Method + dbo.MetricValue.
-- Default Method = 0 if PropertyName not found in dbo.Metrics.
-- Method 1 means compare EventB against EventA as a from-to delta.
-------------------------------------------------------------------------------
;WITH TransitionPairs AS
(
    SELECT
        'TransA' AS TransitionSet,
        mdt.SessionID,
        mdt.CaseID,
        mdt.EventA,
        mdt.EventB,
        mdt.EventA_ID,
        mdt.EventB_ID
    FROM WORK.ModelDrillThrough mdt
    WHERE mdt.SessionID = @DrillThroughSessionID_TransA

    UNION ALL

    SELECT
        'TransB' AS TransitionSet,
        mdt.SessionID,
        mdt.CaseID,
        mdt.EventA,
        mdt.EventB,
        mdt.EventA_ID,
        mdt.EventB_ID
    FROM WORK.ModelDrillThrough mdt
    WHERE mdt.SessionID = @DrillThroughSessionID_TransB
),
EventAProps AS
(
    SELECT
        tp.TransitionSet,
        tp.CaseID,
        tp.EventA,
        tp.EventB,
        tp.EventA_ID,
        tp.EventB_ID,
        epp.PropertyName,
        epp.PropertySource,
        epp.SourceColumnID,
        epp.PropertyValueNumeric AS EventA_PropertyValueNumeric
    FROM TransitionPairs tp
    JOIN dbo.EventPropertiesParsed epp
        ON epp.EventID = tp.EventA_ID
    WHERE epp.PropertyValueNumeric IS NOT NULL
),
EventBProps AS
(
    SELECT
        tp.TransitionSet,
        tp.CaseID,
        tp.EventA,
        tp.EventB,
        tp.EventA_ID,
        tp.EventB_ID,
        epp.PropertyName,
        epp.PropertySource,
        epp.SourceColumnID,
        epp.PropertyValueNumeric AS EventB_PropertyValueNumeric
    FROM TransitionPairs tp
    JOIN dbo.EventPropertiesParsed epp
        ON epp.EventID = tp.EventB_ID
    WHERE epp.PropertyValueNumeric IS NOT NULL
),
MatchedNumericProps AS
(
    SELECT
        b.TransitionSet,
        b.CaseID,
        b.EventA,
        b.EventB,
        b.PropertyName,
        b.PropertySource,
        b.SourceColumnID,
        a.EventA_PropertyValueNumeric,
        b.EventB_PropertyValueNumeric,
        COALESCE(m.[Method], 0) AS MetricMethod
    FROM EventBProps b
    LEFT JOIN EventAProps a
        ON  a.TransitionSet = b.TransitionSet
        AND a.CaseID = b.CaseID
        AND a.EventA_ID = b.EventA_ID
        AND a.EventB_ID = b.EventB_ID
        AND a.PropertyName = b.PropertyName
        AND ISNULL(a.PropertySource, -1) = ISNULL(b.PropertySource, -1)
        AND ISNULL(a.SourceColumnID, -1) = ISNULL(b.SourceColumnID, -1)
    LEFT JOIN dbo.Metrics m
        ON m.Metric = b.PropertyName
),
ComputedNumericProps AS
(
    SELECT
        TransitionSet,
        CaseID,
        EventA,
        EventB,
        PropertyName,
        PropertySource,
        SourceColumnID,
        MetricMethod,
        dbo.MetricValue
        (
            MetricMethod,
            EventA_PropertyValueNumeric,
            NULL,
            EventB_PropertyValueNumeric,
            NULL
        ) AS ComputedMetricValue
    FROM MatchedNumericProps
)
SELECT
    TransitionSet,
    PropertyName,
    PropertySource,
    SourceColumnID,
    MAX(MetricMethod) AS MetricMethod,
    COUNT(*) AS NumericValueCount,
    AVG(ComputedMetricValue) AS AvgValue,
    STDEV(ComputedMetricValue) AS StDevValue,
    MIN(ComputedMetricValue) AS MinValue,
    MAX(ComputedMetricValue) AS MaxValue
INTO #NumericAgg
FROM ComputedNumericProps
WHERE ComputedMetricValue IS NOT NULL
GROUP BY
    TransitionSet,
    PropertyName,
    PropertySource,
    SourceColumnID;

-------------------------------------------------------------------------------
-- Alpha comparison
-- Still compares EventB only, because that is the divergent event.
-------------------------------------------------------------------------------
;WITH TransitionBEvents AS
(
    SELECT
        'TransA' AS TransitionSet,
        mdt.SessionID,
        mdt.CaseID,
        mdt.EventA,
        mdt.EventB,
        mdt.EventB_ID AS EventID
    FROM WORK.ModelDrillThrough mdt
    WHERE mdt.SessionID = @DrillThroughSessionID_TransA

    UNION ALL

    SELECT
        'TransB' AS TransitionSet,
        mdt.SessionID,
        mdt.CaseID,
        mdt.EventA,
        mdt.EventB,
        mdt.EventB_ID AS EventID
    FROM WORK.ModelDrillThrough mdt
    WHERE mdt.SessionID = @DrillThroughSessionID_TransB
),
TransitionEventProperties AS
(
    SELECT
        tbe.TransitionSet,
        tbe.CaseID,
        tbe.EventA,
        tbe.EventB,
        epp.EventID,
        epp.PropertyName,
        epp.PropertySource,
        epp.SourceColumnID,
        epp.PropertyValueAlpha
    FROM TransitionBEvents tbe
    JOIN dbo.EventPropertiesParsed epp
        ON epp.EventID = tbe.EventID
)
SELECT
    TransitionSet,
    PropertyName,
    PropertySource,
    SourceColumnID,
    PropertyValueAlpha,
    COUNT(*) AS AlphaValueCount
INTO #AlphaAgg
FROM TransitionEventProperties
WHERE PropertyValueAlpha IS NOT NULL
GROUP BY
    TransitionSet,
    PropertyName,
    PropertySource,
    SourceColumnID,
    PropertyValueAlpha;

-------------------------------------------------------------------------------
-- Final display 1: numeric property comparison on EventB,
-- but using dbo.MetricValue and Metrics.Method where applicable.
-------------------------------------------------------------------------------
SELECT
    COALESCE(a.PropertyName, b.PropertyName) AS PropertyName,
    COALESCE(a.PropertySource, b.PropertySource) AS PropertySource,
    COALESCE(a.SourceColumnID, b.SourceColumnID) AS SourceColumnID,
    COALESCE(a.MetricMethod, b.MetricMethod) AS MetricMethod,

    a.NumericValueCount AS TransA_Count,
    a.AvgValue AS TransA_Avg,
    a.StDevValue AS TransA_StDev,
    a.MinValue AS TransA_Min,
    a.MaxValue AS TransA_Max,

    b.NumericValueCount AS TransB_Count,
    b.AvgValue AS TransB_Avg,
    b.StDevValue AS TransB_StDev,
    b.MinValue AS TransB_Min,
    b.MaxValue AS TransB_Max,

    CASE
        WHEN a.AvgValue IS NOT NULL AND b.AvgValue IS NOT NULL
        THEN a.AvgValue - b.AvgValue
        ELSE NULL
    END AS AvgDiff_TransA_minus_TransB
FROM
    (SELECT * FROM #NumericAgg WHERE TransitionSet = 'TransA') a
    FULL OUTER JOIN
    (SELECT * FROM #NumericAgg WHERE TransitionSet = 'TransB') b
        ON  a.PropertyName = b.PropertyName
        AND ISNULL(a.PropertySource, -1) = ISNULL(b.PropertySource, -1)
        AND ISNULL(a.SourceColumnID, -1) = ISNULL(b.SourceColumnID, -1)
ORDER BY
    PropertyName;

-------------------------------------------------------------------------------
-- Final display 2: alpha property comparison on EventB only
-------------------------------------------------------------------------------
SELECT
    COALESCE(a.PropertyName, b.PropertyName) AS PropertyName,
    COALESCE(a.PropertySource, b.PropertySource) AS PropertySource,
    COALESCE(a.SourceColumnID, b.SourceColumnID) AS SourceColumnID,
    COALESCE(a.PropertyValueAlpha, b.PropertyValueAlpha) AS PropertyValueAlpha,
    a.AlphaValueCount AS TransA_Count,
    b.AlphaValueCount AS TransB_Count,
    ISNULL(a.AlphaValueCount, 0) - ISNULL(b.AlphaValueCount, 0) AS CountDiff_TransA_minus_TransB
FROM
    (SELECT * FROM #AlphaAgg WHERE TransitionSet = 'TransA') a
    FULL OUTER JOIN
    (SELECT * FROM #AlphaAgg WHERE TransitionSet = 'TransB') b
        ON  a.PropertyName = b.PropertyName
        AND ISNULL(a.PropertySource, -1) = ISNULL(b.PropertySource, -1)
        AND ISNULL(a.SourceColumnID, -1) = ISNULL(b.SourceColumnID, -1)
        AND ISNULL(a.PropertyValueAlpha, N'') = ISNULL(b.PropertyValueAlpha, N'')
ORDER BY
    PropertyName,
    PropertyValueAlpha;

DELETE
FROM WORK.ModelDrillThrough
WHERE SessionID IN (@DrillThroughSessionID_TransA, @DrillThroughSessionID_TransB);

DROP TABLE #NumericAgg;
DROP TABLE #AlphaAgg;
