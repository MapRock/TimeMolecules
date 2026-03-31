USE [TimeSolution]
GO
--[START Code 4 - Filtering events by a list of events.]
-- Retrieve events, filtered by specifying each event.
DECLARE @eventset NVARCHAR(1000)=
	'arrive, greeted, seated, intro, drinks, ccdeclined, charged, order, check, seated, served, bigtip, depart'
SELECT
	* 
FROM 
	dbo.SelectedEvents(@eventset,0,NULL,NULL,NULL,1,NULL,NULL,NULL) 
ORDER BY 
	CaseID,[Rank]

--Stored procedure version, which is more easily migrated to other platforms, including ultra-scalable.
EXEC sp_SelectedEvents @EventSet=@EventSet
--[END Code 4]