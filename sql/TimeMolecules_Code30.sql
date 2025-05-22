USE [TimeSolution]
GO
--[START Code 30 – Markov model using transforms that merges arnold1 and arnold2.]
--Markov Model with transforms. Transform the two arnolds into a single one.
DECLARE @FM_Transforms NVARCHAR(1000)='{"arnold1":"arnold","arnold2":"arnold",
"keto1":"dietpage","weightwatcher1":"dietpage","vanproteinbars":"proteinbars","chocproteinbars":"proteinbars"}'

SELECT
	ModelID,Event1A,EventB,
	[Max],[Avg],[Min],[StDev],CoefVar,[Sum],
	[Rows],Prob,IsEntry,IsExit
FROM dbo.[MarkovProcess](0,'websitepages',0,NULL,NULL,@FM_Transforms,1,NULL,NULL,NULL,0)
--[END Code 30]