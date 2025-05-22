USE [TimeSolution]
GO
--[START Code 27 – Look at raw events for commute.]
--Display raw events related to commute.
SELECT CaseID, [Event], EventDate,[Rank],EventOccurence,MetricActualValue 
FROM dbo.SelectedEvents('commute',0,NULL,NULL,NULL,1,'Fuel',NULL,NULL) 
ORDER BY CaseID,[Rank]
--[END Code 27]
