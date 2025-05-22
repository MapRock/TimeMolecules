USE [TimeSolution]
GO
--[START Code 42 – Code that created ModelId=5. It’s the restaurant MM for employee 1 at location 1. ]
--This should be ModelID=4, which is referenced in the book.
DECLARE @ModelID INT
EXEC CreateUpdateMarkovProcess @ModelID OUTPUT,
	'restaurantguest',0,NULL,NULL,
	NULL,1,NULL,'{"EmployeeID":1,"LocationID":1}',NULL
--Display segments of the Markov Model we just created.
SELECT 
	[ModelID],[EventA],[EventB]
	,[Max],[Avg],[Min],[StDev],[CoefVar],[Sum]
	,[Rows],[Prob],[IsEntry],[IsExit]
FROM [dbo].[ModelEvents]
WHERE Modelid=@ModelID
--[END Code 42]
