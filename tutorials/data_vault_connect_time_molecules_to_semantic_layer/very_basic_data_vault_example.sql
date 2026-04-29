/*
    Data Vault 2.0 – Corrected Final Version
    ========================================
    • Link_Case_Event now uses CaseOrdinal (handles multiple same events per case)
    • One typed satellite per CaseTypeID
    • Hub_Date uses INT DateKey (yyyymmdd)
*/

USE [TimeSolution];
GO

-- Clean slate
DROP TABLE IF EXISTS DV.Sat_Case_Properties_17;
DROP TABLE IF EXISTS DV.Sat_Case_Properties_16;
DROP TABLE IF EXISTS DV.Sat_Case_Properties_15;
DROP TABLE IF EXISTS DV.Sat_Case_Properties_10;
DROP TABLE IF EXISTS DV.Sat_Case_Properties_9;
DROP TABLE IF EXISTS DV.Sat_Case_Properties_8;
DROP TABLE IF EXISTS DV.Sat_Case_Properties_6;
DROP TABLE IF EXISTS DV.Sat_Case_Properties_4;
DROP TABLE IF EXISTS DV.Sat_Case_Properties_3;
DROP TABLE IF EXISTS DV.Sat_Case_Properties_2;
DROP TABLE IF EXISTS DV.Sat_Case_Properties_1;
DROP TABLE IF EXISTS DV.Link_Case_Event;
DROP TABLE IF EXISTS DV.Hub_Date;
DROP TABLE IF EXISTS DV.Hub_Event;
DROP TABLE IF EXISTS DV.Hub_Case;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'DV')
    EXEC('CREATE SCHEMA DV');
GO

-- =============================================
-- HUBS
-- =============================================

CREATE TABLE DV.Hub_Case (
    HubCaseHashKey  VARBINARY(32) NOT NULL PRIMARY KEY,
    CaseID          INT NOT NULL,
    LoadDate        DATETIME2 NOT NULL,
    RecordSource    NVARCHAR(100) NOT NULL
);
INSERT INTO DV.Hub_Case
SELECT HASHBYTES('SHA2_256', CAST(CaseID AS NVARCHAR(20))), CaseID, GETDATE(), 'TimeMolecules.Cases'
FROM dbo.Cases;

CREATE TABLE DV.Hub_Event (
    HubEventHashKey VARBINARY(32) NOT NULL PRIMARY KEY,
    Event           NVARCHAR(50) NOT NULL,
    SourceID        INT NOT NULL,
    LoadDate        DATETIME2 NOT NULL,
    RecordSource    NVARCHAR(100) NOT NULL
);
INSERT INTO DV.Hub_Event
SELECT HASHBYTES('SHA2_256', CONCAT(Event, '|', SourceID)), Event, SourceID, GETDATE(), 'TimeMolecules.DimEvents'
FROM dbo.DimEvents;

CREATE TABLE DV.Hub_Date (
    HubDateHashKey VARBINARY(32) NOT NULL PRIMARY KEY,
    DateKey        INT NOT NULL,           -- yyyymmdd integer
    LoadDate       DATETIME2 NOT NULL,
    RecordSource   NVARCHAR(100) NOT NULL
);
INSERT INTO DV.Hub_Date
SELECT HASHBYTES('SHA2_256', CAST(DateKey AS NVARCHAR(8))), DateKey, GETDATE(), 'TimeMolecules.DimDate'
FROM dbo.DimDate;

-- =============================================
-- LINK (now correct – includes CaseOrdinal)
-- =============================================

CREATE TABLE DV.Link_Case_Event (
    LinkCaseEventHashKey VARBINARY(32) NOT NULL PRIMARY KEY,
    HubCaseHashKey       VARBINARY(32) NOT NULL,
    HubEventHashKey      VARBINARY(32) NOT NULL,
    CaseOrdinal          INT NOT NULL,           -- ← this makes each occurrence unique
    LoadDate             DATETIME2 NOT NULL,
    RecordSource         NVARCHAR(100) NOT NULL
);

