USE [TimeSolution]
GO
--[START Code 75]
DECLARE @EventID BIGINT=435820
SELECT
ep.[PropertyValueNumeric],
ep.SourceColumnID,
ep.EventID,
sc.ColumnName,
sc.TableName
FROM
[TimeSolution].[dbo].[EventPropertiesParsed] ep
JOIN [dbo].[SourceColumns] sc ON sc.SourceColumnID=ep.SourceColumnID
WHERE
ep.eventid=@EventID
--[END Code 75]
