USE [TimeSolution]
GO
--[START Code 22 – Markov model using the  transform.] 
DECLARE @Order INT=0
DECLARE @EventSet NVARCHAR(500)='leavehome,heavytraffic,moderatetraffic,lighttraffic,arrivework,returnhome'
DECLARE @Transforms NVARCHAR(MAX)='merge-heavy-mod'

/*
--SELECT version is being deprecated in favor of sproc version, which is more conducive towards MPP.

SELECT Event1A, EventB, Prob,[Rows] FROM dbo.[MarkovProcess](@Order,
	@EventSet, -- Event Set.
	0,NULL,NULL ,@Transforms, 1, NULL, NULL, NULL, 1)
*/

--Same result as the SELECT above, but all columns, and using sproc, which is more conducive to MPP.
EXEC MarkovProcess2 @Order=@Order, @EventSet=@EventSet, @Transforms=@Transforms

--[END Code 22]