INSERT INTO DV.Link_Case_Event
SELECT 
    HASHBYTES('SHA2_256', CONCAT(CAST(ef.CaseID AS NVARCHAR(20)), '|', ef.Event, '|', ef.SourceID, '|', ef.CaseOrdinal)),
    hc.HubCaseHashKey,
    he.HubEventHashKey,
    ef.CaseOrdinal,
    GETDATE(),
    'TimeMolecules.EventsFact'
FROM dbo.EventsFact ef
JOIN DV.Hub_Case hc ON hc.CaseID = ef.CaseID
JOIN DV.Hub_Event he ON he.Event = ef.Event AND he.SourceID = ef.SourceID;

-- =============================================
-- ONE SATELLITE PER CASETYPE (example for main ones)
-- =============================================

-- Restaurant (1)
CREATE TABLE DV.Sat_Case_Properties_1 (
    HubCaseHashKey     VARBINARY(32) NOT NULL,
    LoadDate           DATETIME2 NOT NULL,
    LoadEndDate        DATETIME2 NULL,
    HashDiff           VARBINARY(32) NOT NULL,
    RecordSource       NVARCHAR(MAX) NOT NULL,
    CustomerID         NVARCHAR(50) NULL,
    EmployeeID         NVARCHAR(50) NULL,
    LocationID         NVARCHAR(50) NULL,
    bigtip             FLOAT NULL,
    ccdeclined         BIT NULL,
    CustomerCompaint   NVARCHAR(200) NULL,
    Re_cook            BIT NULL,
    PropertiesJSON     NVARCHAR(MAX) NULL,
    PRIMARY KEY (HubCaseHashKey, LoadDate)
);

-- Poker (4)
CREATE TABLE DV.Sat_Case_Properties_4 (
    HubCaseHashKey     VARBINARY(32) NOT NULL,
    LoadDate           DATETIME2 NOT NULL,
    LoadEndDate        DATETIME2 NULL,
    HashDiff           VARBINARY(32) NOT NULL,
    RecordSource       NVARCHAR(MAX) NOT NULL,
    PlayersJSON        NVARCHAR(MAX) NULL,
    TournamentNumber   BIGINT NULL,
    button             INT NULL,
    seats              INT NULL,
    PropertiesJSON     NVARCHAR(MAX) NULL,
    PRIMARY KEY (HubCaseHashKey, LoadDate)
);

-- Cardiology (8)
CREATE TABLE DV.Sat_Case_Properties_8 (
    HubCaseHashKey     VARBINARY(32) NOT NULL,
    LoadDate           DATETIME2 NOT NULL,
    LoadEndDate        DATETIME2 NULL,
    HashDiff           VARBINARY(32) NOT NULL,
    RecordSource       NVARCHAR(MAX) NOT NULL,
    PatientMRN         NVARCHAR(50) NULL,
    age                INT NULL,
    gender             NVARCHAR(20) NULL,
    Diabetic           BIT NULL,
    PropertiesJSON     NVARCHAR(MAX) NULL,
    PRIMARY KEY (HubCaseHashKey, LoadDate)
);

-- =============================================
-- POPULATE the satellites (example for the three above)
-- =============================================

-- Populate Restaurant (1)
INSERT INTO DV.Sat_Case_Properties_1
SELECT 
    HASHBYTES('SHA2_256', CAST(cp.CaseID AS NVARCHAR(20))),
    GETDATE(),
    NULL,
    HASHBYTES('SHA2_256', CONCAT(cp.CaseID, MAX(cp.SourceID))),
    'TimeMolecules.vwCasePropertiesParsed',
    MAX(CASE WHEN cp.PropertyName = 'CustomerID' THEN cp.PropertyValueAlpha END),
    MAX(CASE WHEN cp.PropertyName = 'EmployeeID' THEN cp.PropertyValueAlpha END),
    MAX(CASE WHEN cp.PropertyName = 'LocationID' THEN cp.PropertyValueAlpha END),
    MAX(CASE WHEN cp.PropertyName = 'bigtip' THEN cp.PropertyValueNumeric END),
    MAX(CASE WHEN cp.PropertyName = 'ccdeclined' THEN cp.PropertyValueAlpha END),
    MAX(CASE WHEN cp.PropertyName = 'CustomerCompaint' THEN cp.PropertyValueAlpha END),
    MAX(CASE WHEN cp.PropertyName = 'Re-cook' THEN cp.PropertyValueAlpha  END),
    (SELECT * FROM (SELECT PropertyName, PropertyValueAlpha, PropertyValueNumeric 
                    FROM dbo.vwCasePropertiesParsed x 
                    WHERE x.CaseID = cp.CaseID) p FOR JSON PATH)
