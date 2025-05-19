--[START Code 8  – Code for importing sales events from AdventureWorksDW into a temporary table #ETLADW]
USE AdventureWorksDW2017
GO
DROP TABLE IF EXISTS [TimeSolution].[WORK].ETLADW--Global temp table so Code09 can find it.
SELECT 
  [OrderDate], [ShipDate],
  [SalesOrderNumber]+'-'+CAST([SalesOrderLineNumber] AS VARCHAR(20)) AS NaturalKey,
  ROW_NUMBER() OVER (ORDER BY [SalesOrderNumber], [SalesOrderLineNumber]) AS CaseID ,
  '{"SalesAmount":'+CAST(SalesAmount AS VARCHAR(20))+
    ',"OrderQuantity":'+CAST(OrderQuantity AS VARCHAR(20))+
    ',"CustomerKey":'+CAST(CustomerKey AS VARCHAR(20))+
    ',"ProductKey":'+CAST(ProductKey AS VARCHAR(20))+
  '}' AS Properties
INTO [TimeSolution].[WORK].ETLADW-- Write to temp table for follow-ups to the data.
FROM [dbo].[FactInternetSales]
-- Note that some values are packaged in a JSON, as discussed regarding event properties.

-- Display the result.
SELECT * FROM [TimeSolution].[WORK].ETLADW
-- Drop #ETLADW temp table later.
GO
USE [TimeSolution]
GO

