USE [TimeSolution]
GO
--[START Code 43 ]
--Retrieve events that make up the segment greeted->seated in ModelID=5.
SELECT CaseID,EventA,EventB,EventDate_A,EventDate_B,[Minutes],[Rank]
FROM ModelDrillThrough(5,'arrive','greeted')
--[END Code 43]
