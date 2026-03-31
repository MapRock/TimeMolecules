USE [TimeSolution]
GO
--[START Code 44]
DECLARE @ModelID INT=24
SELECT * FROM ModelDrillThrough(@ModelID,'lv-csv1','homedepot1')
--[END Code 44]
