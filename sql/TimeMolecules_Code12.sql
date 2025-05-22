USE [TimeSolution]
GO
--[START Code 12  – Insert (Load) into the Events fact table.]
INSERT INTO [TimeSolution].[dbo].[EventsFact]
	(CaseID, [Event],EventDate,CaseOrdinal)
	SELECT CaseID, 'SaleOrder' AS Event, OrderDate AS EventDate, 1 AS CaseOrdinal
		FROM [Work].[ETLADW]
		WHERE OrderDate IS NOT NULL
	UNION ALL 
	SELECT CaseID, 'SaleShip' AS Event, ShipDate AS EventDate, 2 AS CaseOrdinal
		FROM [Work].[ETLADW]
		WHERE ShipDate IS NOT NULL
	ORDER BY CaseID,CaseOrdinal
--[END Code 12]