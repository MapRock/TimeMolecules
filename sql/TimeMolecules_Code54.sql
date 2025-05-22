USE [TimeSolution]
GO
--[START Code 54]
SELECT *
FROM
dbo.BayesianProbability(
'arrive', --Sequence 1 (sequence of 1 event).
'drinks', --Sequence 2 (sequence of 1 event).
'restaurantguest', --Event Set.
NULL,NULL,NULL,NULL,NULL,NULL)
--[END Code 54]
