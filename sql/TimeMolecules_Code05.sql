USE [TimeSolution]
GO
--[START Code 5 - Insert Event Sets]
DECLARE @EventSetKey VARBINARY(16)
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
--[END Code 5]