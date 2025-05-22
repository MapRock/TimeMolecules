USE [TimeSolution]
GO
--[START Code 50]
DECLARE @NextEvent_EventSet NVARCHAR(100)='restaurantguest'
DECLARE @CurrentEvent NVARCHAR(20)='served'
SELECT ModelID,Event1A,EventB,[Max],[Avg],[Min],[StDev],CoefVar,[Sum],[Rows],Prob
FROM dbo.[MarkovProcess](0,@NextEvent_EventSet,1,NULL,NULL,NULL,1,NULL,NULL,NULL,0)
WHERE
Event1A=@CurrentEvent
--[END Code 50]
