/* 

A patient is classified as having PTE if they experience a TBI within 5 years 
of the date they meet epilepsy criteria. In order to isolate the actual 
occurrence of the TBI from simply having a history of it, codes for personal 
history of TBI, such as V15.52 (ICD-9) and Z87.820 (ICD-10), are not included. 
As in Karlander et al. (2021), injuries to the optic chiasm and optic tract are
not included (ICD-9: 950.1, 950.2, 950.3, ICD-10: S04). 

ICD-9 TBI Criteria: 
    310.2, 800, 801, 803, 804, 850, 851, 852, 853, 854, 905.0, 907.0, 959.01, 
    V15.52
ICD-10 TBI Criteria: 
    F07.81, S02.0, S02.1, S02.7, S02.9, S06, Z87.820

TBI is also classified according to the type of injury. Karlander et al. (2021)
provided the toughclassification according to ICD-10 codes. The adaptation to 
ICD-9 was done with the help of the mapping at
https://health.mil/Reference-Center/Publications/2015/12/01/TBI-Code-Map.

Classification   | ICD-9 Codes                  | ICD-10 Codes 
----------------------------------------------------------------------------------
Unknown          | 854.0, 907.0, 959.01, V15.52 | S06.A, Z87.820
Mild             | 310.2, 850                   | F07.81, S06.01                
Fracture         | 800, 801, 803, 804, 905.0    | S02.0, S02.1, S02.7, S02.9 
Focal Cerebral   | 851, 853                     | S06.3             
Diffuse Cerebral | 854.1                        | S06.1, S06.2, S06.7, S06.8, S06.9    
Extracerebral    | 852                          | S06.4, S06.5, S06.6         

Notes: S06.A should be coded along with another S06 code indicating the type
of injury, so only patients with and ICD-10 TBI classification of Z87.820 should 
potentially have an unknown classification. 854.0 may map to diffuse or focal TBI, 
so it is classified as unknown.

The severity of the TBI classifications in increasing order is considered to be:

1. Unknown
2. Concussion
3. Fracture
4. Focal Cerebral, Diffuse Cerebral, Extracerebral

All TBI visits over the last 5 years are gathered. Then, the most severe TBI,
according to the above list is chosen. Ties are broken by choosing the TBI
closest to the date at which patients first meet our epilepsy criteria.

Only the steps of the file that need to be executed for a specific purpose
should be run. With that said, the overall runtime of the file is estimated to
be 20 minutes.

*/

-- 1. Build ICD code tables with classification (estimated runtime = 3 m.)

DROP TABLE IF EXISTS
    #ICD9Codes
;
SELECT
    icd.ICD9SID AS ICDSID,
    icd.ICD9Code AS Code
INTO
    #ICD9Codes
FROM
    CDWWork.Dim.ICD9 icd
WHERE
    icd.ICD9Code LIKE '310.2%'
    OR
    icd.ICD9Code LIKE '800%'
    OR
    icd.ICD9Code LIKE '801%'
    OR
    icd.ICD9Code LIKE '803%'
    OR
    icd.ICD9Code LIKE '804%'
    OR
    icd.ICD9Code LIKE '850%'
    OR
    icd.ICD9Code LIKE '851%'
    OR
    icd.ICD9Code LIKE '852%'
    OR
    icd.ICD9Code LIKE '853%'
    OR
    icd.ICD9Code LIKE '854%'
    OR
    icd.ICD9Code LIKE '905.0%'
    OR
    icd.ICD9Code LIKE '907.0%'
    OR
    icd.ICD9Code LIKE '959.01%'
    OR
    icd.ICD9Code LIKE 'V15.52%'
;

DROP TABLE IF EXISTS
    SCS_EEGUtil.EEG.rnTBIICD9
;
CREATE TABLE 
    SCS_EEGUtil.EEG.rnTBIICD9 (
        ICDSID INT PRIMARY KEY,
        Code VARCHAR(10),
        Classification VARCHAR(20)
    )
;
INSERT INTO
    SCS_EEGUtil.EEG.rnTBIICD9 (
        ICDSID,
        Code, 
        Classification
    )
