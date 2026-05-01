USE [TimeSolution]
GO
--[START Code 8 - Code composed by ChatGPT.]
-- Insert 'myworkday' event set
DECLARE @EventSetKey VARBINARY(16);
EXEC [dbo].[InsertEventSets] 
    'wakeup,coffee,emails,breakfast,coding,lunch,writing,dinner,sleep', -- EventSet
    'myworkday',                           -- EventSetCode
    @EventSetKey OUTPUT,                   -- Output EventSetKey
    0;      
print @EventSetKey

--Should have only one row.
SELECT * FROM dbo.EventSets WHERE EventSetKey=@EventSetKey
--EventSetKey should be 0xBF33317B1586BC497130A7C7E1D07F0A
--[END Code 8]