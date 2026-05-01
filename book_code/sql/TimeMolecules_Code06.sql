USE [TimeSolution]
GO
/*
This is an example of how to insert a new event set. An event set is a set of events
that is used to select events that are included in a Markov Model.

Appears on Page 136 of Time Molecules.
*/
--[START Code 6 - Insert Event Sets]
DECLARE @EventSetKey VARBINARY(16) --A hash primary key for the event set.
DECLARE @EventSet NVARCHAR(200)=
	'leavesite,walmart1,lv-walmart1,walmart2,lv-walmart2,csv1,lv-csv1,csv4,
       lv-csv4,csv5,lv-csv5,walmart3,lv-walmart3,homedepot1,lv-homedepot1,csv2,
       lv-csv2,returnsite'

EXEC [dbo].[InsertEventSets] 
	@EventSet=@EventSet,
	@EventSetCode =NULL,
-- Key of the inserted event set returned in @EventSetKey.
	@EventSetKey=@EventSetKey OUTPUT, 
	@IsSequence=0 -- IsSequence is a set, not a sequence.
PRINT @EventSetKey

--Should have only one row.
SELECT * FROM dbo.EventSets WHERE EventSetKey=@EventSetKey
--EventSetKey should be 0x3E652120B9AEFE5F7196E26B25494B6B
--[END Code 6]