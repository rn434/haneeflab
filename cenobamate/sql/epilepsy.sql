/* 

This file uses the data provided in ORD_Haneef_202402056D to determine which 
patients meet the criteria for definite epilepsy as defined by the VSSC for 
use in building the Neurology Cube. The patients available in 
ORD_Haneef_202402056D include all patients with any epilepsy or seizure-related
diagnosis, so they need to be filtered to only those classified as definite
epilepsy. This VSSC Cube criteria is as follows:

    1. Three years (index year + past two years) of diagnostic data from all 
    clinics except EEG and LTM (106 and 128 stop codes respectively) cross 
    matched with at least 30 days of an ASD in the required FY excluding 
    gabapentin. For a given index year diagnosis code 345.xx (Epilepsy) and/or 
    780.3x (Other convulsions), G40.* (Epilepsy), R40.4 (Transient Alteration 
    of Awareness), R56.1 (Post Traumatic Seizures) or R56.9 (Unspecified 
    Convulsions) on at least one clinical encounter (excluding data from 
    diagnostic clinics) from index year and past two years will be considered. 
    Patients prescribed gabapentin with at least one encounter coded with 
    345.xx, G40.xxx, R56.1 or R56.9  will also be included in the cohort.

    2. Patients who had at least one inpatient encounter with diagnosis code 
    345.xx or G40.xxx (epilepsy) during the required FY excluding LTM and EEG 
    clinics (primary stop code 106,128) (No cross match with ASD required)

    3. Patients who had at least two outpatient encounters with ICD-09 
    diagnosis code 345.xx or G40.xxx (epilepsy) excluding LTM and EEG clinics 
    (primary stop code 106,128) (on two separate days; no cross match of ASD 
    required).

Running this file will result in a table containing the following information:

    * PatientICN
        + Unique patient identifier
    * DxDate
        + The first date on which patients meet epilepsy criteria 
        + This date is chosen based on the criteria described above
    * ServiceConnected
        + Whether or not the epilepsy or seizure-related diagnosis was deemed 
          to be service connected at any point

*/


-- Gather ASD information (estimated runtime = 3 m.)

DROP TABLE IF EXISTS #ASDFills;
SELECT
    coh.PatientICN,
    CAST(fill.FillDateTime AS DATE) AS FillDate,
    CASE
        WHEN asd.ProductName LIKE '%gabapentin%' THEN 1
        ELSE 0
    END AS GabapentinFlag
INTO
    #ASDFills
FROM
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
    INNER JOIN
    ORD_Haneef_202402056D.Src.RxOut_RxOutpat rx
        ON
        coh.PatientSID = rx.PatientSID
    INNER JOIN
    ORD_Haneef_202402056D.Src.RxOut_RxOutpatFill fill
        ON
        rx.RxOutpatSID = fill.RxOutpatSID
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnASD asd
        ON
        fill.LocalDrugSID = asd.LocalDrugSID
WHERE
    fill.DaysSupply >= 30
    AND
    fill.FillDateTime BETWEEN '2023-10-01' AND '2024-09-30'
;

-- Gather diagnostic information (estimated runtime = 9 m.)

DROP TABLE IF EXISTS ##AllVHADx;
SELECT
    merged.PatientSID,
    merged.DxDate,
    merged.ICD9SID,
    merged.ICD10SID,
    merged.ServiceCategory
INTO
    ##AllVHADx
FROM (
    SELECT
        dx.PatientSID,
        CAST(dx.VDiagnosisDateTime AS DATE) AS DxDate,
        dx.ICD9SID,
        dx.ICD10SID,
        vis.ServiceCategory
    FROM
        ORD_Haneef_202402056D.Src.Outpat_Visit vis
        INNER JOIN
        ORD_Haneef_202402056D.Src.Outpat_VDiagnosis dx
            ON
            vis.VisitSID = dx.VisitSID
        LEFT JOIN
        ORD_Haneef_202402056D.Dflt.rnStopCode s1
            ON
            vis.PrimaryStopCodeSID = s1.StopCodeSID
        LEFT JOIN
        ORD_Haneef_202402056D.Dflt.rnStopCode s2
            ON
            vis.SecondaryStopCodeSID = s2.StopCodeSID
    WHERE 
        (
            s1.StopCodeSID IS NULL
            AND
            s2.StopCodeSID IS NULL
        )
        AND
        dx.VDiagnosisDateTime BETWEEN '2021-10-01' AND '2024-09-30'
) merged
;


