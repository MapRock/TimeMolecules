USE [TimeSolution]
GO
--[START Code 48]
--Return all sequences CONTAINING the set of events in restaurantguest.
/*
--Deprcated.
SELECT [Seq], lastEvent, nextEvent, SeqAvg, SeqStDev, [Rows], [Prob], ExitRows,
Cases
FROM dbo.[Sequences]('restaurantguest',1,NULL,NULL,NULL,1,NULL,NULL,NULL,1)
*/

DECLARE @SessionID UNIQUEIDENTIFIER=NEWID()
EXEC sp_Sequences 'restaurantguest',1,NULL,NULL,NULL,1,NULL,NULL,NULL,1,@SessionID

SELECT [Seq], lastEvent, nextEvent, SeqAvg, SeqStDev, [Rows], [Prob], ExitRows,Cases
FROM
	WORK.[Sequences]
WHERE
	SessionID=@SessionID

--[END Code 48]
