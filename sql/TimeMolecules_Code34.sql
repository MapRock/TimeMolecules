USE [TimeSolution]
GO
--[START Code 34] - Three focused model results.]
--We're not interested in the details. We want to check the average of time customers spend in the restaurant.

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
--[END Code 34]