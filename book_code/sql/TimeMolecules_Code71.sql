USE [TimeSolution]
GO
--[START Code 71]
--Given the arrive event, what is the probability of leaving a big tip?
EXEC [dbo].[CreateUpdateBayesianProbabilities]
'arrive', 'bigtip', 'restaurantguest',NULL,NULL,NULL,NULL,NULL,'CASEID'
--Given the customer arrived and was greeted, what is the prob of leaving a big tip?
EXEC [dbo].[CreateUpdateBayesianProbabilities]
'arrive,greeted','bigtip','restaurantguest',NULL,NULL,NULL,NULL,NULL,'CASEID'
--Given the truck arrived at walmart2, what is the probability of going to walmart3?
EXEC [dbo].[CreateUpdateBayesianProbabilities]
'walmart2','walmart3','pickuproute',NULL,NULL,NULL,NULL,NULL,'DAY'
--[END Code 71]
