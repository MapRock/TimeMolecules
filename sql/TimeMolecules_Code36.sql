USE [TimeSolution]
GO
--[START Code 36  - Get model events for ModelIDs 5 and 7.]
--Display Model details.
SELECT *
FROM [dbo].[ModelEventsByProperty]('restaurantguest', 0, NULL, NULL, NULL, 1, NULL,'{"EmployeeID":1}', NULL, NULL)
WHERE ModelID IN (5,7)
--[END Code 36]
