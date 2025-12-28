/*

This file gathers the relevant ICD codes for TBI-related diagnoses that are 
used in determining whether a patient has PTE or not.

TODO: VARCHAR(10) is throwing an error for unknown columns even though those won't exist after the join
- currently a WHERE clause is added, though it likely adds inefficiency

*/


DROP TABLE IF EXISTS #ICD9TBICriteria;
SELECT
    *
INTO
    #ICD9TBICriteria
FROM (VALUES
    ('310.2%',  'Concussive', 'Concussive', 'History'),
    ('850%', 'Concussive', 'Concussive', 'Event'),

    ('800%', 'Fracture', 'Fracture', 'Event'),
    ('801%', 'Fracture', 'Fracture', 'Event'),
    ('802%', 'Fracture', 'Fracture', 'Event'),
    ('803%', 'Fracture', 'Fracture', 'Event'),
    ('804%', 'Fracture', 'Fracture', 'Event'),

    ('851%', 'Structural', 'Focal Cerebral', 'Event'),
    ('853%', 'Structural', 'Focal Cerebral', 'Event'),

    ('854.1%', 'Structural', 'Diffuse Cerebral', 'Event'),


    ('852%', 'Structural', 'Extracerebral', 'Event'),

    ('854.0%', 'Structural', NULL, 'Event'),

    ('907.0%', 'Structural', NULL, 'History'),
    ('959.01%', NULL, NULL, 'Event'),
    ('V15.52%', NULL, NULL, 'History')
) AS criteria (ICD9Prefix, TBIClassChristensen, TBIClassKarlander, OccurrenceType)
;

DROP TABLE IF EXISTS #ICD10TBICriteria;
SELECT
    *
INTO
    #ICD10TBICriteria
