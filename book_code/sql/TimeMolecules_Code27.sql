USE [TimeSolution]
GO
--[START Code 27 – Look at raw events for commute.]
--Display raw events related to commute.

/*
--SELECT version is being deprecated in favor of sproc version, which is more conducive towards MPP.

SELECT CaseID, [Event], EventDate,[Rank],EventOccurence,MetricActualValue 
FROM dbo.SelectedEvents('commute',0,NULL,NULL,NULL,1,'Fuel',NULL,NULL) 
ORDER BY CaseID,[Rank]
*/
EXEC sp_SelectedEvents 'commute',0,NULL,NULL,NULL,1,'Fuel',NULL,NULL


--[END Code 27]
