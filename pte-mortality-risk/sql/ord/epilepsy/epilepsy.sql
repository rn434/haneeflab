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
    Convulsions) on at least one clinical encounters (excluding data from 
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

DROP TABLE IF EXISTS
    #ASDFills
;
SELECT
    fill.PatientSID,
    CAST(fill.FillDateTime AS DATE) AS FillDate,
    CASE
        WHEN rx.ServiceConnectedFlag = 'Y' THEN 1
        WHEN rx.ServiceConnectedFlag = '1' THEN 1
        ELSE 0
    END AS ServiceConnectedFlag,
    CASE
        WHEN asd.ProductName LIKE '%gabapentin%' THEN 1
        ELSE 0
    END AS GabapentinFlag
INTO
    #ASDFills
FROM
    ORD_Haneef_202402056D.Src.RxOut_RxOutpat rx
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
;

-- Gather diagnostic information (estimated runtime = 9 m.)
-- TODO: do i not need to use inpatient at all? it doesn't have stopcodes either
-- TODO: secondary stop code?
-- TODO: rewrite as inner join

DROP TABLE IF EXISTS
    #SeizureDx
;
SELECT
    vis.PatientSID,
    CAST(dx.VDiagnosisDateTime AS DATE) AS DxDate,
    CASE
        WHEN dx.ServiceConnectedFlag = 'Y' THEN 1
        ELSE 0
    END AS ServiceConnectedFlag,
    COALESCE(icd9.DxType, icd10.DxType) AS DxType,
    COALESCE(icd9.GabapentinFlag, icd10.GabapentinFlag) AS GabapentinFlag,
    vis.ServiceCategory
INTO
    #SeizureDx
FROM
    ORD_Haneef_202402056D.Src.Outpat_Visit vis
    INNER JOIN
    ORD_Haneef_202402056D.Src.Outpat_VDiagnosis dx
        ON
        vis.VisitSID = dx.VisitSID
    LEFT JOIN
    ORD_Haneef_202402056D.Dflt.rnSeizureICD9 icd9
        ON
        dx.ICD9SID = icd9.ICD9SID
    LEFT JOIN
    ORD_Haneef_202402056D.Dflt.rnSeizureICD10 icd10
        ON
        dx.ICD10SID = icd10.ICD10SID
    LEFT JOIN
    ORD_Haneef_202402056D.Dflt.rnStopCode s
        ON
        vis.PrimaryStopCodeSID = s.StopCodeSID
WHERE
    s.StopCodeSID IS NULL
;
select count(*) from #SeizureDx WHERE DxTYPE IS NULL

-------- Match epilepsy criteria (estimated runtime = 2 m.) ---------

-- Criteria 1 (estimated runtime = 1 m.)

DROP TABLE IF EXISTS
    #Criteria1
;
SELECT
    dx.PatientSID,
    MIN(dx.DxDate) AS DxDate,
    MAX(dx.ServiceConnectedFlag) AS ServiceConnectedFlag
INTO
    #Criteria1
FROM
    #ASDFills asd
    INNER JOIN
    #SeizureDx dx
        ON
        asd.PatientSID = dx.PatientSID
WHERE
    (YEAR(asd.FillDate) - YEAR(dx.DxDate)) BETWEEN 0 AND 2
    AND (
        asd.GabapentinFlag = 0
        OR
        dx.GabapentinFlag = 1
    )
GROUP BY
    dx.PatientSID
;
    

-- Criteria 2 (estimated runtime = <1 m.)

DROP TABLE IF EXISTS
    #Criteria2
;
SELECT
    PatientSID,
    MIN(DxDate) AS DxDate,
    MAX(ServiceConnectedFlag) AS ServiceConnectedFlag
INTO
    #Criteria2
FROM 
    #SeizureDx
WHERE
    ServiceCategory IN ('D', 'H', 'I', 'O')
    AND 
    DxType = 'Epilepsy'
GROUP BY
    PatientSID
;


-- Criteria 3 (estimated runtime = <1 m.)

DROP TABLE IF EXISTS
    #Criteria3
;
SELECT
    PatientSID,
    MIN(DxDate) AS DxDate,
    MAX(ServiceConnectedFlag) AS ServiceConnectedFlag
INTO
    #Criteria3
FROM 
    #SeizureDx
WHERE
    ServiceCategory IN ('A', 'R', 'S', 'T', 'X')
    AND 
    DxType = 'Epilepsy'
GROUP BY
    PatientSID
HAVING  
    COUNT(*) >= 2
;


------- Aggregate and find initial diagnosis date (estimated runtime = ) --------


DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnEpilepsyDebug
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnEpilepsyDebug (
        PatientICN VARCHAR(10) PRIMARY KEY,
        DxDate DATE,
        ServiceConnected BIT
    )
;

WITH MergedCriteria AS (
    SELECT
        PatientSID,
        DxDate,
        ServiceConnectedFlag
    FROM
        #Criteria1
        
    UNION ALL
        
    SELECT
        PatientSID,
        DxDate,
        ServiceConnectedFlag
    FROM
        #Criteria2
        
    UNION ALL
        
    SELECT
        PatientSID,
        DxDate,
        ServiceConnectedFlag
    FROM
        #Criteria3
)
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnEpilepsyDebug (
        PatientICN,
        DxDate,
        ServiceConnected
    )
SELECT
    coh.PatientICN,
    MIN(merged.DxDate) AS DxDate,
    MAX(merged.ServiceConnectedFlag) AS ServiceConnected
FROM 
    MergedCriteria merged
    INNER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        merged.PatientSID = coh.PatientSID
GROUP BY
    coh.PatientICN
;

-- 356,937
select count(*) from ORD_Haneef_202402056D.Dflt.rnEpilepsyFinal

select distinct
    spat.ScrSSN
from
    ORD_Haneef_202402056D.Dflt.rnEpilepsyFinal epi
    inner join
    ORD_Haneef_202402056D.Src.SPatient_SPatient spat
        ON
        epi.PatientICN = spat.PatientICN
;