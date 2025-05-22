USE [TimeSolution]
GO
--[START Code 38 – Code that created two models only differing my metric. ]
DECLARE @EventSet NVARCHAR(100)='leavehome,heavytraffic,lighttraffic,arrivework'
EXEC CreateUpdateMarkovProcess 
	NULL,@EventSet ,
	0,NULL,NULL,NULL,1,'Fuel',NULL,NULL
EXEC CreateUpdateMarkovProcess 
	NULL,@EventSet ,
	0,NULL,NULL,NULL,1,'Time Between',NULL,NULL
--[END Code 38] 