USE [TimeSolution]
GO
--[START Code 28 – Markov Model for the fuel metric of the commute event set.]
/*
--Deprecated
SELECT ModelID,Event1A,EventB,[Max],[Avg],[Min],[StDev],CoefVar,[Sum],[Rows],Prob,IsEntry,IsExit
FROM dbo.[MarkovProcess](1,'commute',0,NULL,NULL,NULL,1,'Fuel',NULL,NULL,0)
*/
DECLARE @EventSet NVARCHAR(100)='commute'
DECLARE @Metric NVARCHAR(50)='Fuel'
DECLARE @Order INT=1 --First order Markov Model (a proper Markov model where transition only depends on current).

EXEC dbo.[MarkovProcess2] @Order,@EventSet,0,NULL,NULL,NULL,1,@Metric,NULL,NULL,0

--[END Code 28] 