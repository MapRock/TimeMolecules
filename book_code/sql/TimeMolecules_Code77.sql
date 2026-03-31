USE [TimeSolution]
GO
--[START Code 77]
--Find the entry and exit points of the kitchen order event set. 
DECLARE @EventSet NVARCHAR(200)='kitchenorder'
SELECT *  
FROM  
	[dbo].[EntryAndExitPoints](@EventSet, 0, NULL, NULL, NULL,1,NULL, NULL, NULL) 

--[END Code 77]