FROM dbo.vwCasePropertiesParsed cp
JOIN dbo.Cases c ON c.CaseID = cp.CaseID
WHERE c.CaseTypeID = 1
GROUP BY cp.CaseID;


/*
These two are kind of big.

INSERT INTO DV.Sat_Case_Properties_4
    (HubCaseHashKey, LoadDate, LoadEndDate, HashDiff, RecordSource,
     PlayersJSON, TournamentNumber, button, seats, PropertiesJSON)
SELECT 
    HASHBYTES('SHA2_256', CAST(cp.CaseID AS NVARCHAR(20)))          AS HubCaseHashKey,
    GETDATE()                                                       AS LoadDate,
    NULL                                                            AS LoadEndDate,
    HASHBYTES('SHA2_256', CONCAT(cp.CaseID, cp.SourceID))           AS HashDiff,
    'TimeMolecules.vwCasePropertiesParsed'                          AS RecordSource,

    MAX(CASE WHEN cp.PropertyName = 'Players'         THEN cp.PropertyValueAlpha END) AS PlayersJSON,
    MAX(CASE WHEN cp.PropertyName = 'TournamentNumber'THEN cp.PropertyValueNumeric END) AS TournamentNumber,
    MAX(CASE WHEN cp.PropertyName = 'button'          THEN cp.PropertyValueNumeric END) AS button,
    MAX(CASE WHEN cp.PropertyName = 'seats'           THEN cp.PropertyValueNumeric END) AS seats,

    (SELECT PropertyName, PropertyValueAlpha, PropertyValueNumeric 
     FROM dbo.vwCasePropertiesParsed x 
     WHERE x.CaseID = cp.CaseID 
     FOR JSON PATH)                                                 AS PropertiesJSON
FROM dbo.vwCasePropertiesParsed cp
JOIN dbo.Cases c ON c.CaseID = cp.CaseID
WHERE c.CaseTypeID = 4
GROUP BY cp.CaseID, cp.SourceID;


INSERT INTO DV.Sat_Case_Properties_8
    (HubCaseHashKey, LoadDate, LoadEndDate, HashDiff, RecordSource,
     PatientMRN, age, gender, Diabetic, PropertiesJSON)
SELECT 
    HASHBYTES('SHA2_256', CAST(cp.CaseID AS NVARCHAR(20)))          AS HubCaseHashKey,
    GETDATE()                                                       AS LoadDate,
    NULL                                                            AS LoadEndDate,
    HASHBYTES('SHA2_256', CONCAT(cp.CaseID, cp.SourceID))           AS HashDiff,
    'TimeMolecules.vwCasePropertiesParsed'                          AS RecordSource,

    MAX(CASE WHEN cp.PropertyName = 'PatientMRN' THEN cp.PropertyValueAlpha END) AS PatientMRN,
    MAX(CASE WHEN cp.PropertyName = 'age'        THEN cp.PropertyValueNumeric END) AS age,
    MAX(CASE WHEN cp.PropertyName = 'gender'     THEN cp.PropertyValueAlpha END) AS gender,
    MAX(CASE WHEN cp.PropertyName = 'Diabetic'   THEN cp.PropertyValueAlpha END) AS Diabetic,

    (SELECT PropertyName, PropertyValueAlpha, PropertyValueNumeric 
     FROM dbo.vwCasePropertiesParsed x 
     WHERE x.CaseID = cp.CaseID 
     FOR JSON PATH)                                                 AS PropertiesJSON
FROM dbo.vwCasePropertiesParsed cp
JOIN dbo.Cases c ON c.CaseID = cp.CaseID
WHERE c.CaseTypeID = 8
GROUP BY cp.CaseID, cp.SourceID;
*/

PRINT '✅ Corrected Data Vault model created.';
PRINT '   Link_Case_Event now includes CaseOrdinal → handles repeated events';
PRINT '   One satellite per CaseTypeID';
