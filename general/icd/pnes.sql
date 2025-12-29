/*

This file creates ICD9 and ICD10 tables for PNES.

*/

DROP TABLE IF EXISTS #ICD9PNESCriteria;
SELECT
    *
INTO
    #ICD9PNESCriteria
FROM (VALUES
    ('300.11')
) AS criteria (ICD9Prefix)
;

DROP TABLE IF EXISTS #ICD10PNESCriteria;
SELECT
    *
INTO
    #ICD10PNESCriteria
FROM (VALUES
    ('F44.5'),
    ('F44.9')
) AS criteria (ICD10Prefix)
;


DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnPNESICD9;
SELECT
    icd.ICD9SID,
    icd.ICD9Code
INTO
    SCS_EEGUtil.EEG.rnPNESICD9
FROM
    CDWWork.Dim.ICD9 icd 
    INNER JOIN #ICD9PNESCriteria crit
        ON icd.ICD9Code LIKE crit.ICD9Prefix
WHERE
    LEN(icd.ICD9Code) <= 10
;

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnPNESICD10;
SELECT
    icd.ICD10SID,
    icd.ICD10Code
INTO
    SCS_EEGUtil.EEG.rnPNESICD10
FROM
    CDWWork.Dim.ICD10 icd
    INNER JOIN #ICD10PNESCriteria crit
        ON icd.ICD10Code LIKE crit.ICD10Prefix
WHERE
    LEN(icd.ICD10Code) <= 10
;
