USE [TimeSolution]
GO
SET NOCOUNT ON;
GO

/*
Pattern example:
Create one stored Markov model per month for the cardiology event set.

Purpose:
- Demonstrates dicing by time.
- Uses dbo.TimeIntelligenceWindow to generate monthly windows.
- Uses dbo.CreateUpdateMarkovProcess as the only model-creation entry point.
- Collects the resulting ModelIDs so the batch can be reviewed or reused.

Notes:
- This is intentionally an example pattern for dicing.
- It does NOT call dbo.SelectedEvents directly.
- It assumes dbo.TimeIntelligenceWindow and dbo.CreateUpdateMarkovProcess already exist.
- WindowEnd is treated as exclusive, matching dbo.TimeIntelligenceWindow.
*/

DECLARE
    @EventSet NVARCHAR(MAX) = N'cardiology',
    @enumerate_multiple_events INT = 0,
    @transforms NVARCHAR(MAX) = NULL,
    @ByCase BIT = 1,
    @metric NVARCHAR(20) = NULL,                 -- let proc/default logic decide if desired
    @CaseFilterProperties NVARCHAR(MAX) = NULL,
    @EventFilterProperties NVARCHAR(MAX) = NULL,
    @InsertSequences BIT = 0,                    -- faster for batch creation
    @AnchorDateTime DATETIME = '2024-12-31',        -- change if you want a different anchor
    @MonthsBack INT = 11;                        -- 0..11 = 12 months total

DROP TABLE IF EXISTS #DiceWindows;
CREATE TABLE #DiceWindows
(
    DiceOrdinal INT NOT NULL PRIMARY KEY,
    DiceLabel VARCHAR(20) NOT NULL,
    StartDateTime DATETIME NOT NULL,
    EndDateTime DATETIME NOT NULL
);

;WITH n AS
(
    SELECT 0 AS n
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

DROP TABLE IF EXISTS #CreatedModels;
CREATE TABLE #CreatedModels
(
    DiceOrdinal INT NOT NULL,
    DiceLabel VARCHAR(20) NOT NULL,
    StartDateTime DATETIME NOT NULL,
    EndDateTime DATETIME NOT NULL,
    ModelID INT NULL,
    Status VARCHAR(40) NOT NULL,
    ErrorMessage NVARCHAR(4000) NULL
);

DECLARE
    @DiceOrdinal INT,
    @DiceLabel VARCHAR(20),
    @StartDateTime DATETIME,
    @EndDateTime DATETIME,
    @ModelID INT;

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

		EXEC dbo.MarkovProcess2 
		  @Order=1,
		  @EventSet=@EventSet,
		  @enumerate_multiple_events=@enumerate_multiple_events,
		  @StartDateTime=@StartDateTime,
		  @EndDateTime=@EndDateTime,
		  @ByCase=@ByCase,
		  @ModelID=@ModelID OUTPUT;

        INSERT INTO #CreatedModels
        (
            DiceOrdinal,
            DiceLabel,
            StartDateTime,
            EndDateTime,
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
            @ModelID,
            'CreatedOrUpdated',
            NULL
        );
    END TRY
    BEGIN CATCH
        INSERT INTO #CreatedModels
        (
            DiceOrdinal,
            DiceLabel,
            StartDateTime,
            EndDateTime,
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

SELECT
    DiceOrdinal,
    DiceLabel,
    StartDateTime,
    EndDateTime,
    ModelID,
    Status,
    ErrorMessage
FROM #CreatedModels
ORDER BY StartDateTime;
GO
