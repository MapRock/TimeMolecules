USE [TimeSolution]
GO
--[START Code 36  - Find models by selected properties.]
--Get models with the event set and CaseFilterProperties.
SELECT ModelID, CaseFilterProperties
FROM [dbo].[ModelsByParameters]('restaurantguest', 0, NULL, NULL, NULL, 1, NULL,'{"EmployeeID":1}', NULL, NULL,NULL)
--[END Code 36]