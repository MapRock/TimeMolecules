USE [TimeSolution]
GO
--[START Code 13  – Delete the Internet Sales events from the Time Solution database.]
--Clean up this exercise.
DECLARE @SourceID INT=5 --AdventureWorksDW database in TimeSolution.
DELETE FROM [TimeSolution].[dbo].[EventsFact]
WHERE CaseID IN 
  (SELECT CaseID FROM [TimeSolution].[dbo].[Cases] WHERE SourceID = @SourceID)

DELETE FROM [TimeSolution].[dbo].[CaseProperties]
WHERE CaseID IN 
  (SELECT CaseID FROM [TimeSolution].[dbo].[Cases] WHERE SourceID = @SourceID)

DELETE FROM [TimeSolution].[dbo].[Cases] WHERE SourceID = @SourceID
DROP TABLE IF EXISTS [Work].[ETLADW]


--[END Code 13]