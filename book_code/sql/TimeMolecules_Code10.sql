--[START Code 10  – Update CaseID with an offset so we don’t write over existing CaseIDs.]
USE [TimeSolution]
GO
--Be sure to run Code08 first. It creates ##ETLADW (a global temp table).
DECLARE @CaseID_OffSet INT=(SELECT MAX(CaseID) FROM [TimeSolution].dbo.CaseProperties)
UPDATE [TimeSolution].[WORK].ETLADW SET
	CaseID=CaseID+@CaseID_OffSet


--[END Code 10]