/*

This file identifies acute diagnoses that can lead to epilepsy. The goal is to 
exclude mortality from these acute diagnoses to focus in on chronic epilepsy-
related mortality causes.

Estimated runtime = 8 m.

*/


-- 1. Acute Diagnosis ICD codes (estimated runtime = 1 m.)

DROP TABLE IF EXISTS #ICD9AcuteEventCriteria;
SELECT *
INTO #ICD9AcuteEventCriteria
FROM (VALUES
    ('43[01234678]%', 'Stroke'),
    ('80[01234]%', 'TBI'),
    ('85[01234]%', 'TBI'),
    ('959.01%', 'TBI'),
    ('310.2%', 'TBI'),
    ('191%', 'Brain Tumor'),
    ('198.3%', 'Brain Tumor'),
    ('225.[012]%', 'Brain Tumor'),
    ('237.5%', 'Brain Tumor'),
    ('239.6%', 'Brain Tumor'),
    ('32[0123456]%', 'CNS Infection'),
    ('046%', 'CNS Infection')
) AS criteria (ICD9Prefix, Diagnosis);

DROP TABLE IF EXISTS #ICD10AcuteEventCriteria;
SELECT *
INTO #ICD10AcuteEventCriteria
FROM (VALUES
    ('I6%', 'Cerebrovascular Disease'),
    ('S02%', 'TBI'),
    ('S06%', 'TBI'),
    ('F07.81%', 'TBI'),
    ('C71%', 'Brain Tumor'),
    ('C79.3%', 'Brain Tumor'),
    ('D3[23]%', 'Brain Tumor'),
    ('D43%', 'Brain Tumor'),
    ('G0[0123456789]%', 'CNS Infection')
) AS criteria (ICD10Prefix, Diagnosis);

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnAcuteEventICD9;
SELECT DISTINCT icd.ICD9SID,
    icd.ICD9Code,
    crit.Diagnosis
INTO SCS_EEGUtil.EEG.rnAcuteEventICD9
FROM CDWWork.Dim.ICD9 icd
    INNER JOIN #ICD9AcuteEventCriteria crit
        ON icd.ICD9Code LIKE crit.ICD9Prefix
WHERE LEN(icd.ICD9Code) <= 10;

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnAcuteEventICD10;
SELECT DISTINCT icd.ICD10SID,
    icd.ICD10Code,
    crit.Diagnosis
INTO SCS_EEGUtil.EEG.rnAcuteEventICD10
FROM CDWWork.Dim.ICD10 icd
    INNER JOIN #ICD10AcuteEventCriteria crit
        ON icd.ICD10Code LIKE crit.ICD10Prefix
WHERE LEN(icd.ICD10Code) <= 10;


-- 2. Gather acute event diagnoses (estimated runtime = 7 m.)

DROP TABLE IF EXISTS #InitialDx;
WITH CombinedDx AS (
    SELECT pat.PatientICN,
        COALESCE(icd9.Diagnosis, icd10.Diagnosis) AS Diagnosis,
        CAST(dx.VDiagnosisDateTime AS DATE) AS DxDate
    FROM CDWWork.Patient.Patient pat
    INNER JOIN CDWWork.Outpat.VDiagnosis dx
        ON pat.PatientSID = dx.PatientSID
    LEFT JOIN SCS_EEGUtil.EEG.rnAcuteEventICD9 icd9
        ON dx.ICD9SID = icd9.ICD9SID
    LEFT JOIN SCS_EEGUtil.EEG.rnAcuteEventICD10 icd10
        ON dx.ICD10SID = icd10.ICD10SID
    WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL
    UNION ALL
    SELECT pat.PatientICN,
        COALESCE(icd9.Diagnosis, icd10.Diagnosis) AS Diagnosis,
        CAST(dx.DischargeDateTime AS DATE) AS DxDate
    FROM CDWWork.Patient.Patient pat
    INNER JOIN CDWWork.Inpat.InpatientDiagnosis dx
        ON pat.PatientSID = dx.PatientSID
    LEFT JOIN SCS_EEGUtil.EEG.rnAcuteEventICD9 icd9
        ON dx.ICD9SID = icd9.ICD9SID
    LEFT JOIN SCS_EEGUtil.EEG.rnAcuteEventICD10 icd10
        ON dx.ICD10SID = icd10.ICD10SID
    WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL)
SELECT PatientICN,
    Diagnosis,
    MIN(DxDate) AS DxDate
INTO #InitialDx
FROM CombinedDx
GROUP BY PatientICN, Diagnosis;

-- 3. Pivot operation to get each diagnosis as columns (estimated runtime = 1 m.)

DECLARE @columns NVARCHAR(MAX);
DECLARE @sql NVARCHAR(MAX);
DECLARE @min_columns NVARCHAR(MAX);

SELECT 
    @columns = STRING_AGG(QUOTENAME(Diagnosis), ',')
FROM (SELECT DISTINCT Diagnosis FROM #InitialDx) d;

SELECT 
    @min_columns = STRING_AGG('mn.' + QUOTENAME(Diagnosis) + ' AS ' + QUOTENAME(Diagnosis), ', ')
FROM (SELECT DISTINCT Diagnosis FROM #InitialDx) d;

SET @sql = '
;DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnAcuteEvent;
;WITH src AS (
    SELECT PatientICN, 
        Diagnosis, 
        DxDate
    FROM #InitialDx)
, min_pivot AS (
    SELECT *
    FROM src
    PIVOT (MIN(DxDate) FOR Diagnosis IN (' + @columns + ')) AS mn)
SELECT mn.PatientICN, ' + @min_columns + '
INTO SCS_EEGUtil.EEG.rnAcuteEvent
FROM min_pivot mn;
';

EXEC sp_executesql @sql;

SELECT COUNT(*) FROM SCS_EEGUtil.EEG.rnAcuteEvent;

