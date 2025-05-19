USE [TimeSolution]
GO
--[START Code 20 – Markov model without using the transform.]
SELECT Event1A, EventB, Prob,[Rows] FROM dbo.[MarkovProcess](0,
	'leavehome,heavytraffic,moderatetraffic,lighttraffic,arrivework,returnhome', -- Event Set.
	0,NULL,NULL ,NULL, 1, NULL, NULL, NULL, 1)
--[END Code 20]