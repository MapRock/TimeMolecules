USE [TimeSolution]
GO
--[START Code 55]
SELECT *
FROM
dbo.BayesianProbability(
'greeted,seated,intro', --Sequence 1 (sequence of three events)
'bigtip', --Sequence 2 (sequence of 1 event)
'restaurantguest', --Event Set.
NULL,NULL,NULL,NULL,NULL,NULL)
--[END Code 55]
