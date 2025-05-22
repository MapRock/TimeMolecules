USE [TimeSolution]
GO
--[START Code 73]
DECLARE @EventID BIGINT=435820
--Retrieve basic information and case-level properties of eventid 435820.
SELECT f.CaseID, [EventID], [Event], EventDate, SourceID,cp.Properties
FROM EventsFact f
JOIN CaseProperties cp ON cp.CaseID=f.CaseID
WHERE EventID=@EventID
--[END Code 73]
