/*
Simple test dimension for Location.
Handpicked attributes:
- LocationID
- Description
- City
- State
- Country

Assumptions:
- These are stored in dbo.CasePropertiesParsed
- PropertyName matches the attribute name
*/

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'DIM')
    EXEC('CREATE SCHEMA DIM');
GO

IF OBJECT_ID('DIM.Location_Test','U') IS NOT NULL
    DROP TABLE DIM.Location_Test;
GO

;WITH LocationBase AS
(
    SELECT DISTINCT
        CAST(loc.PropertyValueNumeric AS INT) AS LocationID,
        loc.CaseID
    FROM dbo.CasePropertiesParsed loc (NOLOCK)
    WHERE loc.PropertyName = 'LocationID'
      AND loc.PropertyValueNumeric IS NOT NULL
),
LocationAttributes AS
(
    SELECT
        lb.LocationID,
        MAX(CASE WHEN cp.PropertyName = 'Description'
                 THEN COALESCE(cp.PropertyValueAlpha, CAST(cp.PropertyValueNumeric AS NVARCHAR(4000)))
            END) AS [Description],
        MAX(CASE WHEN cp.PropertyName = 'City'
                 THEN COALESCE(cp.PropertyValueAlpha, CAST(cp.PropertyValueNumeric AS NVARCHAR(4000)))
            END) AS City,
        MAX(CASE WHEN cp.PropertyName = 'State'
                 THEN COALESCE(cp.PropertyValueAlpha, CAST(cp.PropertyValueNumeric AS NVARCHAR(4000)))
            END) AS [State],
        MAX(CASE WHEN cp.PropertyName = 'Country'
                 THEN COALESCE(cp.PropertyValueAlpha, CAST(cp.PropertyValueNumeric AS NVARCHAR(4000)))
            END) AS Country
    FROM
        LocationBase lb
        JOIN dbo.CasePropertiesParsed cp (NOLOCK)
            ON cp.CaseID = lb.CaseID
    GROUP BY
        lb.LocationID
)
SELECT
    LocationID,
    COALESCE([Description], 'Unknown') AS [Description],
    COALESCE(City, 'Unknown') AS City,
    COALESCE([State], 'Unknown') AS [State],
    COALESCE(Country, 'Unknown') AS Country
INTO DIM.Location_Test
FROM LocationAttributes;
GO

SELECT TOP 100 *
FROM DIM.Location_Test
ORDER BY LocationID;
GO
