USE [TimeSolution]
GO
--[START Code 47]
DECLARE @enumerate_mult_events INT=3
SELECT Event1A, EventB,[Rows],Prob,[IsEntry],[IsExit],[Max],[Min],[StDev],[Avg]
FROM dbo.[MarkovProcess](
0,'restaurantguest',@enumerate_mult_events,NULL,NULL,NULL,1,NULL,NULL,NULL,0)
ORDER BY [OrdinalMean]
--[END Code 47]
