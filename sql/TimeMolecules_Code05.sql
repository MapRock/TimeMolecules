USE [TimeSolution]
GO
--[START Code 5 - Filtering events by event set.]
-- Use the EventSet code, restaurantguest, which maps to all the events above.
--Mistakenly called "Code 4a" in the book.
SELECT
	* 
FROM 
	dbo.SelectedEvents('restaurantguest',0,NULL,NULL,NULL,1,NULL,NULL,NULL) 
ORDER BY 
	CaseID,[Rank]
--[END Code 5]