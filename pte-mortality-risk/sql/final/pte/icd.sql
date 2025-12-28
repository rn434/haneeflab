/*

This file gathers the relevant ICD codes for TBI-related diagnoses that are 
used in determining whether a patient has PTE or not.


*/

-- Karlander TBI Classification (w/ translation to ICD-9 + history codes)

DROP TABLE IF EXISTS #ICD9TBICriteria;
SELECT
    *
INTO
    #ICD9TBICriteria
FROM (VALUES
    ('310.2%',  'Concussion', 'Concussion'),
    ('850%', 'Concussion', 'Concussion'),

    ('800%', 'Fracture', 'Fracture'),
    ('801%', 'Fracture', 'Fracture'),
    ('802%', 'Fracture', 'Fracture'),
    ('803%', 'Fracture', 'Fracture'),
    ('804%', 'Fracture', 'Fracture'),

    ('851%', 'Structural', 'Focal Cerebral'),
    ('853%', 'Structural', 'Focal Cerebral'),

    ('854.1%', 'Structural', 'Diffuse Cerebral'),


    ('852%', 'Structural', 'Extracerebral'),

    ('854.0%', 'Structural', NULL),

    ('905.0%', 'Fracture', 'Fracture'),
    ('907.0%', 'Structural', NULL),
    ('959.01%', NULL, NULL),
    ('V15.52%', NULL, NULL)
) AS criteria (ICD9Prefix, TBIClassChristensen, TBIClassKarlander)
;

DROP TABLE IF EXISTS #ICD10TBICriteria;
SELECT
    *
INTO
    #ICD10TBICriteria
