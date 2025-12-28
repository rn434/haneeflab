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

TBI is also classified according to the class of injury. Karlander et al. (2021)
provided the rough classification according to ICD-10 codes. The adaptation to 
ICD-9 was done with the help of the mapping at
https://health.mil/Reference-Center/Publications/2015/12/01/TBI-Code-Map.

TBI Class        | ICD-9 Codes                  | ICD-10 Codes 
----------------------------------------------------------------------------------
Unknown Class    | 854.0, 907.0, 959.01, V15.52     | S06.A, Z87.820
Concussive       | 310.2, 850                | F07.81, S06.01                
Fracture         | 800, 801, 803, 804, 905.0 | S02.0, S02.1, S02.7, S02.9 
Focal Cerebral   | 851, 853                  | S06.3             
Diffuse Cerebral | 854.1                       | S06.1, S06.2, S06.7, S06.8, S06.9    
Extracerebral    | 852                       | S06.4, S06.5, S06.6         

Notes: S06.A should be coded along with another S06 code indicating the type
of injury. 854.0 may map to diffuse or focal TBI, but I classified it as diffuse.

The severity of the TBI codes above is determined by the duration of loss of 
consciousness experienced (LOC). All codes not in the table below are considered
to be of unknown severity

TBI Severity     | LOC (hrs.) | ICD-9 Codes                   | ICD-10 Codes 
----------------------------------------------------------------------------------
Mild             | <1         | 850.1, 8!(50).x(1, 2)         | S06.0X(0, 1), S06.!(0)x(0, 1, 2)
Moderate         | 1 - 24     | 850.2, 8!(50).x3              | S06.!(0)x(3, 4)                
Severe           | >24        | 850.(3, 4), 8!(50).x(4, 5)    | S06.!(0)x(5, 6) 

All TBI visits over the last 5 years are gathered. Then, the most severe TBI. 
Ties are broken by choosing the TBI closest to the date at which patients first 
meet our epilepsy criteria.

Only the steps of the file that need to be executed for a specific purpose
should be run. With that said, the overall runtime of the file is estimated to
be 20 minutes.

*/

-- 1. Build ICD code tables with type and severity (estimated runtime = <1 m.)

DROP TABLE IF EXISTS
    #ICD9Codes
;
SELECT
    icd.ICD9SID AS ICDSID,
    icd.ICD9Code AS Code,
    CASE
        WHEN icd.ICD9Code LIKE '310.2%' THEN 'Concussive'
        WHEN icd.ICD9Code LIKE '850%' THEN 'Concussive'
            
        WHEN icd.ICD9Code LIKE '800%' THEN 'Fracture'
        WHEN icd.ICD9Code LIKE '801%' THEN 'Fracture'
        WHEN icd.ICD9Code LIKE '803%' THEN 'Fracture'
        WHEN icd.ICD9Code LIKE '804%' THEN 'Fracture'
        WHEN icd.ICD9Code LIKE '905.0%' THEN 'Fracture'
            
        WHEN icd.ICD9Code LIKE '851%' THEN 'Focal Cerebral'
        WHEN icd.ICD9Code LIKE '853%' THEN 'Focal Cerebral'
            
        WHEN icd.ICD9Code LIKE '854.1%' THEN 'Diffuse Cerebral'
            
        WHEN icd.ICD9Code LIKE '852%' THEN 'Extracerebral'

        ELSE 'Unknown Class'
    END AS Class
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
        Class VARCHAR(20),
        Severity VARCHAR(20)
    )
;
INSERT INTO
    SCS_EEGUtil.EEG.rnTBIICD9 (
        ICDSID,
        Code, 
        Class,
        Severity
    )
SELECT
    icd.ICDSID,
    icd.Code,
    icd.Class,
    CASE
        WHEN icd.Code LIKE '850.1%' THEN 'Mild'
            
        WHEN icd.Code LIKE '850.2%' THEN 'Moderate'
            
        WHEN icd.Code LIKE '850.3%' THEN 'Severe'
        WHEN icd.Code LIKE '850.4%' THEN 'Severe'

        WHEN icd.Code LIKE '850.%' THEN 'Unknown Severity'
            
        WHEN icd.Code LIKE '8__._1%' THEN 'Mild'
        WHEN icd.Code LIKE '8__._2%' THEN 'Mild'
            
        WHEN icd.Code LIKE '8__._3%' THEN 'Moderate'
            
        WHEN icd.Code LIKE '8__._4%' THEN 'Severe'
        WHEN icd.Code LIKE '8__._5%' THEN 'Severe'

        ELSE 'Unknown Severity'
    END AS Severity
FROM
    #ICD9Codes icd
;

DROP TABLE IF EXISTS
    #ICD10Codes
