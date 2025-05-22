USE [TimeSolution]
GO
--[START Code 25 – Basic request for a Markov model.]
--The individual Events for @EventSet=restaurantguest (a group of event types) cases.
SELECT * 
FROM dbo.SelectedEvents('restaurantguest',0, NULL,NULL,NULL,1,NULL,NULL,NULL) 
ORDER BY CaseID,[Rank]
--[END Code 25]