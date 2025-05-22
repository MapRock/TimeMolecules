USE [TimeSolution]
GO
--[START Code 49]
SELECT [Seq], lastEvent, nextEvent,HopStDev, HopAvg, HopStDev/HopAvg AS
HopCoefVar,[Rows]
FROM dbo.[Sequences]('restaurantguest',1,NULL,NULL,NULL,1,NULL,NULL,NULL,1)
--[END Code 49]
