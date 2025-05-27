USE [TimeSolution]
GO
--[START Code 00 - Fill CasePropertiesParsed and EventPropertiesParsed]
--First, we need to add the user (the person installing the dev environment) to the Time Molecules system.
	DECLARE @UID INT
    EXEC dbo.SetUserAccessBitmap 
      @SUSER_NAME = NULL, 
      @AccessBitmap = 7, --Access Users.AccessID of 1, 2, and 3.
      @DisplayAccessDetail = 1, 
      @UserID = @UID OUTPUT;
	PRINT @UID
	SELECT * FROM dbo.Users
/*
This should be done before the tutorials. These two tables are quite large, so I truncated them
before creating the .BAK file that is restored to your SQL Server instance.

The two tables, CasePropertiesParsed and EventPropertiesParsed are large and can be easily rebuilt.
So, I truncated them before creating the TimeSolution.bak file.
*/
	EXEC [dbo].[InsertCaseProperties] @CompleteRefresh=1 --1 means to truncate CasePropertiesParsed
	EXEC [dbo].[InsertEventProperties] @CompleteRefresh=1
--[END Code 00]