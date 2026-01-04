/*

This file implements epilepsy criteria to identify patients with 
epilepsy as well as their initial date of meeting criteria.

Criteria:

    Seizure-related ICD codes are:
        ICD-09: 345, 780.39; ICD-10: G40*, R40.4, R56.1, R56.9
    Epilepsy-related ICD codes are:
        ICD-09: 345*; ICD-10: G40*

    (1) At least one documented seizure-related ICD code in the index year or 
        previous two years and at least a 30-day fill of an ASM prescription in 
        the index year (excluding gabapentin and pregabalin).
    (2) At least one inpatient encounter with an epilepsy-related ICD code.
    (3) At least two outpatient provider encounters on separate days with 
        epilepsy-related diagnoses.

    Diagnoses from LTM or EEG clinics (stop codes 106 or 128) are not considered.

    Note: ServiceCategory in CDWWork.Outpat.Visit is not the most reliable
    way to gauge inpatient (D, H, I, O) vs outpatient (A, R, S, T, X), so we
    use the Outpatient and Inpatient tables.

Estimated runtime = 34 m.

*/


-------- Initial data collection (estimated runtime = 32 m.) ---------


-- 1. ASM Data (estimated runtime = 9 m.)

DROP TABLE IF EXISTS #ASMFills;
SELECT coh.PatientICN,
    asm.DrugNameWithoutDose,
    CAST(fill.FillDateTime AS DATE) AS FillDate
INTO #ASMFills
FROM CDWWork.Patient.Patient coh
    INNER JOIN CDWWork.RxOut.RxOutpatFill fill
        ON coh.PatientSID = fill.PatientSID
    INNER JOIN SCS_EEGUtil.EEG.rnASM asm
        ON fill.NationalDrugSID = asm.NationalDrugSID
WHERE fill.DaysSupply >= 30;


-- 2. Outpatient and Inpatient Seizure Dx Data (estimated runtime = 22 m.)

DROP TABLE IF EXISTS #SeizureDx;
SELECT pat.PatientICN,
    CAST(dx.VDiagnosisDateTime AS DATE) AS DxDate,
    COALESCE(icd9.DxType, icd10.DxType) AS DxType,
    COALESCE(icd9.GabapentinFlag, icd10.GabapentinFlag) AS GabapentinFlag
INTO #SeizureDx
FROM CDWWork.Outpat.Visit vis
    INNER JOIN CDWWork.Outpat.VDiagnosis dx
        ON vis.VisitSID = dx.VisitSID
    INNER JOIN CDWWork.Patient.Patient pat
        ON dx.PatientSID = pat.PatientSID
    LEFT JOIN SCS_EEGUtil.EEG.rnStopCode s1
        ON vis.PrimaryStopCodeSID = s1.StopCodeSID
    LEFT JOIN SCS_EEGUtil.EEG.rnStopCode s2
        ON vis.SecondaryStopCodeSID = s2.StopCodeSID
    LEFT JOIN SCS_EEGUtil.EEG.rnSeizureICD9 icd9
        ON dx.ICD9SID = icd9.ICD9SID
    LEFT JOIN SCS_EEGUtil.EEG.rnSeizureICD10 icd10
        ON dx.ICD10SID = icd10.ICD10SID
WHERE (s1.StopCodeSID IS NULL AND s2.StopCodeSID IS NULL)
    AND (icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL);


-- 3. Inpatient Epilepsy Dx Data (estimated runtime = 1 m.)

DROP TABLE IF EXISTS #InpatientEpilepsyDx;
SELECT pat.PatientICN,
    CAST(dx.DischargeDateTime AS DATE) AS DxDate
INTO #InpatientEpilepsyDx
FROM CDWWork.Inpat.InpatientDiagnosis dx
    INNER JOIN CDWWork.Patient.Patient pat
        ON dx.PatientSID = pat.PatientSID
    LEFT JOIN SCS_EEGUtil.EEG.rnSeizureICD9 icd9
        ON dx.ICD9SID = icd9.ICD9SID
    LEFT JOIN SCS_EEGUtil.EEG.rnSeizureICD10 icd10
        ON dx.ICD10SID = icd10.ICD10SID
WHERE (icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL)
    AND COALESCE(icd9.DxType, icd10.DxType) = 'Epilepsy';


-------- Match epilepsy criteria (estimated runtime = 2 m.) ---------


-- Criteria 1 (estimated runtime = 1 m.)

DROP TABLE IF EXISTS #Criteria1;
SELECT dx.PatientICN,
    CASE WHEN MIN(asm.FillDate) >= MIN(dx.DxDate) THEN MIN(asm.FillDate)
        ELSE MIN(dx.DxDate) END AS DxDate
INTO #Criteria1
FROM #ASMFills asm
    INNER JOIN #SeizureDx dx
        ON asm.PatientICN = dx.PatientICN
-- Below is to align with the criteria ("index year or previous two years"), 
-- though just checking that the distance is <= 3 years would make sense too.
WHERE (YEAR(asm.FillDate) - YEAR(dx.DxDate)) BETWEEN 0 AND 2 
    AND (asm.DrugNameWithoutDose <> 'Gabapentin' OR dx.GabapentinFlag = 1)
GROUP BY dx.PatientICN;
    

-- Criteria 2 (estimated runtime = <1 m.)

DROP TABLE IF EXISTS #Criteria2;
SELECT PatientICN,
    MIN(DxDate) AS DxDate
INTO #Criteria2
FROM #InpatientEpilepsyDx
GROUP BY PatientICN;


-- Criteria 3 (estimated runtime = <1 m.)

DROP TABLE IF EXISTS #Criteria3;
WITH DiagnosisCounts AS (
    SELECT PatientICN,
        YEAR(DxDate) AS DxYear
    FROM #SeizureDx
    WHERE DxType = 'Epilepsy'
    GROUP BY PatientICN,
        Year(DxDate)
    HAVING COUNT(DISTINCT DxDate) >= 2)
, FirstYear AS (
    SELECT PatientICN,
        MIN(DxYear) AS FirstValidYear
    FROM DiagnosisCounts
    GROUP BY PatientICN)
, ValidDates AS (
    SELECT DISTINCT dx.PatientICN,
        dx.DxDate
    FROM #SeizureDx dx
    INNER JOIN FirstYear fy
        ON dx.PatientICN = fy.PatientICN
        AND YEAR(dx.DxDate) = fy.FirstValidYear)
, RankedDates AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY PatientICN ORDER BY DxDate) AS rn
    FROM ValidDates)
SELECT PatientICN,
    DxDate
INTO #Criteria3
FROM RankedDates
WHERE rn = 2;


------- Aggregate and find initial diagnosis date (estimated runtime = < 1 m.) --------

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnEpilepsyComplete;
WITH MergedCriteria AS (
    SELECT PatientICN,
        DxDate
    FROM #Criteria1
    UNION ALL
    SELECT PatientICN,
        DxDate
    FROM #Criteria2
    UNION ALL
    SELECT PatientICN,
        DxDate
    FROM #Criteria3)
SELECT merged.PatientICN,
    MIN(merged.DxDate) AS DxDate
INTO SCS_EEGUtil.EEG.rnEpilepsyComplete
FROM MergedCriteria merged
GROUP BY merged.PatientICN;

SELECT COUNT(*) AS Criteria1Count from #Criteria1;
SELECT COUNT(*) AS Criteria2Count from #Criteria2;
SELECT COUNT(*) AS Criteria3Count from #Criteria3;
SELECT COUNT(*) AS AllEpilepsyCount FROM SCS_EEGUtil.EEG.rnEpilepsyComplete;