SELECT
    icd9.ICDSID,
    icd9.Code,
    CASE
        WHEN icd9.Code LIKE '854.0%' THEN 'Unknown'
        WHEN icd9.Code LIKE '907.0%' THEN 'Unknown'
        WHEN icd9.Code LIKE '959.01%' THEN 'Unknown'
        WHEN icd9.Code LIKE 'V15.52%' THEN 'Unknown'
            
        WHEN icd9.Code LIKE '310.2%' THEN 'Mild'
        WHEN icd9.Code LIKE '850%' THEN 'Mild'
            
        WHEN icd9.Code LIKE '800%' THEN 'Fracture'
        WHEN icd9.Code LIKE '801%' THEN 'Fracture'
        WHEN icd9.Code LIKE '803%' THEN 'Fracture'
        WHEN icd9.Code LIKE '804%' THEN 'Fracture'
        WHEN icd9.Code LIKE '905.0%' THEN 'Fracture'
            
        WHEN icd9.Code LIKE '851%' THEN 'Focal Cerebral'
        WHEN icd9.Code LIKE '853%' THEN 'Focal Cerebral'
            
        WHEN icd9.Code LIKE '854.1%' THEN 'Diffuse Cerebral'
            
        WHEN icd9.Code LIKE '852%' THEN 'Extracerebral'
    END AS Classification
FROM
    #ICD9Codes icd9
;

DROP TABLE IF EXISTS
    #ICD10Codes
;
SELECT
    icd.ICD10SID AS ICDSID,
    icd.ICD10Code AS Code
INTO
    #ICD10Codes
FROM
    CDWWork.Dim.ICD10 icd
WHERE
    icd.ICD10Code LIKE 'F07.81%'
    OR
    icd.ICD10Code LIKE 'S02.0%'
    OR
    icd.ICD10Code LIKE 'S02.1%'
    OR
    icd.ICD10Code LIKE 'S02.7%'
    OR
    icd.ICD10Code LIKE 'S02.9%'
    OR
    icd.ICD10Code LIKE 'S06%'
    OR
    icd.ICD10Code LIKE 'Z87.820%'
;


DROP TABLE IF EXISTS
    SCS_EEGUtil.EEG.rnTBIICD10
;
CREATE TABLE 
    SCS_EEGUtil.EEG.rnTBIICD10 (
        ICDSID INT PRIMARY KEY,
        Code VARCHAR(10),
        Classification VARCHAR(20)
    )
;
INSERT INTO
    SCS_EEGUtil.EEG.rnTBIICD10 (
        ICDSID,
        Code,
        Classification
    )
SELECT
    icd10.ICDSID,
    icd10.Code,
    CASE
        WHEN icd10.Code LIKE 'S06.A%' THEN 'Unknown'
        WHEN icd10.Code LIKE 'Z87.820%' THEN 'Unknown'
            
        WHEN icd10.Code LIKE 'F07.81%' THEN 'Mild'
        WHEN icd10.Code LIKE 'S06.0%' THEN 'Mild'
            
        WHEN icd10.Code LIKE 'S02.0%' THEN 'Fracture'
        WHEN icd10.Code LIKE 'S02.1%' THEN 'Fracture'
        WHEN icd10.Code LIKE 'S02.7%' THEN 'Fracture'
        WHEN icd10.Code LIKE 'S02.9%' THEN 'Fracture'
            
        WHEN icd10.Code LIKE 'S06.3%' THEN 'Focal Cerebral'
            
        WHEN icd10.Code LIKE 'S06.1%' THEN 'Diffuse Cerebral'
        WHEN icd10.Code LIKE 'S06.2%' THEN 'Diffuse Cerebral'
        WHEN icd10.Code LIKE 'S06.7%' THEN 'Diffuse Cerebral'
        WHEN icd10.Code LIKE 'S06.8%' THEN 'Diffuse Cerebral'
        WHEN icd10.Code LIKE 'S06.9%' THEN 'Diffuse Cerebral'
            
        WHEN icd10.Code LIKE 'S06.4%' THEN 'Extracerebral'
        WHEN icd10.Code LIKE 'S06.5%' THEN 'Extracerebral'
        WHEN icd10.Code LIKE 'S06.6%' THEN 'Extracerebral'
    END AS Classification
FROM
    #ICD10Codes icd10
