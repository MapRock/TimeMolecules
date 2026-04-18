DECLARE @ModelID BIGINT = 14;
DECLARE @EventA NVARCHAR(50)='leavehome'
DECLARE @EventB_TransA NVARCHAR(50)='arrivework'
DECLARE @EventB_TransB NVARCHAR(50)='heavytraffic'

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
        epp.PropertyValueNumeric,
        epp.PropertyValueAlpha,
        epp.EventDate,
        epp.[Event]
    FROM TransitionBEvents tbe
    JOIN dbo.EventPropertiesParsed epp
        ON epp.EventID = tbe.EventID
)
SELECT
    TransitionSet,
    PropertyName,
    PropertySource,
    SourceColumnID,
    COUNT(*) AS NumericValueCount,
    AVG(PropertyValueNumeric) AS AvgValue,
    STDEV(PropertyValueNumeric) AS StDevValue,
    MIN(PropertyValueNumeric) AS MinValue,
    MAX(PropertyValueNumeric) AS MaxValue
INTO #NumericAgg
FROM TransitionEventProperties
WHERE PropertyValueNumeric IS NOT NULL
GROUP BY
    TransitionSet,
    PropertyName,
    PropertySource,
    SourceColumnID;

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
        epp.PropertyValueNumeric,
        epp.PropertyValueAlpha,
        epp.EventDate,
        epp.[Event]
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

-- Final display 1: numeric property comparison on EventB only
SELECT
    COALESCE(a.PropertyName, b.PropertyName) AS PropertyName,
    COALESCE(a.PropertySource, b.PropertySource) AS PropertySource,
    COALESCE(a.SourceColumnID, b.SourceColumnID) AS SourceColumnID,

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

-- Final display 2: alpha property comparison on EventB only
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
