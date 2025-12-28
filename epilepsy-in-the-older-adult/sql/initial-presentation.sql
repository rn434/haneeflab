/*

This file determines the initial seizure presentation for all epilepsy patients.

Estimated runtime = 8 m.

*/


-- 1. First Seizure ICD codes (estimated runtime = 1 m.)

DROP TABLE IF EXISTS #ICD9IndexEpisodeCriteria;
SELECT *
INTO #ICD9IndexEpisodeCriteria
FROM (VALUES
    ('345%', 'Epilepsy'),
    ('780.3%', 'Convulsions'),
    ('780.2%', 'Syncope'),
    ('435.9%', 'TIA'),
    ('43[01234678]%', 'Stroke'),
    -- ('437.7%', 'Transient global amnesia'),
    ('293.0%', 'Altered Mental Status'),
    ('348.3[019]%', 'Altered Mental Status'),
    ('780.02%', 'Altered Mental Status'),
    ('780.97%', 'Altered Mental Status'),
    -- ('293.0%', 'Delirium'),
    -- ('348.3[019]%', 'Encephalopathy'),
    -- ('780.02%', 'Transient alteration of awareness'),
    -- ('780.97%', 'Disorientation / Altered mental status, unspecified'),
    ('300.11%', 'FDS'),
    -- ('V15.88%', 'Repeated falls'), -- poor translation
    ('784.3%', 'Aphasia')
) AS criteria (ICD9Prefix, Diagnosis);

DROP TABLE IF EXISTS #ICD10IndexEpisodeCriteria;
SELECT *
INTO #ICD10IndexEpisodeCriteria
FROM (VALUES
    ('G40%', 'Epilepsy'),
    ('R56%', 'Convulsions'),
    ('R55%', 'Syncope'),
    ('G45.9%', 'TIA'),
    ('I6%', 'Stroke'),
    -- ('G45.4%', 'Transient global amnesia'),
    ('F05%', 'Altered Mental Status'),
    ('G93.4[019]%', 'Altered Mental Status'),
    ('R40.4%', 'Altered Mental Status'),
    ('R41.0%', 'Altered Mental Status'),
    ('R41.82%', 'Altered Mental Status'),
    -- ('F05%', 'Delirium'),
    -- ('G93.4[019]%', 'Encephalopathy'),
    -- ('R40.4%', 'Transient alteration of awareness'),
    -- ('R41.0%', 'Disorientation / Altered mental status, unspecified'),
    -- ('R41.82%', 'Disorientation / Altered mental status, unspecified'),
    ('F44.5%', 'FDS'),
    -- ('R29.6%', 'Repeated falls'),
    ('R47.01%', 'Aphasia')
) AS criteria (ICD10Prefix, Diagnosis);

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnIndexEpisodeICD9;
SELECT DISTINCT icd.ICD9SID,
    icd.ICD9Code,
    crit.Diagnosis
INTO SCS_EEGUtil.EEG.rnIndexEpisodeICD9
FROM CDWWork.Dim.ICD9 icd
    INNER JOIN #ICD9IndexEpisodeCriteria crit
        ON icd.ICD9Code LIKE crit.ICD9Prefix
WHERE LEN(icd.ICD9Code) <= 10;

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnIndexEpisodeICD10;
SELECT DISTINCT icd.ICD10SID,
    icd.ICD10Code,
    crit.Diagnosis
INTO SCS_EEGUtil.EEG.rnIndexEpisodeICD10
FROM CDWWork.Dim.ICD10 icd
    INNER JOIN #ICD10IndexEpisodeCriteria crit
        ON icd.ICD10Code LIKE crit.ICD10Prefix
WHERE LEN(icd.ICD10Code) <= 10;


-- 2. Gather initial seizure presentations (estimated runtime = 7 m.)

DROP TABLE IF EXISTS #InitialDx;
WITH CombinedDx AS (
    SELECT pat.PatientICN,
        COALESCE(icd9.Diagnosis, icd10.Diagnosis) AS Diagnosis,
        CAST(dx.VDiagnosisDateTime AS DATE) AS DxDate
    FROM CDWWork.Patient.Patient pat
    INNER JOIN CDWWork.Outpat.VDiagnosis dx
        ON pat.PatientSID = dx.PatientSID
    LEFT JOIN SCS_EEGUtil.EEG.rnIndexEpisodeICD9 icd9
        ON dx.ICD9SID = icd9.ICD9SID
    LEFT JOIN SCS_EEGUtil.EEG.rnIndexEpisodeICD10 icd10
        ON dx.ICD10SID = icd10.ICD10SID
    WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL
    UNION ALL
    SELECT pat.PatientICN,
        COALESCE(icd9.Diagnosis, icd10.Diagnosis) AS Diagnosis,
        CAST(dx.DischargeDateTime AS DATE) AS DxDate
    FROM CDWWork.Patient.Patient pat
    INNER JOIN CDWWork.Inpat.InpatientDiagnosis dx
        ON pat.PatientSID = dx.PatientSID
    LEFT JOIN SCS_EEGUtil.EEG.rnIndexEpisodeICD9 icd9
        ON dx.ICD9SID = icd9.ICD9SID
    LEFT JOIN SCS_EEGUtil.EEG.rnIndexEpisodeICD10 icd10
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
;DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnIndexEpisode;
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
INTO SCS_EEGUtil.EEG.rnIndexEpisode
FROM min_pivot mn;
';

EXEC sp_executesql @sql;

SELECT COUNT(*) FROM SCS_EEGUtil.EEG.rnIndexEpisode;

