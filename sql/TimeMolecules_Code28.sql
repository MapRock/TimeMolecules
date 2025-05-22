USE [TimeSolution]
GO
--[START Code 28 – Markov Model for the fuel metric of the commute event set.]
SELECT ModelID,Event1A,EventB,[Max],[Avg],[Min],[StDev],CoefVar,[Sum],[Rows],Prob,IsEntry,IsExit
FROM dbo.[MarkovProcess](1,'commute',0,NULL,NULL,NULL,1,'Fuel',NULL,NULL,0)
--[END Code 28] 