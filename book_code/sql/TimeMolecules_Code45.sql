USE [TimeSolution]
GO
--[START Code 45, Page 183, Time Molecules]
--What else is going on between events across cases?
DECLARE @ModelID INT=24
SELECT CaseID, EventID, Event, EventDate
FROM dbo.[IntersegmentEvents](@ModelID,'lv-csv1','homedepot1')
--[END Code 45]

