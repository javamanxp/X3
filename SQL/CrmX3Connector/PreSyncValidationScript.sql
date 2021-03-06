/*****************************************************************************/
-- Author:				Bob Delamater
-- Create Date:			08/16/2016
-- Description:			Diagnostic Script For Sage CRM / X3 migrations
-- Use cases checked: 
--						1. Local menu 233. Find values outside the range. 
--						Anything outside the expected value range will
--						case an error 500 at migration time. Exists at 
--						at least up to connector 2.0
--
--						2. Locate special characters on the BPCUSTOMER
--						table. Usually this will show up in the customer 
--						company name as customers copy and paste values
--						from the internet.
--						Dependency: 
-- https://github.com/Delamater/SQL/blob/master/StringPatterns/GetNonAsciiCodes.sql
--
--						This exists in any version of the connector
--
--						3. Address length cannot exceed 40 characters
--						Can exist in any version of the connector. 
--						To resolve you must increase the CRM table 
--						through an ALTER TABLE script, or truncate the 
--						incoming data. 
/*****************************************************************************/


IF OBJECT_ID('dbo.CrmX3SyncPreValidationLogResults', 'U') IS NOT NULL
BEGIN
	PRINT 'Recreating dbo.CrmX3SyncPreValidationLogResults'
	DROP TABLE dbo.CrmX3SyncPreValidationLogResults
END
GO
CREATE TABLE dbo.CrmX3SyncPreValidationLogResults
(
	ID					INT IDENTITY(1,1) PRIMARY KEY,
	UseCaseFound		VARCHAR(MAX) NOT NULL,
	UseCaseDescription	VARCHAR(MAX) NOT NULL
)

/*****				Variable Set up				*****/
DECLARE @rowCnt INT
SET @rowCnt = 0

/***** Use Case 1: Local Menu 233 range check	*****/
-- It's possible to alter local menus, but the fieldMappings.inc CRM / X3 connector 
-- hard codes these values. So, any value outside the normal range (1-12) will cause a hard error
-- all the way up to at least connector 2.2. 
-- 
-- Find these values and report the records so a decision can be made on how to handle these

SELECT BPANUM_0, CCNCRM_0, CNTFNC_0
FROM x3v7_01.PRODUCTION.CONTACT 
WHERE 
	(CNTFNC_0 <1 OR CNTFNC_0 > 12) -- Known range from fieldMappings.inc

SET @rowCnt = @@ROWCOUNT
IF @rowCnt > 0
INSERT INTO dbo.CrmX3SyncPreValidationLogResults(UseCaseFound, UseCaseDescription)
SELECT 1, 'Local Menu 233 Outside Range - Record Count: ' + CAST(@rowCnt AS VARCHAR(25))

-- Reinit Row Count
SET @rowCnt = 0


/***** Use Case 2: Special Characters			*****/
IF OBJECT_ID('uspFindNonAsciiFields', 'P') IS NULL
BEGIN
	SELECT 'uspFindNonAsciiFields does not exist. Please compile this stored procedure before continuing. End of script. ' ScriptFailure, 
	'https://raw.githubusercontent.com/Delamater/SQL/master/StringPatterns/GetNonAsciiCodes.sql' GetAndCompileMe
	RETURN -- End script
END


DECLARE @ObjectIDs AS dbo.ObjectIds
INSERT INTO @ObjectIDs(ObjectID, SchemaName, TableName)
SELECT t.object_id, s.name, t.name
FROM sys.tables t
	INNER JOIN sys.schemas s
		ON s.schema_id = t.schema_id
		AND t.name IN
		(
			'BPCUSTOMER', 'CONTACT', 'CONTACTCRM'
		)
WHERE s.name = 'SEED'
EXEC uspFindNonAsciiFields @ObjectIDs, 31, 126

SET @rowCnt = @@ROWCOUNT
IF @rowCnt > 0
INSERT INTO dbo.CrmX3SyncPreValidationLogResults(UseCaseFound, UseCaseDescription)
SELECT 2, 'Special Characters - Record Count: ' + CAST(@rowCnt AS VARCHAR(25))

-- Reinit Row Count
SET @rowCnt = 0


/***** Use Case 3: Special Characters			*****/
SELECT LEN(BPAADDLIG_0), LEN(BPAADDLIG_1), * 
FROM PRODUCTION.BPADDRESS 
WHERE 
	LEN(BPAADDLIG_0) >= 41
	OR LEN(BPAADDLIG_1) >= 41
	OR LEN(BPAADDLIG_2) >=41


SET @rowCnt = @@ROWCOUNT
IF @rowCnt > 0
INSERT INTO dbo.CrmX3SyncPreValidationLogResults(UseCaseFound, UseCaseDescription)
SELECT 3, 'Address Length - Record Count: ' + CAST(@rowCnt AS VARCHAR(25))

SET @rowCnt = @@ROWCOUNT
IF @rowCnt > 0
INSERT INTO dbo.CrmX3SyncPreValidationLogResults(UseCaseFound, UseCaseDescription)
SELECT 3, 'Address Length- Record Count: ' + CAST(@rowCnt AS VARCHAR(25))

-- Reinit Row Count
SET @rowCnt = 0





/*****				Report Results				*****/
SELECT * FROM dbo.CrmX3SyncPreValidationLogResults
