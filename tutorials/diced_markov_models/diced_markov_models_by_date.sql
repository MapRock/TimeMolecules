USE [TimeSolution]
GO
SET NOCOUNT ON;
GO

/*
Pattern example:
Create one diced Markov model per month for the cardiology event set.

Purpose:
- Demonstrates dicing by time.
- Uses dbo.TimeIntelligenceWindow to generate monthly windows.
- Uses dbo.MarkovProcess2 to create one WORK.MarkovProcess result per dice.
- Captures one SessionID per dice so the corresponding WORK.MarkovProcess rows can be retrieved.
- Pivots the final result into a matrix:
    rows    = EventA, EventB
    columns = DiceLabel
    values  = Prob

Notes:
- This assumes dbo.MarkovProcess2 writes rows to WORK.MarkovProcess using @SessionID.
- WindowEnd is treated as exclusive, matching dbo.TimeIntelligenceWindow.
*/


DECLARE
    @EventSet NVARCHAR(MAX) = N'cardiology',
    @enumerate_multiple_events INT = 0,
    @transforms NVARCHAR(MAX) = NULL,
    @ByCase BIT = 1,
    @metric NVARCHAR(20) = NULL,
    @CaseFilterProperties NVARCHAR(MAX) = NULL,
    @EventFilterProperties NVARCHAR(MAX) = NULL,
    @InsertSequences BIT = 0,
    @AnchorDateTime DATETIME = '2024-12-31',
    @MonthsBack INT = 11;

DROP TABLE IF EXISTS #DiceWindows;
CREATE TABLE #DiceWindows
(
    DiceOrdinal   INT         NOT NULL PRIMARY KEY,
    DiceLabel     VARCHAR(20) NOT NULL,
    StartDateTime DATETIME    NOT NULL,
    EndDateTime   DATETIME    NOT NULL
);

;WITH n AS
(
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1
    FROM n
    WHERE n < @MonthsBack
)
INSERT INTO #DiceWindows
(
    DiceOrdinal,
    DiceLabel,
    StartDateTime,
    EndDateTime
)
SELECT
    n.n AS DiceOrdinal,
    CONVERT(VARCHAR(7), ti.StartDateTime, 120) AS DiceLabel,   -- yyyy-mm
    ti.StartDateTime,
    ti.EndDateTime
FROM n
CROSS APPLY dbo.TimeIntelligenceWindow(@AnchorDateTime, n.n, 'LAGMONTH') ti
ORDER BY ti.StartDateTime
OPTION (MAXRECURSION 400);

SELECT * FRoM #DiceWindows

IF OBJECT_ID('tempdb..#CreatedModels_Date') IS NOT NULL
    DROP TABLE #CreatedModels_Date;

CREATE TABLE #CreatedModels_Date
(
    DiceOrdinal   INT              NOT NULL,
    DiceLabel     VARCHAR(20)      NOT NULL,
    StartDateTime DATETIME         NOT NULL,
    EndDateTime   DATETIME         NOT NULL,
    SessionID     UNIQUEIDENTIFIER NULL,
    ModelID       INT              NULL,
    Status        VARCHAR(40)      NOT NULL,
    ErrorMessage  NVARCHAR(4000)   NULL
);

DECLARE
    @DiceOrdinal   INT,
    @DiceLabel     VARCHAR(20),
    @StartDateTime DATETIME,
    @EndDateTime   DATETIME,
    @ModelID       INT,
    @SessionID     UNIQUEIDENTIFIER;

DECLARE month_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT
    DiceOrdinal,
    DiceLabel,
    StartDateTime,
    EndDateTime
FROM #DiceWindows
ORDER BY StartDateTime;

OPEN month_cursor;

FETCH NEXT FROM month_cursor
INTO @DiceOrdinal, @DiceLabel, @StartDateTime, @EndDateTime;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        SET @ModelID = NULL;
        SET @SessionID = NEWID();

        EXEC dbo.MarkovProcess2 
            @Order = 1,
            @EventSet = @EventSet,
            @enumerate_multiple_events = @enumerate_multiple_events,
            @StartDateTime = @StartDateTime,
            @EndDateTime = @EndDateTime,
            @transforms = @transforms,
            @ByCase = @ByCase,
            @metric = @metric,
            @CaseFilterProperties = @CaseFilterProperties,
            @EventFilterProperties = @EventFilterProperties,
            @SessionID = @SessionID,
            @ModelID = @ModelID OUTPUT;

        SELECT * FROM Work.MarkovProcess WHERE SessionId=@SessionID

        INSERT INTO #CreatedModels_Date
        (
            DiceOrdinal,
            DiceLabel,
            StartDateTime,
            EndDateTime,
            SessionID,
            ModelID,
            Status,
            ErrorMessage
        )
        VALUES
        (
            @DiceOrdinal,
            @DiceLabel,
            @StartDateTime,
            @EndDateTime,
            @SessionID,
            @ModelID,
            'CreatedOrUpdated',
            NULL
        );
    END TRY
    BEGIN CATCH
        INSERT INTO #CreatedModels_Date
        (
            DiceOrdinal,
            DiceLabel,
            StartDateTime,
            EndDateTime,
            SessionID,
            ModelID,
            Status,
            ErrorMessage
        )
        VALUES
        (
            @DiceOrdinal,
            @DiceLabel,
            @StartDateTime,
            @EndDateTime,
            @SessionID,
            NULL,
            'Error',
            ERROR_MESSAGE()
        );
    END CATCH;

    FETCH NEXT FROM month_cursor
    INTO @DiceOrdinal, @DiceLabel, @StartDateTime, @EndDateTime;
END

CLOSE month_cursor;
DEALLOCATE month_cursor;

-- Optional audit
SELECT
    DiceOrdinal,
    DiceLabel,
    StartDateTime,
    EndDateTime,
    SessionID,
    ModelID,
    Status,
    ErrorMessage
FROM #CreatedModels_Date
ORDER BY StartDateTime;

-- Build pivot column list
DECLARE @cols NVARCHAR(MAX);
DECLARE @sql  NVARCHAR(MAX);

SELECT
    @cols =
        STUFF
        (
            (
                SELECT ',' + QUOTENAME(x.DiceLabel)
                FROM
                (
                    SELECT DISTINCT
                        DiceOrdinal,
                        DiceLabel
                    FROM #CreatedModels_Date
                    WHERE Status = 'CreatedOrUpdated'
                      AND SessionID IS NOT NULL
                ) x
                ORDER BY x.DiceOrdinal
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)')
        ,1,1,'');

IF @cols IS NULL OR LTRIM(RTRIM(@cols)) = ''
BEGIN
    PRINT 'No successful dice results were captured.';
    RETURN;
END;

SET @sql = N'
;WITH src AS
(
    SELECT
        mp.Event1A,
        mp.EventB,
        cm.DiceLabel,
        mp.Prob
    FROM #CreatedModels_Date cm
    JOIN WORK.MarkovProcess mp
        ON cm.SessionID = mp.SessionID
    WHERE cm.Status = ''CreatedOrUpdated''
)
SELECT
    Event1A,
    EventB,
    ' + @cols + '
FROM src
PIVOT
(
    MAX(Prob)
    FOR DiceLabel IN (' + @cols + ')
) p
ORDER BY Event1A, EventB;';
print @sql

EXEC sys.sp_executesql @sql;
GO
