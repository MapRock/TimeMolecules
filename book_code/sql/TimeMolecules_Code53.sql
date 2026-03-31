USE [TimeSolution]
GO
--[START Code 53]
--Time Period Case Markov Models
DECLARE @DD_EventSet NVARCHAR(1000)='heavytraffic,moderatetraffic,lighttraffic'
DECLARE @DD_ByCase BIT=0 --This means we ignore the CaseID.
/*
--Deprecated in order to move the codebase closer to MPP deployment.

SELECT Event1A, EventB, Prob, [Rows]
FROM dbo.[MarkovProcess](1, @DD_EventSet ,0,NULL,NULL,NULL,
@DD_ByCase,NULL,NULL,NULL,1)
*/

DECLARE @SessionID UNIQUEIDENTIFIER=NEWID()


EXEC MarkovProcess2 1, @DD_EventSet ,0,NULL,NULL,NULL,@DD_ByCase,NULL,NULL,NULL,1,NULL,NULL,@SessionID

SELECT 
	Event1A, EventB, Prob, [Rows]
FROM WORK.MarkovProcess 
WHERE 
	SessionID=@SessionID 
ORDER BY Event2A,EventB

DELETE FROM WORK.MarkovProcess WHERE SessionID=@SessionID
--[END Code 53]
