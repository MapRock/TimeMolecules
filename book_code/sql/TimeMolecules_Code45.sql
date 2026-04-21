USE [TimeSolution]
GO
--[START Code 45, Page 183, Time Molecules]
--What else is going on between events across cases?
DECLARE @ModelID INT=24
SELECT CaseID, EventID, Event, EventDate
FROM dbo.[IntersegmentEvents](@ModelID,'lv-csv1','homedepot1')

/*
The TVF, dbo.[IntersegmentEvents], is deprecated.
Below, the new stored procedure:

1. Takes us closer to MPP deployment by moving away from TVF.
2. Adds functionality to optionally define a lag and lead time in minutes.

*/

--Same as original TVF call above.
EXEC dbo.sp_IntersegmentEvents
    @ModelID = @ModelID,
    @EventA = 'lv-csv1',
    @EventB = 'homedepot1'

--With lag and lead minutes.
EXEC dbo.sp_IntersegmentEvents
    @ModelID = @ModelID,
    @EventA = 'lv-csv1',
    @EventB = 'homedepot1',
    @LagMinutes = 15,	--15 minutes before the datetime of @EventA.
    @LeadMinutes = 10;	--10 minutes after the datetime of @EventB.

--[END Code 45]

