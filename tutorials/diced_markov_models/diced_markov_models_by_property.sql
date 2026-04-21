USE [TimeSolution]
GO
SET NOCOUNT ON;
GO

/*
Pattern example:
Create one stored Markov model per LocationID for the restaurantguest event set.

Purpose:
- Demonstrates dicing by property.
- Retrieves distinct LocationID values from dbo.CasePropertiesParsed.
- Builds @CaseFilterProperties as JSON for each LocationID.
- Uses dbo.MarkovProcess2 as the model-creation entry point.
- Collects the resulting ModelIDs so the batch can be reviewed or reused.

Notes:
- This is intentionally an example pattern for dicing by property.
- The date range is fixed from 2020-01-01 through today.
- It does NOT call dbo.SelectedEvents directly.
- Assumes LocationID is stored in dbo.CasePropertiesParsed.PropertyName.
*/

DECLARE
    @EventSet NVARCHAR(MAX) = N'restaurantguest',
    @Order INT = 1,
    @enumerate_multiple_events INT = 0,
    @ByCase BIT = 1,
    @StartDateTime DATETIME = '2020-01-01',
    @EndDateTime DATETIME = GETDATE(),
	@Property NVARCHAR(200)='EmployeeID'

DROP TABLE IF EXISTS #DiceProperties;
CREATE TABLE #DiceProperties
(
    DiceOrdinal INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    PropertyName SYSNAME NOT NULL,
    PropertyValueAlpha NVARCHAR(4000) NULL,
    PropertyValueNumeric FLOAT NULL,
    CaseFilterProperties NVARCHAR(MAX) NOT NULL,
    DiceLabel VARCHAR(200) NOT NULL
);

INSERT INTO #DiceProperties
(
    PropertyName,
    PropertyValueAlpha,
    PropertyValueNumeric,
    CaseFilterProperties,
    DiceLabel
)
SELECT
    @Property AS PropertyName,
    cpp.PropertyValueAlpha,
    cpp.PropertyValueNumeric,
    CASE
        WHEN cpp.PropertyValueNumeric IS NOT NULL
            THEN CONCAT('{"',@Property,'":', CAST(CAST(cpp.PropertyValueNumeric AS BIGINT) AS VARCHAR(50)), '}')
        ELSE CONCAT('{"',@Property,'":"', STRING_ESCAPE(cpp.PropertyValueAlpha, 'json'), '"}')
    END AS CaseFilterProperties,
    CASE
        WHEN cpp.PropertyValueNumeric IS NOT NULL
            THEN CONCAT(@Property,'=',CAST(CAST(cpp.PropertyValueNumeric AS BIGINT) AS VARCHAR(50)))
        ELSE CONCAT(@Property,'=', cpp.PropertyValueAlpha)
    END AS DiceLabel
FROM
(
    SELECT DISTINCT
        PropertyValueAlpha,
        PropertyValueNumeric
    FROM dbo.CasePropertiesParsed WITH (NOLOCK)
    WHERE PropertyName = @Property
      AND (PropertyValueAlpha IS NOT NULL OR PropertyValueNumeric IS NOT NULL)
) cpp
ORDER BY
    CASE WHEN cpp.PropertyValueNumeric IS NULL THEN 1 ELSE 0 END,
    cpp.PropertyValueNumeric,
    cpp.PropertyValueAlpha;

IF OBJECT_ID('tempdb..#CreatedModels') IS NOT NULL
    DROP TABLE #CreatedModels;

CREATE TABLE #CreatedModels
(
    DiceOrdinal INT NOT NULL,
    DiceLabel VARCHAR(200) NOT NULL,
    PropertyName SYSNAME NOT NULL,
    PropertyValueAlpha NVARCHAR(4000) NULL,
    PropertyValueNumeric FLOAT NULL,
    CaseFilterProperties NVARCHAR(MAX) NOT NULL,
    StartDateTime DATETIME NOT NULL,
    EndDateTime DATETIME NOT NULL,
    ModelID INT NULL,
    Status VARCHAR(40) NOT NULL,
    ErrorMessage NVARCHAR(4000) NULL
);

DECLARE
    @DiceOrdinal INT,
    @DiceLabel VARCHAR(200),
    @PropertyName SYSNAME,
    @PropertyValueAlpha NVARCHAR(4000),
    @PropertyValueNumeric FLOAT,
    @CaseFilterProperties NVARCHAR(MAX),
    @ModelID INT;

DECLARE property_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT
    DiceOrdinal,
    DiceLabel,
    PropertyName,
    PropertyValueAlpha,
    PropertyValueNumeric,
    CaseFilterProperties
FROM #DiceProperties
ORDER BY DiceOrdinal;

OPEN property_cursor;

FETCH NEXT FROM property_cursor
INTO @DiceOrdinal, @DiceLabel, @PropertyName, @PropertyValueAlpha, @PropertyValueNumeric, @CaseFilterProperties;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        SET @ModelID = NULL;

        EXEC dbo.MarkovProcess2
             @Order = @Order,
             @EventSet = @EventSet,
             @enumerate_multiple_events = @enumerate_multiple_events,
             @StartDateTime = @StartDateTime,
             @EndDateTime = @EndDateTime,
             @ByCase = @ByCase,
             @CaseFilterProperties = @CaseFilterProperties,
             @ModelID = @ModelID OUTPUT;

        INSERT INTO #CreatedModels
        (
            DiceOrdinal,
            DiceLabel,
            PropertyName,
            PropertyValueAlpha,
            PropertyValueNumeric,
            CaseFilterProperties,
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
            @PropertyName,
            @PropertyValueAlpha,
            @PropertyValueNumeric,
            @CaseFilterProperties,
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
            PropertyName,
            PropertyValueAlpha,
            PropertyValueNumeric,
            CaseFilterProperties,
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
            @PropertyName,
            @PropertyValueAlpha,
            @PropertyValueNumeric,
            @CaseFilterProperties,
            @StartDateTime,
            @EndDateTime,
            NULL,
            'Error',
            ERROR_MESSAGE()
        );
    END CATCH;

    FETCH NEXT FROM property_cursor
    INTO @DiceOrdinal, @DiceLabel, @PropertyName, @PropertyValueAlpha, @PropertyValueNumeric, @CaseFilterProperties;
END

CLOSE property_cursor;
DEALLOCATE property_cursor;

SELECT
    DiceOrdinal,
    DiceLabel,
    PropertyName,
    PropertyValueAlpha,
    PropertyValueNumeric,
    CaseFilterProperties,
    StartDateTime,
    EndDateTime,
    ModelID,
    Status,
    ErrorMessage
FROM #CreatedModels
ORDER BY DiceOrdinal;
GO
