USE [TimeSolution]
GO
--[START Code 5 - Filtering events by event set.]
--This describes how to select events from the EventsFact table.
-- Use the EventSet code, restaurantguest, which maps to all the events above.
--Mistakenly called "Code 4a" in the book.
/*
--2026-04-30 dbo.SelectedEvents is Deprecated due to portability issues to MPP.
SELECT
	* 
FROM 
	dbo.SelectedEvents('restaurantguest',0,NULL,NULL,NULL,1,NULL,NULL,NULL) 
ORDER BY 
	CaseID,[Rank]
*/

EXEC sp_SelectedEvents @EventSet='restaurantguest'
--[END Code 5]