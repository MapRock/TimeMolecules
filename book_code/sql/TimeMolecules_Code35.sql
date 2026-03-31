USE [TimeSolution]
GO
--[START Code 35] - Three focused model results.]
--We're not interested in the details. We want to check the average of time customers spend in the restaurant.
/*
--Deprecated.

--1. Length of time, begin to end.
SELECT ModelID,Event1A,EventB,[Max],[Avg],[Min],[StDev],CoefVar,[Sum],
	[Rows],Prob,IsEntry,IsExit,FromCache
FROM dbo.[MarkovProcess](0, 'arrive,depart' ,1,NULL,NULL,NULL,1,NULL,NULL,NULL,1)

--2. From the time the party is seated until they depart.
SELECT ModelID,Event1A,EventB,[Max],[Avg],[Min],[StDev],CoefVar,[Sum],
	[Rows],Prob,IsEntry,IsExit,FromCache
FROM dbo.[MarkovProcess](0, 'seated,depart' ,1,NULL,NULL,NULL,1,NULL,NULL,NULL,1)

--3. From the time the party orders to the time they are served.
SELECT ModelID,Event1A,EventB,[Max],[Avg],[Min],[StDev],CoefVar,[Sum],
	[Rows],Prob,IsEntry,IsExit,FromCache
FROM dbo.[MarkovProcess](0, 'order,served' ,1,NULL,NULL,NULL,1,NULL,NULL,NULL,1)
*/

--@SessionID is part of effort to move the solution closer to being deployed on MPP.
DECLARE @SessionID UNIQUEIDENTIFIER=NEWID()

--1. Length of time, begin to end.
EXEC MarkovProcess2 0, 'arrive,depart' ,1,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,0,NULL, @SessionID
SELECT ModelID,Event1A,EventB,[Max],[Avg],[Min],[StDev],CoefVar,[Sum],
	[Rows],Prob,IsEntry,IsExit,FromCache
FROM WORK.MarkovProcess WHERE SessionID=@SessionID
DELETE FROM WORK.MarkovProcess WHERE SessionID=@SessionID

--2. From the time the party is seated until they depart.
EXEC MarkovProcess2 0, 'seated,depart' ,1,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,0,NULL, @SessionID
SELECT ModelID,Event1A,EventB,[Max],[Avg],[Min],[StDev],CoefVar,[Sum],
	[Rows],Prob,IsEntry,IsExit,FromCache
FROM WORK.MarkovProcess WHERE SessionID=@SessionID
DELETE FROM WORK.MarkovProcess WHERE SessionID=@SessionID

--3. From the time the party orders to the time they are served.
EXEC MarkovProcess2 0, 'order,served' ,1,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,0,NULL, @SessionID
SELECT ModelID,Event1A,EventB,[Max],[Avg],[Min],[StDev],CoefVar,[Sum],
	[Rows],Prob,IsEntry,IsExit,FromCache
FROM WORK.MarkovProcess WHERE SessionID=@SessionID
DELETE FROM WORK.MarkovProcess WHERE SessionID=@SessionID


--[END Code 35]