FROM (VALUES
    ('F07.81%', 'Concussion', 'Concussion'),
    ('S06.0%', 'Concussion', 'Concussion'),

    ('S02.0%', 'Fracture', 'Fracture'),
    ('S02.1%', 'Fracture', 'Fracture'),
    ('S02.9%', 'Fracture', 'Fracture'),

    ('S06.3%', 'Structural', 'Focal Cerebral'),

    ('S06.1%', 'Structural', 'Diffuse Cerebral'),
    ('S06.2%', 'Structural', 'Diffuse Cerebral'),
    ('S06.8%', 'Structural', 'Diffuse Cerebral'),
    ('S06.9%', 'Structural', 'Diffuse Cerebral'),

    ('S06.4%', 'Structural', 'Extracerebral'),
    ('S06.5%', 'Structural', 'Extracerebral'),
    ('S06.6%', 'Structural', 'Extracerebral'),

    ('Z87.820%', NULL, NULL)
) AS criteria (ICD10Prefix, TBIClassChristensen, TBIClassKarlander)
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTBIICD9Karlander;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnTBIICD9Karlander (
    ICD9SID INT PRIMARY KEY,
    ICD9Code VARCHAR(10),
    TBIClassChristensen VARCHAR(20),
    TBIClassKarlander VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnTBIICD9Karlander (
    ICD9SID,
    ICD9Code, 
    TBIClassChristensen,
    TBIClassKarlander
)
SELECT
    icd.ICD9SID,
    icd.ICD9Code,
    crit.TBIClassChristensen,
    crit.TBIClassKarlander
FROM
    CDWWork.Dim.ICD9 icd
    INNER JOIN
    #ICD9TBICriteria crit
        ON
        icd.ICD9Code LIKE crit.ICD9Prefix
WHERE
    LEN(icd.ICD9Code) <= 10
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTBIICD10Karlander;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnTBIICD10Karlander (
    ICD10SID INT PRIMARY KEY,
    ICD10Code VARCHAR(10),
    TBIClassChristensen VARCHAR(20),
    TBIClassKarlander VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnTBIICD10Karlander (
    ICD10SID,
    ICD10Code, 
    TBIClassChristensen,
    TBIClassKarlander
)
SELECT
    icd.ICD10SID,
    icd.ICD10Code,
    crit.TBIClassChristensen,
    crit.TBIClassKarlander
FROM
    CDWWork.Dim.ICD10 icd
    INNER JOIN
    #ICD10TBICriteria crit
        ON
        icd.ICD10Code LIKE crit.ICD10Prefix
WHERE
    LEN(icd.ICD10Code) <= 10
;

-- AFHSD TBI Classification

DROP TABLE IF EXISTS #ICD9TBICriteriaDoD;
SELECT
    *
INTO
    #ICD9TBICriteriaDoD
FROM (VALUES
    ('310.2%', 'Mild'),
    
    ('850.[0159]', 'Mild'),
    ('850.11', 'Mild'),
    ('850.12', 'Moderate'),
    ('850.2', 'Moderate'),
    ('850.[34]', 'Severe'),
    
    ('851.[02468][012369]', 'Moderate'),
    ('851.[02468][45]', 'Severe'),
    
    ('852.[024][012369]', 'Moderate'),
    ('852.[024][45]', 'Severe'),
    
    ('853.0[012369]', 'Moderate'),
    ('853.0[45]', 'Severe'),
    
    ('854.0[012369]', 'Moderate'),
    ('854.0[45]', 'Severe'),
    
    ('851.[13579]%', 'Penetrating'),
    
    ('852.[135]%', 'Penetrating'),
    
    ('853.1%', 'Penetrating'),
    
    ('854.1%', 'Penetrating'),
    
    ('80[0134].[01234][012369]', 'Moderate'),
    ('80[0134].[01234][45]', 'Severe'),
    
    ('80[0134].[56789]%', 'Penetrating'),
    
    ('950.[123]', NULL),
    
    ('907.0', NULL),
    ('959.01', 'Mild'),
    
    ('V15.52', NULL)
) AS criteria (ICD9Prefix, TBIClassArmed)
;

DROP TABLE IF EXISTS #ICD10TBICriteriaDoD;
SELECT
    *
INTO
    #ICD10TBICriteriaDoD
FROM (VALUES
    ('F07.81%', 'Mild'),

    ('S04.0[234]%', 'Severe'),

    ('S06.0X[019]%', 'Mild'),
    ('S06.0X[234]%', 'Moderate'),
    ('S06.0X[5678]%', 'Severe'),

    ('S06.[129]X[012349A]%', 'Moderate'),
    ('S06.[129]X[5678]%', 'Severe'),

    ('S06.3[012345678][012349A]%', 'Moderate'),
    ('S06.3[012345678][5678]%', 'Severe'),

    ('S06.[456]X[012349A]%', 'Moderate'),
    ('S06.[456]X[5678]%', 'Severe'),

    ('S06.89[012349A]%', 'Moderate'),
    ('S06.89[5678]%', 'Severe'),

    ('S02.0%A', 'Moderate'),
    ('S02.0%B', 'Penetrating'),

    ('S02.10%A', 'Moderate'),
    ('S02.10%B', 'Penetrating'),

    ('S02.11[0AB]%A', 'Mild'),
    ('S02.11[0AB]%B', 'Penetrating'),

    ('S02.11[1CD]%A', 'Moderate'),
    ('S02.11[1CD]%B', 'Penetrating'),

    ('S02.11[2EF]%A', 'Mild'),
    ('S02.11[2EF]%B', 'Penetrating'),

    ('S02.113%A', 'Mild'),
    ('S02.113%B', 'Penetrating'),

    ('S02.11[8GH]%A', 'Moderate'),
    ('S02.11[8GH]%B', 'Penetrating'),

    ('S02.119', 'Moderate'),
    ('S02.119%A', 'Moderate'),
    ('S02.119%B', 'Penetrating'),

    ('S02.19X%A', 'Moderate'),
    ('S02.19X%B', 'Penetrating'),

    ('S02.8%A', 'Mild'),
    ('S02.8%B', 'Penetrating'),

    ('S02.91%A', 'Moderate'),
    ('S02.91%B', 'Penetrating'),

    ('S07.1%', 'Moderate'),

    ('Z87.820', 'Mild')
) AS criteria (ICD10Prefix, TBIClassArmed)
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTBIICD9DoD;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnTBIICD9DoD (
    ICD9SID INT PRIMARY KEY,
    ICD9Code VARCHAR(10),
    TBIClassArmed VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnTBIICD9DoD (
    ICD9SID,
    ICD9Code, 
    TBIClassArmed
)
SELECT
    icd.ICD9SID,
    icd.ICD9Code,
    crit.TBIClassArmed
FROM
    CDWWork.Dim.ICD9 icd
    INNER JOIN
    #ICD9TBICriteriaDoD crit
        ON
        icd.ICD9Code LIKE crit.ICD9Prefix
WHERE
    LEN(icd.ICD9Code) <= 10
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTBIICD10DoD;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnTBIICD10DoD (
    ICD10SID INT PRIMARY KEY,
    ICD10Code VARCHAR(10),
    TBIClassArmed VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnTBIICD10DoD (
    ICD10SID,
    ICD10Code, 
    TBIClassArmed
)
SELECT
    icd.ICD10SID,
    icd.ICD10Code,
    crit.TBIClassArmed
FROM
    CDWWork.Dim.ICD10 icd
    INNER JOIN
    #ICD10TBICriteriaDoD crit
        ON
        icd.ICD10Code LIKE crit.ICD10Prefix
WHERE
    LEN(icd.ICD10Code) <= 10
;

-- Combine ICD codes

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTBIICD9;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnTBIICD9 (
    ICD9SID INT PRIMARY KEY,
    ICD9Code VARCHAR(50),

    TBIClassChristensen VARCHAR(20),
    TBIClassKarlander VARCHAR(20),
    KarlanderAny BIT,

    TBIClassArmed VARCHAR(20),
    ArmedAny BIT
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnTBIICD9 (
    ICD9SID,
    ICD9Code, 

    TBIClassChristensen,
    TBIClassKarlander,
    KarlanderAny,

    TBIClassArmed,
    ArmedAny
)
SELECT
    COALESCE(dod.ICD9SID, karl.ICD9SID) AS ICD9SID,
    COALESCE(dod.ICD9Code, karl.ICD9Code) AS ICD9Code,

    karl.TBIClassChristensen,
    karl.TBIClassKarlander,
    CASE
        WHEN dod.ICD9SID IS NOT NULL THEN 1
        ELSE 0
    END AS KarlanderAny,
    
    dod.TBIClassArmed,
    CASE
        WHEN dod.ICD9SID IS NOT NULL THEN 1
        ELSE 0
    END AS ArmedAny
FROM
    ORD_Haneef_202402056D.Dflt.rnTBIICD9Karlander karl
    FULL JOIN
    ORD_Haneef_202402056D.Dflt.rnTBIICD9DoD dod
        ON
        karl.ICD9SID = dod.ICD9SID
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTBIICD10;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnTBIICD10 (
    ICD10SID INT PRIMARY KEY,
    ICD10Code VARCHAR(50),

    TBIClassChristensen VARCHAR(20),
    TBIClassKarlander VARCHAR(20),
    KarlanderAny BIT,

    TBIClassArmed VARCHAR(20),
    ArmedAny BIT
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnTBIICD10 (
    ICD10SID,
    ICD10Code, 
    
    TBIClassChristensen,
    TBIClassKarlander,
    KarlanderAny,

    TBIClassArmed,
    ArmedAny
)
SELECT
    COALESCE(dod.ICD10SID, karl.ICD10SID) AS ICD10SID,
    COALESCE(dod.ICD10Code, karl.ICD10Code) AS ICD10Code,
    
    karl.TBIClassChristensen,
    karl.TBIClassKarlander,
    CASE
        WHEN dod.ICD10SID IS NOT NULL THEN 1
        ELSE 0
    END AS KarlanderAny,

    
    dod.TBIClassArmed,
    CASE
        WHEN dod.ICD10SID IS NOT NULL THEN 1
        ELSE 0
    END AS ArmedAny
FROM
    ORD_Haneef_202402056D.Dflt.rnTBIICD10Karlander karl
    FULL JOIN
    ORD_Haneef_202402056D.Dflt.rnTBIICD10DoD dod
        ON
        karl.ICD10SID = dod.ICD10SID
;