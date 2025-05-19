USE [TimeSolution]
GO
--[START Code 25 – The Markov model with statistics-based columns.]
--Markov Model created from the events listed above. Don't force refresh, so it reads from MarkovEvents.
--Max, Avg, Min, StDev refer by default to the time between the events.
--@Metric (8th parameter) is NULL, which defaults to 'Time Between'.
SELECT 
	ModelID,Event1A,EventB,[Max],[Avg],[Min],[StDev],CoefVar,
[Sum],[Rows],Prob,IsEntry,IsExit
FROM dbo.[MarkovProcess](0,'restaurantguest',0, NULL,NULL,NULL,1,NULL,NULL,NULL,0)
--[END Code 25]