/*

This file gathers the relevant ICD codes for seizure and epilepsy diagnoses 
that are used in determining whether and when a patient meets epilepsy criteria.

TODO: VARCHAR(10) is throwing an error for unknown columns even though those won't exist after the join
- currently a WHERE clause is added, though it likely adds inefficiency

*/


DROP TABLE IF EXISTS #ICD9SeizureCriteria;
SELECT
    *
INTO
    #ICD9SeizureCriteria
FROM (VALUES
    ('345%', 'Epilepsy', 1),
    ('780.3%', 'Seizure Only', 0)
) AS criteria (ICD9Prefix, DxType, GabapentinFlag)
;

DROP TABLE IF EXISTS #ICD10SeizureCriteria;
SELECT
    *
INTO
    #ICD10SeizureCriteria
FROM (VALUES
    ('G40%', 'Epilepsy', 1),
    ('R40.4%', 'Seizure Only', 0),
    ('R56.1%', 'Seizure Only', 1),
    ('R56.9%', 'Seizure Only', 1)
) AS criteria (ICD10Prefix, DxType, GabapentinFlag)
;


DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnSeizureICD9;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnSeizureICD9 (
    ICD9SID INT PRIMARY KEY,
    ICD9Code VARCHAR(10),
    DxType VARCHAR(20),
    GabapentinFlag BIT
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnSeizureICD9 (
    ICD9SID,
    ICD9Code,
    DxType,
    GabapentinFlag
)
SELECT
    icd.ICD9SID,
    icd.ICD9Code,
    crit.DxType,
    crit.GabapentinFlag
FROM
    CDWWork.Dim.ICD9 icd
    INNER JOIN
    #ICD9SeizureCriteria crit
        ON icd.ICD9Code LIKE crit.ICD9Prefix
WHERE
    LEN(icd.ICD9Code) <= 10
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnSeizureICD10;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnSeizureICD10 (
    ICD10SID INT PRIMARY KEY,
    ICD10Code VARCHAR(10),
    DxType VARCHAR(20),
    GabapentinFlag BIT
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnSeizureICD10 (
    ICD10SID,
    ICD10Code,
    DxType,
    GabapentinFlag
)
SELECT
    icd.ICD10SID,
    icd.ICD10Code,
    crit.DxType,
    crit.GabapentinFlag
FROM
    CDWWork.Dim.ICD10 icd
    INNER JOIN
    #ICD10SeizureCriteria crit
        ON icd.ICD10Code LIKE crit.ICD10Prefix
WHERE
    LEN(icd.ICD10Code) <= 10
;