;
SELECT
    icd.ICD10SID AS ICDSID,
    icd.ICD10Code AS Code,
    CASE 
        WHEN icd.ICD10Code LIKE 'F07.81%' THEN 'Concussive'
        WHEN icd.ICD10Code LIKE 'S06.0%' THEN 'Concussive'
            
        WHEN icd.ICD10Code LIKE 'S02.0%' THEN 'Fracture'
        WHEN icd.ICD10Code LIKE 'S02.1%' THEN 'Fracture'
        WHEN icd.ICD10Code LIKE 'S02.7%' THEN 'Fracture'
        WHEN icd.ICD10Code LIKE 'S02.9%' THEN 'Fracture'
            
        WHEN icd.ICD10Code LIKE 'S06.3%' THEN 'Focal Cerebral'
            
        WHEN icd.ICD10Code LIKE 'S06.1%' THEN 'Diffuse Cerebral'
        WHEN icd.ICD10Code LIKE 'S06.2%' THEN 'Diffuse Cerebral'
        WHEN icd.ICD10Code LIKE 'S06.7%' THEN 'Diffuse Cerebral'
        WHEN icd.ICD10Code LIKE 'S06.8%' THEN 'Diffuse Cerebral'
        WHEN icd.ICD10Code LIKE 'S06.9%' THEN 'Diffuse Cerebral'
            
        WHEN icd.ICD10Code LIKE 'S06.4%' THEN 'Extracerebral'
        WHEN icd.ICD10Code LIKE 'S06.5%' THEN 'Extracerebral'
        WHEN icd.ICD10Code LIKE 'S06.6%' THEN 'Extracerebral'

        ELSE 'Unknown Class'
    END AS Class
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
        Class VARCHAR(20),
        Severity VARCHAR(20)
    )
;
INSERT INTO
    SCS_EEGUtil.EEG.rnTBIICD10 (
        ICDSID,
        Code,
        Class,
        Severity
    )
SELECT
    icd.ICDSID,
    icd.Code,
    icd.Class,
    CASE
        WHEN icd.Code LIKE 'S06.0X0%' THEN 'Mild'
        WHEN icd.Code LIKE 'S06.0X0%' THEN 'Mild'

        WHEN icd.Code LIKE 'S06.0X%' THEN 'Unknown Severity' 
            
        WHEN icd.Code LIKE 'S06.__0%' THEN 'Mild'
        WHEN icd.Code LIKE 'S06.__1%' THEN 'Mild'
        WHEN icd.Code LIKE 'S06.__2%' THEN 'Mild'
            
        WHEN icd.Code LIKE 'S06.__3%' THEN 'Moderate'
        WHEN icd.Code LIKE 'S06.__4%' THEN 'Moderate'
            
        WHEN icd.Code LIKE 'S06.__5%' THEN 'Severe'
        WHEN icd.Code LIKE 'S06.__6%' THEN 'Severe'

        ELSE 'Unknown Severity'
    END AS Severity
FROM
    #ICD10Codes icd
;


-- 2. Gather patient and visit information (estimated runtime = 2 m.)

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


-- 3. Find TBI Records (estimated runtime = <1 m.)

DROP TABLE IF EXISTS 
    #ICD9TBI
;
SELECT
	pi.PatientICN,
    pi.VisitDateTime,
    icd9.Code,
	icd9.Class,
    icd9.Severity
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
	icd10.Class,
    icd10.Severity
INTO
    #ICD10TBI
FROM 
    #PatientInfo pi
    INNER JOIN 
    SCS_EEGUtil.EEG.rnTBIICD10 icd10
        ON pi.ICD10SID = icd10.ICDSID
;

-- 4. Combined ICD-9 and ICD-10 records and choose the most severe, most
-- recent TBI for each PatientICN (estimated runtime = <1 m.)

DROP TABLE IF EXISTS
    #SeverityRankings
;
CREATE TABLE
    #SeverityRankings (
        Severity VARCHAR(20) PRIMARY KEY,
        Rank INT
    )
;
INSERT INTO
    #SeverityRankings (
        Severity, 
        Rank
    )
VALUES
    ('Unknown Severity', 0),
    ('Mild', 1),
    ('Moderate', 2),
    ('Severe', 3)
;

DROP TABLE IF EXISTS 
    SCS_EEGUtil.EEG.rnTBI3
;
CREATE TABLE
    SCS_EEGUtil.EEG.rnTBI3 (
        PatientICN VARCHAR(50) PRIMARY KEY,
        ICDCode VARCHAR(10),
        Class VARCHAR(20),
        Severity VARCHAR(20)
    )
;
INSERT INTO
    SCS_EEGUtil.EEG.rnTBI3 (
        PatientICN,
        ICDCode,
        Class,
        Severity
    )
SELECT
    sq.PatientICN,
    sq.ICDCode,
    sq.Class,
    sq.Severity
FROM (
    SELECT 
        merged.PatientICN,
        merged.Code AS ICDCode,
        merged.Class,
        merged.Severity,
        ROW_NUMBER() OVER (PARTITION BY merged.PatientICN ORDER BY sr.Rank DESC, merged.VisitDateTime DESC) AS rn
    FROM (
        SELECT
            icd9.PatientICN,
            icd9.VisitDateTime,
            icd9.Code,
            icd9.Class,
            icd9.Severity
        FROM
            #ICD9TBI icd9
        
        UNION ALL

        SELECT
            icd10.PatientICN,
            icd10.VisitDateTime,
            icd10.Code,
            icd10.Class,
            icd10.Severity
        FROM
            #ICD10TBI icd10
    ) merged
    INNER JOIN 
    #SeverityRankings sr
        ON
        merged.Severity = sr.Severity
) sq
WHERE
    sq.rn = 1
;

-- 5. Run metrics (estimated runtime = <1 m.)

SELECT 
    COUNT(*),
    tbi.Class,
    tbi.Severity
FROM
    SCS_EEGUtil.EEG.rnTBI3 tbi
GROUP BY
    tbi.Class,
    tbi.Severity
;

SELECT 
    COUNT(*) c,
    tbi.ICDCode
FROM
    SCS_EEGUtil.EEG.rnTBI3 tbi
GROUP BY
    tbi.ICDCode
ORDER BY
    c DESC
;


