USE [TimeSolution]
GO
--[START Code 78]
/*
Code 78 is an example of how to find event sets that contain one or more specified events. The TVF, 
EventSetInclusion, looks for all event sets that contain the specified subset of events—in this case, 
event sets that include order or served.

This makes sense in the context of Code 77, where we found the handoff points of the kitchenorder event set.
Meaning there was an 'order' event that handed off to the 'order_received' event of the kitchenorder event set and
the 'order_ready' event of the kitchenorder event set handed off to some event 'served'.

So the point is, what possible event sets did kitchen order hand off to? That would be any event set 
that contains 'order' and 'served'.
*/


SELECT * FROM [EventSetInclusion]('order,served')
--[END Code 78]