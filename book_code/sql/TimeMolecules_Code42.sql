USE [TimeSolution]
GO
--[START Code 42 – Code that created ModelId=5. It’s the restaurant MM for employee 1 at location 1. ]
--This should be ModelID=4, which is referenced in the book.
/*
The stored procedure, CreateUpdateMarkovProcess, is used to create and store a Markov Model.
It is idempotent, meaning it will refresh the model (with events from EventsFact) that might have been added) if it already exists - that is, the same
event set, date range, case and event level filters, etc. If all of those parameters are the same, then a new model will be created.
*/

--Appears on Page 181 of Time Molecules.
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