;


-- 2. Gather patient and visit information (estimated runtime = 15 m.)

DROP TABLE IF EXISTS
    #PatientInfo
;
SELECT
	coh.PatientICN,
    v.VisitDateTime,
    v.ICD9SID,
    v.ICD10SID
INTO
    #PatientInfo
FROM 
    SCS_EEGUtil.EEG.rn_cohort2 coh
    INNER JOIN 
    CDWWork.SPatient.SPatient sp
        ON coh.PatientICN = sp.PatientICN
    INNER JOIN 
    CDWWork.Outpat.WorkloadVDiagnosis v
        ON sp.PatientSID = v.PatientSID
WHERE 
    DATEDIFF(year, v.VisitDateTime, coh.FirstDXDateTime) BETWEEN 0 AND 5
;


-- 3. Find TBI Records (estimated runtime = 2 m.)

DROP TABLE IF EXISTS 
    #ICD9TBI
;
SELECT
	pi.PatientICN,
    pi.VisitDateTime,
    icd9.Code,
	icd9.Classification
INTO
    #ICD9TBI
FROM 
    #PatientInfo pi
    INNER JOIN 
    SCS_EEGUtil.EEG.rnTBIICD9 icd9
        ON pi.ICD9SID = icd9.ICDSID
;

DROP TABLE IF EXISTS 
    #ICD10TBI
;
SELECT
	pi.PatientICN,
    pi.VisitDateTime,
	icd10.Code,
	icd10.Classification
INTO
    #ICD10TBI
FROM 
    #PatientInfo pi
    INNER JOIN 
    SCS_EEGUtil.EEG.rnTBIICD10 icd10
        ON pi.ICD10SID = icd10.ICDSID
;

-- 4. Combined ICD-9 and ICD-10 records and choose the most "severe", most
-- recent TBI for each PatientICN (estimated runtime = <1 m.)

DROP TABLE IF EXISTS
    #SeverityRankings
;
CREATE TABLE
    #SeverityRankings (
        Classification VARCHAR(20) PRIMARY KEY,
        Rank INT
    )
;
INSERT INTO
    #SeverityRankings (
        Classification, 
        Rank
    )
VALUES
    ('Unknown', 1),
    ('Mild', 2),
    ('Fracture', 3),
    ('Focal Cerebral', 4),
    ('Diffuse Cerebral', 4),
    ('Extracerebral', 4)
;

DROP TABLE IF EXISTS 
    SCS_EEGUtil.EEG.rnTBI3
;
CREATE TABLE
    SCS_EEGUtil.EEG.rnTBI3
 (
        PatientICN VARCHAR(50) PRIMARY KEY,
        ICDCode VARCHAR(10),
        Classification VARCHAR(20)
    )
;
INSERT INTO
    SCS_EEGUtil.EEG.rnTBI3 (
        PatientICN,
        ICDCode,
        Classification
    )
SELECT
    sq.PatientICN,
    sq.ICDCode,
    sq.Classification
FROM (
    SELECT 
        merged.PatientICN,
        merged.Code AS ICDCode,
        merged.Classification,
        ROW_NUMBER() OVER (PARTITION BY merged.PatientICN ORDER BY sr.Rank DESC, merged.VisitDateTime DESC) AS rn
    FROM (
        SELECT
            PatientICN,
            VisitDateTime,
            Code,
            Classification
        FROM
            #ICD9TBI
        
        UNION ALL

        SELECT
            PatientICN,
            VisitDateTime,
            Code,
            Classification
        FROM
            #ICD10TBI
    ) merged
    INNER JOIN 
    #SeverityRankings sr
        ON
        merged.Classification = sr.Classification
) sq
WHERE
    sq.rn = 1
;

-- 5. Run metrics (estimated runtime = <1 m.)

SELECT 
    COUNT(*),
    tbi.Classification
FROM
    SCS_EEGUtil.EEG.rnTBI3
 tbi
GROUP BY
    tbi.Classification
;

SELECT 
    COUNT(*) c,
    tbi.ICDCode
FROM
    SCS_EEGUtil.EEG.rnTBI3
 tbi
GROUP BY
    tbi.ICDCode
ORDER BY
    c DESC
;


