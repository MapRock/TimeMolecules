/*
    Data Vault 2.0 Demo – Fixed for duplicate Event names across sources
    ===================================================================
    Hub_Event now uses (Event + SourceID) as the business key.
*/

USE [TimeSolution];
GO

-- Clean slate
DROP TABLE IF EXISTS DV.Sat_Event_Properties;
DROP TABLE IF EXISTS DV.Sat_Case_Properties;
DROP TABLE IF EXISTS DV.Link_Case_Event;
DROP TABLE IF EXISTS DV.Hub_Event;
DROP TABLE IF EXISTS DV.Hub_Case;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'DV')
    EXEC('CREATE SCHEMA DV');
GO

-- =============================================
-- HUBS (fixed Hub_Event)
-- =============================================

CREATE TABLE DV.Hub_Case (
    HubCaseHashKey  VARBINARY(32) NOT NULL PRIMARY KEY,
    CaseID          INT NOT NULL,
    LoadDate        DATETIME2 NOT NULL,
    RecordSource    NVARCHAR(100) NOT NULL
);

INSERT INTO DV.Hub_Case
SELECT 
    HASHBYTES('SHA2_256', CAST(CaseID AS NVARCHAR(20))),
    CaseID,
    GETDATE(),
    'TimeMolecules.Cases'
FROM dbo.Cases;

CREATE TABLE DV.Hub_Event (
    HubEventHashKey VARBINARY(32) NOT NULL PRIMARY KEY,
    Event           NVARCHAR(50) NOT NULL,
    SourceID        INT NOT NULL,
    LoadDate        DATETIME2 NOT NULL,
    RecordSource    NVARCHAR(100) NOT NULL
);

INSERT INTO DV.Hub_Event (HubEventHashKey, Event, SourceID, LoadDate, RecordSource)
SELECT 
    HASHBYTES('SHA2_256', CONCAT(Event, '|', SourceID)),
    Event,
    SourceID,
    GETDATE(),
    'TimeMolecules.DimEvents'
FROM dbo.DimEvents
WHERE Event IS NOT NULL;

-- =============================================
-- LINK (updated to use new Hub_Event)
-- =============================================

CREATE TABLE DV.Link_Case_Event (
    LinkCaseEventHashKey VARBINARY(32) NOT NULL,
    HubCaseHashKey       VARBINARY(32) NOT NULL,
    HubEventHashKey      VARBINARY(32) NOT NULL,
    LoadDate             DATETIME2 NOT NULL,
    RecordSource         NVARCHAR(100) NOT NULL
);

INSERT INTO DV.Link_Case_Event
SELECT 
    HASHBYTES('SHA2_256', CONCAT(CAST(ef.CaseID AS NVARCHAR(20)), '|', ef.Event, '|', ef.SourceID)),
    hc.HubCaseHashKey,
    he.HubEventHashKey,
    GETDATE(),
    'TimeMolecules.EventsFact'
FROM dbo.EventsFact ef
JOIN DV.Hub_Case hc ON hc.CaseID = ef.CaseID
JOIN DV.Hub_Event he ON he.Event = ef.Event AND he.SourceID = ef.SourceID;

PRINT '✅ Fixed Data Vault demo created successfully.';
PRINT '   Hubs: Hub_Case, Hub_Event (now includes SourceID)';
PRINT '   Link: Link_Case_Event';
