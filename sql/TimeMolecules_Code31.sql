USE [TimeSolution]
GO
--[START Code 31 – Retrieve MM we hope is actually cached.]
DECLARE @Force_Refresh BIT=0 --0=Will return model if it exists. 
                             --1=Will recalculate the MM even if it exists.
DECLARE @EventSet NVARCHAR(500)='websitepages'
SELECT
	ModelID,Event1A,EventB,
	[Max],[Avg],[Min],[StDev],CoefVar,[Sum],
	[Rows],Prob,IsEntry,IsExit
FROM dbo.[MarkovProcess](
      0, @EventSet, 0,NULL,NULL,NULL,1,NULL,NULL,NULL, @Force_Refresh)
--[END Code 31]