FROM (VALUES
    ('F07.81%', 'Concussive', 'Concussive', 'History'),
    ('S06.0%A', 'Concussive', 'Concussive', 'Initial'),
    ('S06.0%D', 'Concussive', 'Concussive', 'Subsequent'),
    ('S06.0%S', 'Concussive', 'Concussive', 'Sequela'),

    ('S02.0%[AB]', 'Fracture', 'Fracture', 'Initial'),
    ('S02.0%[DGK]', 'Fracture', 'Fracture', 'Subsequent'),
    ('S02.0%S', 'Fracture', 'Fracture', 'Sequela'),
    ('S02.1%[AB]', 'Fracture', 'Fracture', 'Initial'),
    ('S02.1%[DGK]', 'Fracture', 'Fracture', 'Subsequent'),
    ('S02.1%S', 'Fracture', 'Fracture', 'Sequela'),
    -- ('S02.8%[AB]', 'Fracture', 'Fracture', 'Initial'),
    -- ('S02.8%[DGK]', 'Fracture', 'Fracture', 'Subsequent'),
    -- ('S02.8%S', 'Fracture', 'Fracture', 'Sequela'),
    ('S02.9%[AB]', 'Fracture', 'Fracture', 'Initial'),
    ('S02.9%[DGK]', 'Fracture', 'Fracture', 'Subsequent'),
    ('S02.9%S', 'Fracture', 'Fracture', 'Sequela'),

    ('S06.3%A', 'Structural', 'Focal Cerebral', 'Initial'),
    ('S06.3%D', 'Structural', 'Focal Cerebral', 'Subsequent'),
    ('S06.3%S', 'Structural', 'Focal Cerebral', 'Sequela'),

    ('S06.1%A', 'Structural', 'Diffuse Cerebral', 'Initial'),
    ('S06.1%D', 'Structural', 'Diffuse Cerebral', 'Subsequent'),
    ('S06.1%S', 'Structural', 'Diffuse Cerebral', 'Sequela'),
    ('S06.2%A', 'Structural', 'Diffuse Cerebral', 'Initial'),
    ('S06.2%D', 'Structural', 'Diffuse Cerebral', 'Subsequent'),
    ('S06.2%S', 'Structural', 'Diffuse Cerebral', 'Sequela'),
    ('S06.8%A', 'Structural', 'Diffuse Cerebral', 'Initial'),
    ('S06.8%D', 'Structural', 'Diffuse Cerebral', 'Subsequent'),
    ('S06.8%S', 'Structural', 'Diffuse Cerebral', 'Sequela'),
    ('S06.9%A', 'Structural', 'Diffuse Cerebral', 'Initial'),
    ('S06.9%D', 'Structural', 'Diffuse Cerebral', 'Subsequent'),
    ('S06.9%S', 'Structural', 'Diffuse Cerebral', 'Sequela'),

    ('S06.4%A', 'Structural', 'Extracerebral', 'Initial'),
    ('S06.4%D', 'Structural', 'Extracerebral', 'Subsequent'),
    ('S06.4%S', 'Structural', 'Extracerebral', 'Sequela'),
    ('S06.5%A', 'Structural', 'Extracerebral', 'Initial'),
    ('S06.5%D', 'Structural', 'Extracerebral', 'Subsequent'),
    ('S06.5%S', 'Structural', 'Extracerebral', 'Sequela'),
    ('S06.6%A', 'Structural', 'Extracerebral', 'Initial'),
    ('S06.6%D', 'Structural', 'Extracerebral', 'Subsequent'),
    ('S06.6%S', 'Structural', 'Extracerebral', 'Sequela'),

    ('Z87.820%', NULL, NULL, 'History')
) AS criteria (ICD10Prefix, TBIClassChristensen, TBIClassKarlander, OccurrenceType)
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTBIICD9;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnTBIICD9 (
    ICD9SID INT PRIMARY KEY,
    ICD9Code VARCHAR(10),
    TBIClassChristensen VARCHAR(20),
    TBIClassKarlander VARCHAR(20),
    OccurrenceType VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnTBIICD9 (
    ICD9SID,
    ICD9Code, 
    TBIClassChristensen,
    TBIClassKarlander,
    OccurrenceType
)
SELECT
    icd.ICD9SID,
    icd.ICD9Code,
    crit.TBIClassChristensen,
    crit.TBIClassKarlander,
    crit.OccurrenceType
FROM
    CDWWork.Dim.ICD9 icd
    INNER JOIN
    #ICD9TBICriteria crit
        ON
        icd.ICD9Code LIKE crit.ICD9Prefix
WHERE
    LEN(icd.ICD9Code) <= 10
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTBIICD10;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnTBIICD10 (
    ICD10SID INT PRIMARY KEY,
    ICD10Code VARCHAR(10),
    TBIClassChristensen VARCHAR(20),
    TBIClassKarlander VARCHAR(20),
    OccurrenceType VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnTBIICD10 (
    ICD10SID,
    ICD10Code, 
    TBIClassChristensen,
    TBIClassKarlander,
    OccurrenceType
)
SELECT
    icd.ICD10SID,
    icd.ICD10Code,
    crit.TBIClassChristensen,
    crit.TBIClassKarlander,
    crit.OccurrenceType
FROM
    CDWWork.Dim.ICD10 icd
    INNER JOIN
    #ICD10TBICriteria crit
        ON
        icd.ICD10Code LIKE crit.ICD10Prefix
WHERE
    LEN(icd.ICD10Code) <= 10
;

--- DoD Severity Classification ---

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
) AS criteria (ICD9Prefix, TBISeverity)
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
) AS criteria (ICD10Prefix, TBISeverity)
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTBIICD9DoD;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnTBIICD9DoD (
    ICD9SID INT PRIMARY KEY,
    ICD9Code VARCHAR(10),
    TBISeverity VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnTBIICD9DoD (
    ICD9SID,
    ICD9Code, 
    TBISeverity
)
SELECT
    icd.ICD9SID,
    icd.ICD9Code,
    crit.TBISeverity
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
    TBISeverity VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnTBIICD10DoD (
    ICD10SID,
    ICD10Code, 
    TBISeverity
)
SELECT
    icd.ICD10SID,
    icd.ICD10Code,
    crit.TBISeverity
FROM
    CDWWork.Dim.ICD10 icd
    INNER JOIN
    #ICD10TBICriteriaDoD crit
        ON
        icd.ICD10Code LIKE crit.ICD10Prefix
WHERE
    LEN(icd.ICD10Code) <= 10
;
