USE [TimeSolution]
GO
--[START Code 13  – Display Markov model created from AdventureWorksDW2017 Internet sales.]
SELECT ModelID,Event1A,EventB,[Max],[Avg],[Min],[StDev],CoefVar,[Sum],[Rows],Prob
FROM dbo.[MarkovProcess](1,'SaleOrder,SaleShip',0,NULL,NULL,NULL,1,NULL,NULL,NULL,0)
--[END Code 13]