/*

This file creates ICD9 and ICD10 tables for intractable epilepsy.

*/

DROP TABLE IF EXISTS #ICD9IntractableCriteria;
SELECT
    *
INTO
    #ICD9IntractableCriteria
FROM (VALUES
    ('345.[01456789]1')
) AS criteria (ICD9Prefix)
;

DROP TABLE IF EXISTS #ICD10IntractableCriteria;
SELECT
    *
INTO
    #ICD10IntractableCriteria
FROM (VALUES
    ('G40.[012349ABC]1%'),
    ('G40.8%[34]')
) AS criteria (ICD10Prefix)
;


DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnIntractableICD9;
SELECT
    icd.ICD9SID,
    icd.ICD9Code
INTO
    SCS_EEGUtil.EEG.rnIntractableICD9
FROM
    CDWWork.Dim.ICD9 icd
    INNER JOIN
    #ICD9IntractableCriteria crit
        ON icd.ICD9Code LIKE crit.ICD9Prefix
WHERE
    LEN(icd.ICD9Code) <= 10
;

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnIntractableICD10;
SELECT
    icd.ICD10SID,
    icd.ICD10Code
INTO
    SCS_EEGUtil.EEG.rnIntractableICD10
FROM
    CDWWork.Dim.ICD10 icd
    INNER JOIN
    #ICD10IntractableCriteria crit
        ON icd.ICD10Code LIKE crit.ICD10Prefix
WHERE
    LEN(icd.ICD10Code) <= 10
;
