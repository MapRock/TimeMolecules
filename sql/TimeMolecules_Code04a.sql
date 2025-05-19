USE [TimeSolution]
GO
--[START Code 4a - Filtering events by event set.]
-- Use the EventSet code, restaurantguest, which maps to all the events above.
SELECT
	* 
FROM 
	dbo.SelectedEvents('restaurantguest',0,NULL,NULL,NULL,1,NULL,NULL,NULL) 
ORDER BY 
	CaseID,[Rank]
--[END Code 4a]