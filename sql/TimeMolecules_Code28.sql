USE [TimeSolution]
GO
--[START Code 28 - Markov Model of websitepages event set.]
SELECT 
	ModelID,Event1A,EventB,
	[Max],[Avg],[Min],[StDev],CoefVar,[Sum],
	[Rows],Prob,IsEntry,IsExit
FROM dbo.[MarkovProcess](0,'websitepages',0,NULL,NULL,NULL,1,NULL,NULL,NULL,0)
--[END Code 28]