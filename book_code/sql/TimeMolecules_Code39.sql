USE [TimeSolution]
GO
--[START Code 39 – Code that retrieves the two models created with Code 38.]
DECLARE @Metric NVARCHAR(50)=NULL --NULL means all metrics.
SELECT *
FROM 
	[dbo].[ModelEventsByProperty](
		'leavehome,heavytraffic,lighttraffic,arrivework', 0, NULL,
		NULL, NULL, 1, @Metric, NULL, NULL, NULL)
--[END Code 39]