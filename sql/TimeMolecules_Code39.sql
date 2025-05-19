USE [TimeSolution]
GO
--[START Code 39 – Code that retrieves only the model for Fuel. ]
DECLARE @Metric NVARCHAR(50)='Fuel'
SELECT *
FROM 
	[dbo].[ModelEventsByProperty](
		'leavehome,heavytraffic,lighttraffic,arrivework', 0, NULL,
		NULL, NULL, 1, @Metric, NULL, NULL, NULL) 
--[END Code 39]
