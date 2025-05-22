USE [TimeSolution]
GO
--[START Code 74]
--TVF EventPropertiesSource(@EventID) collects data source metadata.
--Get the case and event property sources related to the EventID=435820
DECLARE @EventID BIGINT=435820
SELECT
PropertyName, PropertyValueNumeric,[Property_Table_Name],[Property_Column],
Property_DBName, [Case_NaturalKey], [Property_ServerName],
[NaturalKey_Table_Name], [NaturalKey_Column], NaturalKey_DBName,
[NaturalKey_ServerName], [Date_Column]
FROM EventPropertiesSource(@EventID)
--[END Code 74]
