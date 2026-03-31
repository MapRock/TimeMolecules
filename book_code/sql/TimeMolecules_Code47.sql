USE [TimeSolution]
GO
--[START Code 47]
DECLARE @enumerate_mult_events INT=3

/*
--Deprecated.
SELECT Event1A, EventB,[Rows],Prob,[IsEntry],[IsExit],[Max],[Min],[StDev],[Avg]
FROM dbo.[MarkovProcess](
0,'restaurantguest',@enumerate_mult_events,NULL,NULL,NULL,1,NULL,NULL,NULL,0)
ORDER BY [OrdinalMean]
*/
DECLARE @SessionID UNIQUEIDENTIFIER=NEWID()
EXEC MarkovProcess2 0,'restaurantguest',@enumerate_mult_events,NULL,NULL,NULL,1,NULL,NULL,NULL,0,NULL,NULL,@SessionID

SELECT 
	Event1A, EventB,[Rows],Prob,[IsEntry],[IsExit],[Max],[Min],[StDev],[Avg] 
FROM WORK.MarkovProcess 
WHERE 
	SessionID=@SessionID
ORDER BY [OrdinalMean]
--[END Code 47]
