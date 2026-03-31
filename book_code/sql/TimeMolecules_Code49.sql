USE [TimeSolution]
GO
--[START Code 49]
/*
--Deprecated.
SELECT [Seq], lastEvent, nextEvent,HopStDev, HopAvg, HopStDev/HopAvg AS
HopCoefVar,[Rows]
FROM dbo.[Sequences]('restaurantguest',1,NULL,NULL,NULL,1,NULL,NULL,NULL,1)
*/

DECLARE @SessionID UNIQUEIDENTIFIER=NEWID()
EXEC sp_Sequences 'restaurantguest',1,NULL,NULL,NULL,1,NULL,NULL,NULL,1,@SessionID

SELECT [Seq], lastEvent, nextEvent,HopStDev, HopAvg, HopStDev/HopAvg AS HopCoefVar,[Rows]
FROM
	WORK.[Sequences]
WHERE
	SessionID=@SessionID
--[END Code 49]
