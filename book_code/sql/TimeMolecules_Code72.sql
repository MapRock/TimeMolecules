USE [TimeSolution]
GO
--[START Code 72]
--Run this SQL in SSMS.
--Save results to bayesian_tm_prob.csv. Remember to replace NULL with blanks.
--From Neo4j browser, run load_tm_bayesian_prob.cql.
SELECT [ModelID],[GroupType]
,EventSetA, EventSetB
,[ACount],[BCount],[A_Int_BCount],[PB_A],[PA_B]
,[TotalCases],[PA],[PB],[EventA_Description],[EventB_Description]
,[CaseFilterProperties],[EventFilterProperties],[StartDateTime],[EndDateTime]
,[Server],[Database],[EventSetTable],[EventSetColumn],[EventA_Hash],[EventB_Hash]
FROM
[dbo].[vwBayesianProbabilities_TCW]
--[END Code 72]
