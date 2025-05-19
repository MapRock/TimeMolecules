USE [TimeSolution]
GO
--[START Code 18 – Three ways the event set key is created.]
DECLARE @SetByOccurence NVARCHAR(50)='arrive,greeted,seated, order, served,check,depart'
DECLARE @SetPreSorted NVARCHAR(50)=' arrive,check, depart,greeted,order, seated,served'
DECLARE @NotSequence BIT=0
DECLARE @IsSequence BIT=1
--These two sets return 0x0CD81FF42053BE46A03E9CACA3D4D451
SELECT  [dbo].[EventSetKey](@SetByOccurence, @NotSequence) AS [Set_BCD]	
SELECT  [dbo].[EventSetKey](@SetPreSorted, @NotSequence) AS [Set_BCD]

--This sequence returns 0x68202A5558621FC045E6EBB091C4AD1F
SELECT  [dbo].[EventSetKey](@SetByOccurence, @IsSequence) AS [Seq_CBD]
--[END Code 18]