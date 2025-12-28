DROP TABLE IF EXISTS #ICD9TumorCriteria;
SELECT
    *
INTO
    #ICD9TumorCriteria
FROM (VALUES
    ('191%')
) AS criteria (ICD9Prefix)
;

DROP TABLE IF EXISTS #ICD10TumorCriteria;
SELECT
    *
INTO
    #ICD10TumorCriteria
FROM (VALUES
    ('C71%')
) AS criteria (ICD10Prefix)
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTumorICD9;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnTumorICD9 (
    ICD9SID INT PRIMARY KEY,
    ICD9Code VARCHAR(10)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnTumorICD9 (
    ICD9SID,
    ICD9Code
)
SELECT
    icd.ICD9SID,
    icd.ICD9Code
FROM
    CDWWork.Dim.ICD9 icd
    INNER JOIN
    #ICD9TumorCriteria crit
        ON
        icd.ICD9Code LIKE crit.ICD9Prefix
WHERE
    LEN(icd.ICD9Code) <= 10
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTumorICD10;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnTumorICD10 (
    ICD10SID INT PRIMARY KEY,
    ICD10Code VARCHAR(10)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnTumorICD10 (
    ICD10SID,
    ICD10Code
)
SELECT
    icd.ICD10SID,
    icd.ICD10Code
FROM
    CDWWork.Dim.ICD10 icd
    INNER JOIN
    #ICD10TumorCriteria crit
        ON
        icd.ICD10Code LIKE crit.ICD10Prefix
WHERE
    LEN(icd.ICD10Code) <= 10
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTumor;
WITH TumorDx AS (
    SELECT
        dx.PatientSID,
        dx.DxDate AS TumorDate
    FROM
        ##AllDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnTumorICD9 icd
            ON
            dx.ICD9SID = icd.ICD9SID
    
    UNION ALL

    SELECT
        dx.PatientSID,
        dx.DxDate AS TumorDate
    FROM
        ##AllDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnTumorICD10 icd
            ON
            dx.ICD10SID = icd.ICD10SID
)
SELECT DISTINCT
    coh.PatientICN
INTO
    ORD_Haneef_202402056D.Dflt.rnTumor
FROM
    TumorDx tumor
    INNER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        tumor.PatientSID = coh.PatientSID
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnEpilepsyFinal epi
        ON
        coh.PatientICN = epi.PatientICN
WHERE
    Tumor.TumorDate <= epi.DxDate
;