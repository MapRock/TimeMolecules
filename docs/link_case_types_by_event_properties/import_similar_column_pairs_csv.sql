USE TimeSolution;
GO
/*
Insert the CSV file created by source_column_semantic_similarity.py into the table, dbo.SimilarSourceColumnPairs.
The output CSV is named: C:\MapRock\TimeMolecules\similar_column_pairs.csv.
*/
IF OBJECT_ID('dbo.SimilarSourceColumnPairs', 'U') IS NOT NULL
    DROP TABLE dbo.SimilarSourceColumnPairs;
GO

CREATE TABLE dbo.SimilarSourceColumnPairs (
    SourceColumnID1     INT            NOT NULL,	--FK to dbo.[dbo].[SourceColumns].SourceColumnID.
    SourceColumnID2     INT            NOT NULL,	--FK to dbo.[dbo].[SourceColumns].SourceColumnID.
    SimilarityScore     DECIMAL(5,4)   NOT NULL,	--Score of 0.65 through 1. 0.65 is the value set as 'plausibly similar'
    Reason              NVARCHAR(500)  NULL

);
GO


BULK INSERT dbo.SimilarSourceColumnPairs
FROM 'C:\MapRock\TimeMolecules\similar_column_pairs.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',           -- or '0x0a'
    CODEPAGE = '65001',             -- UTF-8 if needed
    KEEPNULLS,
    TABLOCK
);

-- Keep highest similarity per pair. 
--[TODO] The LLM has a weird problem with duplicates. Probably LLM prompt needs tweaking. Will address later.
WITH Ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY SourceColumnID1, SourceColumnID2 
                              ORDER BY SimilarityScore DESC) AS rn
    FROM dbo.SimilarSourceColumnPairs
)
DELETE FROM Ranked WHERE rn > 1;
GO

-- Quick verification
SELECT COUNT(*) AS [RowCount] FROM dbo.SimilarSourceColumnPairs;
SELECT * FROM dbo.SimilarSourceColumnPairs ORDER BY SimilarityScore DESC;
SELECT * FROM vwSimiliarSourceColumnPairs_Full ORDER BY SimilarityScore DESC;
