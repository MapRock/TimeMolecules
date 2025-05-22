USE [TimeSolution]
GO
--[START Code 11  – Insert (Load) sales from AdventureWorksDW into the Cases tables of Time Solution.]
--Be sure to run Code09 first. It creates #ETLADW
--Retrieve metadata (SourceID and CaseTypeID) for the data source
DECLARE @DatabaseName NVARCHAR(128)='AdventureWorksDW2017'
DECLARE @SourceID INT = 
  (SELECT SourceID FROM [TimeSolution].[dbo].[Sources] WHERE [Name]=@DatabaseName)
DECLARE @CaseTypeName NVARCHAR(128)='Internet Sale'

DECLARE @CaseTypeID INT = 
  (SELECT CaseTypeID FROM [TimeSolution].[dbo].CaseTypes WHERE [Name]=@CaseTypeName)

--Insert data from #ETLADW into CaseProperties and Cases tables.
INSERT INTO [TimeSolution].dbo.CaseProperties (CaseID, [Properties])
	SELECT CaseID, [Properties] FROM [Work].[ETLADW]
INSERT INTO [TimeSolution].dbo.Cases 
  (CaseID, NaturalKey,SourceID,CaseTypeID,AccessBitmap)
  SELECT CaseID, NaturalKey,@SourceID AS SourceID,@CaseTypeID, 7 FROM [Work].[ETLADW]
--[END Code 11]