USE [TimeSolution]
GO
--[START Code 52]
DECLARE @StockEventSetHO NVARCHAR(50)='Big Drop-3%,No Move,Big Jump+3%'
DECLARE @MetricHO NVARCHAR(10)='Close'
DECLARE @StockHO NVARCHAR(20)='{"Stock":"MSFT"}'
DECLARE @level INT=1 --1st-order Markov model.
SELECT Event1A,EventB,[Rows],[Prob],round([Max],2) as [Max]
FROM dbo.[MarkovProcess](@level,
@StockEventSetHO,0,'01-01-2000','12-31-2000',NULL,1,@MetricHO,@StockHO,NULL,0 )
ORDER BY Event2A,EventB
SET @level=2 --2nd-order Markov model.
SELECT Event1A,Event2A,EventB,[Rows],[Prob],round([Max],2) as [Max]
FROM dbo.[MarkovProcess](@level,
@StockEventSetHO,0,'01-01-2000','12-31-2000',NULL,1,@MetricHO,@StockHO,NULL,0 )
ORDER BY Event2A,EventB
--[END Code 52]
