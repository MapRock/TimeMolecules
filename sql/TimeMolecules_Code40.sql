USE [TimeSolution]
GO
--[START Code 40 – Analyze MSFT Close over two different years. ]
DECLARE @StockEventSet NVARCHAR(50)='Big Drop-3%,No Move,Big Jump+3%'
DECLARE @Metric NVARCHAR(10)='Close'
DECLARE @Stock NVARCHAR(20)='{"Stock":"MSFT"}'
--Day to Day events for the year 2000.
SELECT Event1A,EventB,[Rows],[Prob],[Max] FROM dbo.[MarkovProcess](
   1, @StockEventSet,0,'01-01-2000','12-31-2000',NULL,1,@Metric,@Stock,NULL,0)
--Day to Day events for the year 2008.
SELECT Event1A,EventB,[Rows],[Prob],[Max]  FROM dbo.[MarkovProcess](
   1, @StockEventSet,0,'01-01-2008','12-31-2008',NULL,1,@Metric,@Stock,NULL,0)
--[END Code 40]
