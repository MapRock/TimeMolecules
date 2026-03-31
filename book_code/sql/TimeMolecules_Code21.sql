USE [TimeSolution]
GO

--[START Code 21 – Markov model without using the transform.]
DECLARE @EventSet NVARCHAR(500)='leavehome,heavytraffic,moderatetraffic,lighttraffic,arrivework,returnhome'
DECLARE @Order INT=0
DECLARE @Transforms NVARCHAR(MAX)=NULL

/*
--SELECT version is being deprecated in favor of sproc version, which is more conducive towards MPP.

SELECT Event1A, EventB, Prob,[Rows] FROM dbo.[MarkovProcess](@Order,
	@EventSet, -- Event Set.
	0,NULL,NULL ,@Transforms, 1, NULL, NULL, NULL, 1)
*/

--Same result as the SELECT above, but all columns, and using sproc, which is more conducive to MPP.
EXEC MarkovProcess2 @Order=@Order, @EventSet=@EventSet, @Transforms=@Transforms

--[END Code 21]