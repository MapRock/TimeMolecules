USE [TimeSolution]
GO
--[START Code 48]
--Return all sequences CONTAINING the set of events in restaurantguest.
SELECT [Seq], lastEvent, nextEvent, SeqAvg, SeqStDev, [Rows], [Prob], ExitRows,
Cases
FROM dbo.[Sequences]('restaurantguest',1,NULL,NULL,NULL,1,NULL,NULL,NULL,1)
--[END Code 48]
