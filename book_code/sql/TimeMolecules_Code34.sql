USE [TimeSolution]
GO
--[START Code 34 – Save the query with the transforms and requery.]
--Cache the Markov Model with the arnold and dietpage transforms.
DECLARE @EventSet NVARCHAR(500)='websitepages'
DECLARE @TransformCode NVARCHAR(20)='arnold'

EXEC CreateUpdateMarkovProcess NULL, @EventSet,0,NULL,NULL,@TransformCode,1,NULL,NULL,NULL
--Query the website pages event set with the arnold transform that we just created.
SELECT
	ModelID,Event1A,EventB,
	[Max],[Avg],[Min],[StDev],CoefVar,[Sum],
	[Rows],Prob,IsEntry,IsExit,FromCache
FROM dbo.[MarkovProcess](0,@EventSet,0,NULL,NULL,@TransformCode,1,NULL,NULL,NULL,0)
--[END Code 34]