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
--[END Code 8]