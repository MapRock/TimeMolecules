USE [TimeSolution]
GO
--[START Code 45]
SELECT CaseID, EventID, Event, EventDate
FROM dbo.[IntersegmentEvents](24,'lv-csv1','homedepot1')
--[END Code 45]
