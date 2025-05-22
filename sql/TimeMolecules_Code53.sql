USE [TimeSolution]
GO
--[START Code 53]
--Time Period Case Markov Models
DECLARE @DD_EventSet NVARCHAR(1000)='heavytraffic,moderatetraffic,lighttraffic'
DECLARE @DD_ByCase BIT=0 --This means we ignore the CaseID.
SELECT Event1A, EventB, Prob, [Rows]
FROM dbo.[MarkovProcess](1, @DD_EventSet ,0,NULL,NULL,NULL,
@DD_ByCase,NULL,NULL,NULL,1)
--[END Code 53]
