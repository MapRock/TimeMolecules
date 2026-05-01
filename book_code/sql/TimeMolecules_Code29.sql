USE [TimeSolution]
GO
--[START Code 29 - Markov Model of websitepages event set.]
/*
--Deprecated.
SELECT 
	ModelID,Event1A,EventB,
	[Max],[Avg],[Min],[StDev],CoefVar,[Sum],
	[Rows],Prob,IsEntry,IsExit
FROM dbo.[MarkovProcess](0,'websitepages',0,NULL,NULL,NULL,1,NULL,NULL,NULL,0)
*/
DECLARE @EventSet NVARCHAR(50)='websitepages'
EXEC MarkovProcess2 0,@EventSet,0,NULL,NULL,NULL,1,NULL,NULL,NULL,0
--Should have ModelID=27 because the model already exists.
--[END Code 29]