DROP TABLE IF EXISTS #SeizureDx;
WITH RawSeizureDx AS (
    SELECT
        dx.PatientSID,
        dx.DxDate,
        icd.DxType,
        icd.GabapentinFlag,
        dx.ServiceCategory
    FROM
        ##AllVHADx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnSeizureICD9 icd
            ON
            dx.ICD9SID = icd.ICD9SID
    
    UNION ALL

    SELECT
        dx.PatientSID,
        dx.DxDate,
        icd.DxType,
        icd.GabapentinFlag,
        dx.ServiceCategory
    FROM
        ##AllVHADx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnSeizureICD10 icd
            ON
            dx.ICD10SID = icd.ICD10SID
)
SELECT
    coh.PatientICN,
    rawdx.DxDate,
    rawdx.DxType,
    rawdx.GabapentinFlag,
    rawdx.ServiceCategory
INTO
    #SeizureDx
FROM
    RawSeizureDx rawdx
    INNER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        rawdx.PatientSID = coh.PatientSID
;


-------- Match epilepsy criteria (estimated runtime = 2 m.) ---------

-- Criteria 1 (estimated runtime = 1 m.)

DROP TABLE IF EXISTS #Criteria1;
SELECT
    dx.PatientICN,
    MIN(dx.DxDate) AS DxDate
INTO
    #Criteria1
FROM
    #ASDFills asd
    INNER JOIN
    #SeizureDx dx
        ON
        asd.PatientICN = dx.PatientICN
WHERE
    -- (YEAR(asd.FillDate) - YEAR(dx.DxDate)) BETWEEN 0 AND 2
    -- AND (
        asd.GabapentinFlag = 0
        OR
        dx.GabapentinFlag = 1
    -- )
GROUP BY
    dx.PatientICN
;
    

-- Criteria 2 (estimated runtime = <1 m.)

DROP TABLE IF EXISTS #Criteria2;
SELECT
    PatientICN,
    MIN(DxDate) AS DxDate
INTO
    #Criteria2
FROM 
    #SeizureDx
WHERE
    ServiceCategory IN ('D', 'H', 'I', 'O')
    AND 
    DxType = 'Epilepsy'
    AND
    DxDate BETWEEN '2023-10-01' AND '2024-09-30'
GROUP BY
    PatientICN
;


-- Criteria 3 (estimated runtime = <1 m.)

DROP TABLE IF EXISTS #Criteria3;
SELECT
    PatientICN,
    MIN(DxDate) AS DxDate
INTO
    #Criteria3
FROM 
    #SeizureDx
WHERE
    ServiceCategory IN ('A', 'R', 'S', 'T', 'X')
    AND 
    DxType = 'Epilepsy'
    AND
    DxDate BETWEEN '2023-10-01' AND '2024-09-30'
GROUP BY
    PatientICN
HAVING  
    COUNT(DISTINCT DxDate) >= 2
;


------- Aggregate and find initial diagnosis date (estimated runtime = <1 m.) --------


DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnEpilepsyFY24Debug;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnEpilepsyFY24Debug (
    PatientICN VARCHAR(10) PRIMARY KEY,
    DxDate DATE
)
;

WITH MergedCriteria AS (
    SELECT
        PatientICN,
        DxDate
    FROM
        #Criteria1
        
    UNION ALL
        
    SELECT
        PatientICN,
        DxDate
    FROM
        #Criteria2
        
    UNION ALL
        
    SELECT
        PatientICN,
        DxDate
    FROM
        #Criteria3
)
INSERT INTO ORD_Haneef_202402056D.Dflt.rnEpilepsyFY24Debug (
    PatientICN,
    DxDate
)
SELECT
    merged.PatientICN,
    MIN(merged.DxDate) AS DxDate
FROM 
    MergedCriteria merged
GROUP BY
    PatientICN
;
-- select count(*) from ORD_Haneef_202402056D.Dflt.rnEpilepsyFY24Debug

-- select ServiceCategory, count(*) from ORD_Haneef_202402056D.Src.Outpat_Visit GROUP BY ServiceCategory

-- N	2848
-- I	52337108
-- H	5201817
-- X	96067649
-- D	75125114
-- O	24205
-- IN HOSPITAL	49
-- R	1131049
-- S	32639
-- 0	13
-- T	53385223
-- A	262155386
-- NULL	6645
-- HF	1366
-- E	119619658
-- C	978