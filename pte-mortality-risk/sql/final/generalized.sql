DROP TABLE IF EXISTS #ICD9GeneralizedCriteria;
SELECT
    *
INTO
    #ICD9GeneralizedCriteria
FROM (VALUES
    ('345.[0123]%', 'Generalized'),
    ('345.[457]%', 'Focal')
) AS criteria (ICD9Prefix, EpilepsyType)
;

DROP TABLE IF EXISTS #ICD10GeneralizedCriteria;
SELECT
    *
INTO
    #ICD10GeneralizedCriteria
FROM (VALUES
    ('G40.[0125]%', 'Focal'),
    ('G40.[3A4]%', 'Generalized')
) AS criteria (ICD10Prefix, EpilepsyType)
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnGeneralizedICD9;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnGeneralizedICD9 (
    ICD9SID INT PRIMARY KEY,
    ICD9Code VARCHAR(10),
    EpilepsyType VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnGeneralizedICD9 (
    ICD9SID,
    ICD9Code,
    EpilepsyType
)
SELECT
    icd.ICD9SID,
    icd.ICD9Code,
    crit.EpilepsyType
FROM
    CDWWork.Dim.ICD9 icd
    INNER JOIN
    #ICD9GeneralizedCriteria crit
        ON
        icd.ICD9Code LIKE crit.ICD9Prefix
WHERE
    LEN(icd.ICD9Code) <= 10
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnGeneralizedICD10;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnGeneralizedICD10 (
    ICD10SID INT PRIMARY KEY,
    ICD10Code VARCHAR(10),
    EpilepsyType VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnGeneralizedICD10 (
    ICD10SID,
    ICD10Code,
    EpilepsyType
)
SELECT
    icd.ICD10SID,
    icd.ICD10Code,
    crit.EpilepsyType
FROM
    CDWWork.Dim.ICD10 icd
    INNER JOIN
    #ICD10GeneralizedCriteria crit
        ON
        icd.ICD10Code LIKE crit.ICD10Prefix
WHERE
    LEN(icd.ICD10Code) <= 10
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnGeneralized;
WITH GeneralizedDx AS (
    SELECT
        *
    FROM (
        SELECT
            dx.PatientSID,
            icd.EpilepsyType
        FROM
            ##AllDx dx
            INNER JOIN
            ORD_Haneef_202402056D.Dflt.rnGeneralizedICD9 icd
                ON
                dx.ICD9SID = icd.ICD9SID
        
        UNION ALL

        SELECT
            dx.PatientSID,
            icd.EpilepsyType
        FROM
            ##AllDx dx
            INNER JOIN
            ORD_Haneef_202402056D.Dflt.rnGeneralizedICD10 icd
                ON
                dx.ICD10SID = icd.ICD10SID
    ) merged
    WHERE
        merged.EpilepsyType = 'Generalized'
) 
SELECT DISTINCT
    coh.PatientICN
INTO
    ORD_Haneef_202402056D.Dflt.rnGeneralized
FROM
    GeneralizedDx generalized
    INNER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        generalized.PatientSID = coh.PatientSID
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnEpilepsyFinal epi
        ON
        coh.PatientICN = epi.PatientICN
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnFocal;
WITH GeneralizedDx AS (
    SELECT
        *
    FROM (
        SELECT
            dx.PatientSID,
            icd.EpilepsyType
        FROM
            ##AllDx dx
            INNER JOIN
            ORD_Haneef_202402056D.Dflt.rnGeneralizedICD9 icd
                ON
                dx.ICD9SID = icd.ICD9SID
        
        UNION ALL

        SELECT
            dx.PatientSID,
            icd.EpilepsyType
        FROM
            ##AllDx dx
            INNER JOIN
            ORD_Haneef_202402056D.Dflt.rnGeneralizedICD10 icd
                ON
                dx.ICD10SID = icd.ICD10SID
    ) merged
    WHERE
        merged.EpilepsyType = 'Focal'
) 
SELECT DISTINCT
    coh.PatientICN
INTO
    ORD_Haneef_202402056D.Dflt.rnFocal
FROM
    GeneralizedDx generalized
    INNER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        generalized.PatientSID = coh.PatientSID
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnEpilepsyFinal epi
        ON
        coh.PatientICN = epi.PatientICN
;


DROP TABLE IF EXISTS #ICD9EpilepsyPrefixCriteria;
SELECT
    *
INTO
    #ICD9EpilepsyPrefixCriteria
FROM (VALUES
    ('345%')
) AS criteria (ICD9Prefix)
;

DROP TABLE IF EXISTS #ICD10EpilepsyPrefixCriteria;
SELECT
    *
INTO
    #ICD10EpilepsyPrefixCriteria
FROM (VALUES
    ('G40%')
) AS criteria (ICD10Prefix)
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnEpilepsyPrefixICD9;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnEpilepsyPrefixICD9 (
    ICD9SID INT PRIMARY KEY,
    ICD9Code VARCHAR(10),
    EpilepsyPrefix VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnEpilepsyPrefixICD9 (
    ICD9SID,
    ICD9Code,
    EpilepsyPrefix
)
SELECT
    icd.ICD9SID,
    icd.ICD9Code,
    SUBSTRING(icd.ICD9Code, 1, 5) AS EpilepsyPrefix
FROM
    CDWWork.Dim.ICD9 icd
    INNER JOIN
    #ICD9EpilepsyPrefixCriteria crit
        ON
        icd.ICD9Code LIKE crit.ICD9Prefix
WHERE
    LEN(icd.ICD9Code) <= 10
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnEpilepsyPrefixICD10;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnEpilepsyPrefixICD10 (
    ICD10SID INT PRIMARY KEY,
    ICD10Code VARCHAR(10),
    EpilepsyPrefix VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnEpilepsyPrefixICD10 (
    ICD10SID,
    ICD10Code,
    EpilepsyPrefix
)
SELECT
    icd.ICD10SID,
    icd.ICD10Code,
    SUBSTRING(icd.ICD10Code, 1, 5) AS EpilepsyPrefix
FROM
    CDWWork.Dim.ICD10 icd
    INNER JOIN
    #ICD10EpilepsyPrefixCriteria crit
        ON
        icd.ICD10Code LIKE crit.ICD10Prefix
WHERE
    LEN(icd.ICD10Code) <= 10
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnEpilepsyPrefixes;
WITH GeneralizedDx AS (
    SELECT
        *
    FROM (
        SELECT
            dx.PatientSID,
            icd.EpilepsyPrefix
        FROM
            ##AllDx dx
            INNER JOIN
            ORD_Haneef_202402056D.Dflt.rnEpilepsyPrefixICD9 icd
                ON
                dx.ICD9SID = icd.ICD9SID
        
        UNION ALL

        SELECT
            dx.PatientSID,
            icd.EpilepsyPrefix
        FROM
            ##AllDx dx
            INNER JOIN
            ORD_Haneef_202402056D.Dflt.rnEpilepsyPrefixICD10 icd
                ON
                dx.ICD10SID = icd.ICD10SID
    ) merged
)
SELECT
    generalized.EpilepsyPrefix,
    COUNT(*) AS N
INTO
    ORD_Haneef_202402056D.Dflt.rnEpilepsyPrefixes
FROM
    GeneralizedDx generalized
GROUP BY
    EpilepsyPrefix
;

DROP TABLE IF EXISTS #EpilepsyPrefixCategories;
WITH GeneralizedDx AS (
    SELECT
        *
    FROM (
        SELECT
            dx.PatientSID,
            icd.EpilepsyPrefix
        FROM
            ##AllDx dx
            INNER JOIN
            ORD_Haneef_202402056D.Dflt.rnEpilepsyPrefixICD9 icd
                ON
                dx.ICD9SID = icd.ICD9SID
        
        UNION ALL

        SELECT
            dx.PatientSID,
            icd.EpilepsyPrefix
        FROM
            ##AllDx dx
            INNER JOIN
            ORD_Haneef_202402056D.Dflt.rnEpilepsyPrefixICD10 icd
                ON
                dx.ICD10SID = icd.ICD10SID
    ) merged
)
SELECT
    coh.PatientICN,
    generalized.EpilepsyPrefix
INTO
   #EpilepsyPrefixCategories
FROM
    GeneralizedDx generalized
    INNER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        generalized.PatientSID = coh.PatientSID
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnEpilepsyPrefixCategories;
SELECT
    PatientICN,
    MAX(CASE WHEN EpilepsyPrefix = '345.0' THEN 1 ELSE 0 END) AS ICD93450,
    MAX(CASE WHEN EpilepsyPrefix = '345.1' THEN 1 ELSE 0 END) AS ICD93451,
    MAX(CASE WHEN EpilepsyPrefix = '345.2' THEN 1 ELSE 0 END) AS ICD93452,
    MAX(CASE WHEN EpilepsyPrefix = '345.3' THEN 1 ELSE 0 END) AS ICD93453,
    MAX(CASE WHEN EpilepsyPrefix = '345.4' THEN 1 ELSE 0 END) AS ICD93454,
    MAX(CASE WHEN EpilepsyPrefix = '345.5' THEN 1 ELSE 0 END) AS ICD93455,
    MAX(CASE WHEN EpilepsyPrefix = '345.6' THEN 1 ELSE 0 END) AS ICD93456,
    MAX(CASE WHEN EpilepsyPrefix = '345.7' THEN 1 ELSE 0 END) AS ICD93457,
    MAX(CASE WHEN EpilepsyPrefix = '345.8' THEN 1 ELSE 0 END) AS ICD93458,
    MAX(CASE WHEN EpilepsyPrefix = '345.9' THEN 1 ELSE 0 END) AS ICD93459,
    MAX(CASE WHEN EpilepsyPrefix = 'G40.0' THEN 1 ELSE 0 END) AS ICD10G400,
    MAX(CASE WHEN EpilepsyPrefix = 'G40.1' THEN 1 ELSE 0 END) AS ICD10G401,
    MAX(CASE WHEN EpilepsyPrefix = 'G40.2' THEN 1 ELSE 0 END) AS ICD10G402,
    MAX(CASE WHEN EpilepsyPrefix = 'G40.3' THEN 1 ELSE 0 END) AS ICD10G403,
    MAX(CASE WHEN EpilepsyPrefix = 'G40.4' THEN 1 ELSE 0 END) AS ICD10G404,
    MAX(CASE WHEN EpilepsyPrefix = 'G40.5' THEN 1 ELSE 0 END) AS ICD10G405,
    MAX(CASE WHEN EpilepsyPrefix = 'G40.8' THEN 1 ELSE 0 END) AS ICD10G408,
    MAX(CASE WHEN EpilepsyPrefix = 'G40.9' THEN 1 ELSE 0 END) AS ICD10G409,
    MAX(CASE WHEN EpilepsyPrefix = 'G40.A' THEN 1 ELSE 0 END) AS ICD10G40A,
    MAX(CASE WHEN EpilepsyPrefix = 'G40.B' THEN 1 ELSE 0 END) AS ICD10G40B,
    MAX(CASE WHEN EpilepsyPrefix = 'G40.C' THEN 1 ELSE 0 END) AS ICD10G40C
INTO
    ORD_Haneef_202402056D.Dflt.rnEpilepsyPrefixCategories
FROM
    #EpilepsyPrefixCategories
GROUP BY
    PatientICN
;



select * from ORD_Haneef_202402056D.Dflt.rnEpilepsyPrefixes order by EpilepsyPrefix

select count(*) from ORD_Haneef_202402056D.Dflt.rnFocal focal inner join ORD_Haneef_202402056D.Dflt.rnGeneralized gen on focal.PatientICN = gen.PatientICN