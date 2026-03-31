USE [TimeSolution]
GO
--[START Code 25 – Basic request for a Markov model.]
--The individual Events for @EventSet=restaurantguest (a group of event types) cases.
DECLARE @EventSet NVARCHAR(500)='restaurantguest'

/*
--SELECT version is being deprecated in favor of sproc version, which is more conducive towards MPP.

SELECT * 
FROM dbo.SelectedEvents(@EventSet,0, NULL,NULL,NULL,1,NULL,NULL,NULL) 
ORDER BY CaseID,[Rank]
*/

--Same result as the SELECT above, but all columns, and using sproc, which is more conducive to MPP.
EXEC sp_SelectedEvents @EventSet,0, NULL,NULL,NULL,1,NULL,NULL,NULL
--[END Code 25]