USE [TimeSolution]
GO
--[START Code 54]
/*
--Deprecated.
SELECT *
FROM
dbo.BayesianProbability(
'arrive', --Sequence 1 (sequence of 1 event).
'drinks', --Sequence 2 (sequence of 1 event).
'restaurantguest', --Event Set.
NULL,NULL,NULL,NULL,NULL,NULL)
*/

--This is the new way towards making the codebase more ammenable towards porting to MPP.
DECLARE @SessionID UNIQUEIDENTIFIER=NEWID() --Passing a SessionID will allow us to get the result set instead of it just being output.
EXEC dbo.BayesianProbability2
    @SeqA = 'arrive',
    @SeqB = 'drinks',
    @EventSet =NULL,
    @StartDateTime = NULL,
    @EndDateTime   = NULL,
    @transforms    = NULL,
    @CaseFilterProperties  = NULL,
    @EventFilterProperties = NULL,
    @GroupType     = NULL,
	@SessionID=@SessionID OUTPUT

SELECT * FROM WORK.BayesianProbability WHERE SessionID=@SessionID
DELETE FROM WORK.BayesianProbability WHERE SessionID=@SessionID
--[END Code 54]
