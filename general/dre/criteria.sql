/* 

This file implements the currently used DRE criteria:

- ASM Count >= 2, with low doses and gabapentin, pregabalin, diazepam, 
midazolam excluded
- Intractable ICD Count >= 1
- EEG/MRI Count >= 1

Estimated runtime = 12 m.

*/

-- 1. ASM data (estimated runtime = 8 m.)

DROP TABLE IF EXISTS #ASMFills;
WITH AllASMFills AS (
    SELECT coh.PatientICN,
        asm.DrugNameWithDose,
        asm.DrugNameWithoutDose,
        asm.StrengthNumeric,
        asm.DailyLowDoseThreshold,
        CAST(fill.FillDateTime AS DATE) AS FillDate,
        fill.DaysSupply,
        fill.QtyNumeric,
        (fill.QtyNumeric * asm.StrengthNumeric / fill.DaysSupply) AS DailyDose
    FROM SCS_EEGUtil.EEG.rnEpilepsy coh
        INNER JOIN CDWWork.Patient.Patient pat
            ON coh.PatientICN = pat.PatientICN
        INNER JOIN CDWWork.RxOut.RxOutpat rx
            ON pat.PatientSID = rx.PatientSID
        INNER JOIN CDWWork.RxOut.RxOutpatFill fill
            ON rx.RxOutpatSID = fill.RxOutpatSID
        INNER JOIN SCS_EEGUtil.EEG.rnASM asm
            ON fill.NationalDrugSID = asm.NationalDrugSID
    WHERE fill.DaysSupply >= 30
        AND asm.DrugNameWithoutDose NOT IN (
            'gabapentin', 'pregabalin', 'midazolam', 'diazepam'))
SELECT DISTINCT PatientICN,
    DrugNameWithoutDose,
    DailyDose,
    DailyLowDoseThreshold,
    FillDate
INTO #ASMFills
FROM AllASMFills;

DECLARE @asms NVARCHAR(MAX), @asms_sufficient_dose NVARCHAR(MAX), @query NVARCHAR(MAX)

SELECT @asms = STRING_AGG(QUOTENAME(DrugNameWithoutDose), ',')
FROM (SELECT DISTINCT DrugNameWithoutDose FROM SCS_EEGUtil.EEG.rnASM) asm;

SELECT @asms_sufficient_dose = STRING_AGG(QUOTENAME(DrugNameWithoutDose + 'SufficientDose'), ',')
FROM (SELECT DISTINCT DrugNameWithoutDose FROM SCS_EEGUtil.EEG.rnASM) asm;

SET @query = 'DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnASMExposures;
WITH ASMFills AS (
    SELECT PatientICN,
        DrugNameWithoutDose,
        FillDate
    FROM #ASMFills)
, ASMFillsSufficientDose AS (
    SELECT PatientICN,
        DrugNameWithoutDose + ''SufficientDose'' AS DrugNameWithoutDoseSufficientDose,
        FillDate
    FROM #ASMFills
    WHERE DailyDose >= DailyLowDoseThreshold)
, PivotAllFills AS (
    SELECT PatientICN,
        ' + @asms + '
    FROM ASMFills
    PIVOT (MIN(FillDate) FOR DrugNameWithoutDose IN (' + @asms + ')) Pivot1)
, PivotSufficientDoseFills AS (
    SELECT PatientICN,
        ' + @asms_sufficient_dose + '
    FROM ASMFillsSufficientDose
    PIVOT (MIN(FillDate) FOR DrugNameWithoutDoseSufficientDose IN (' + @asms_sufficient_dose + ')) Pivot2)
SELECT epi.PatientICN, 
    ' + @asms + ',
    ' + @asms_sufficient_dose + '
INTO SCS_EEGUtil.EEG.rnASMExposures
FROM SCS_EEGUtil.EEG.rnEpilepsy epi
    LEFT JOIN PivotAllFills Pivot1
        ON epi.PatientICN = Pivot1.PatientICN
    LEFT JOIN PivotSufficientDoseFills Pivot2
        ON Pivot1.PatientICN = Pivot2.PatientICN;';

EXEC sp_executesql @query;


-- 2. Intractable ICD codes (estimated runtime = 2 m.)

DROP TABLE IF EXISTS #IntractableDx;
WITH Cohort AS (
    SELECT epi.PatientICN,
        pat.PatientSID
    FROM SCS_EEGUtil.EEG.rnEpilepsy epi
        INNER JOIN CDWWork.Patient.Patient pat
            ON epi.PatientICN = pat.PatientICN)
-- , RawIntractableDx AS (
--     SELECT coh.PatientICN,
--         CAST(dx.VDiagnosisDateTime AS DATE) AS DxDate,
--         icd9.ICD9Code AS ICDCode,
--         'ICD9' AS ICDVersion
--     FROM Cohort coh
--         INNER JOIN CDWWork.Outpat.WorkloadVDiagnosis dx
--             ON coh.PatientSID = dx.PatientSID
--         INNER JOIN SCS_EEGUtil.EEG.rnIntractableICD9 icd9
--             ON dx.ICD9SID = icd9.ICD9SID
--     UNION
--     SELECT coh.PatientICN,
--         CAST(dx.VDiagnosisDateTime AS DATE) AS DxDate,
--         icd10.ICD10Code AS ICDCode,
--         'ICD10' AS ICDVersion
--     FROM Cohort coh
--         INNER JOIN CDWWork.Outpat.WorkloadVDiagnosis dx
--             ON coh.PatientSID = dx.PatientSID
--         INNER JOIN SCS_EEGUtil.EEG.rnIntractableICD10 icd10
--             ON dx.ICD10SID = icd10.ICD10SID)
SELECT DISTINCT coh.PatientICN,
    CAST(dx.VDiagnosisDateTime AS DATE) AS DxDate
INTO #IntractableDx
FROM Cohort coh
-- FROM RawIntractableDx dx
    INNER JOIN CDWWork.Outpat.WorkloadVDiagnosis dx
        ON dx.PatientSID = coh.PatientSID
    LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD9 icd9
        ON dx.ICD9SID = icd9.ICD9SID
    LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD10 icd10
        ON dx.ICD10SID = icd10.ICD10SID
WHERE icd9.ICD9SID IS NOT NULL
    OR icd10.ICD10SID IS NOT NULL;

-- 3. EEG/MRI (estimated runtime = 0 m.)
    -- Already gathered

-- 4. Implement Criteria (estimated runtime = <1 m.)

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnDRE;
WITH ASMCounts AS (
    SELECT PatientICN,
        COUNT(DISTINCT DrugNameWithoutDose) AS ASMCount,
        COUNT(DISTINCT 
            CASE WHEN DailyDose > DailyLowDoseThreshold 
            THEN DrugNameWithoutDose
        END) AS ASMCountLowDoseExcluded
    FROM #ASMFills
    GROUP BY PatientICN)
, IntractableCounts AS (
    SELECT PatientICN,
        COUNT(DISTINCT DxDate) AS IntractableCount,
        MIN(DxDate) AS InitialIntractableDx
    FROM #IntractableDx
    GROUP BY PatientICN)
, EEGCounts AS (
    SELECT PatientICN,
        COUNT(DISTINCT EEGDate) AS EEGCount,
        MIN(EEGDate) AS InitialEEG
    FROM SCS_EEGUtil.EEG.rnEEG
    GROUP BY PatientICN)
, MRICounts AS (
    SELECT PatientICN,
        COUNT(DISTINCT MRIDate) AS MRICount,
        MIN(MRIDate) AS InitialMRI
    FROM SCS_EEGUtil.EEG.rnMRI
    GROUP BY PatientICN)
, Combined AS(
    SELECT epi.PatientICN,
        COALESCE(asm.ASMCount, 0) AS ASMCount,
        COALESCE(asm.ASMCountLowDoseExcluded, 0) AS ASMCountLowDoseExcluded,
        COALESCE(intr.IntractableCount, 0) AS IntractableCount,
        InitialIntractableDx,
        COALESCE(eeg.EEGCount, 0) AS EEGCount,
        InitialEEG,
        COALESCE(mri.MRICount, 0) AS MRICount,
        InitialMRI
    FROM SCS_EEGUtil.EEG.rnEpilepsy epi
        FULL JOIN ASMCounts asm
            ON epi.PatientICN = asm.PatientICN
        FULL JOIN IntractableCounts intr
            ON epi.PatientICN = intr.PatientICN
        FULL JOIN EEGCounts eeg
            ON epi.PatientICN = eeg.PatientICN
        FULL JOIN MRICounts mri
            ON epi.PatientICN = mri.PatientICN)
SELECT *,
    CASE WHEN ASMCountLowDoseExcluded >= 2
        AND IntractableCount >= 1
        AND (EEGCount + MRICount) >= 1
        THEN 1 ELSE 0
    END AS DRE
INTO SCS_EEGUtil.EEG.rnDRE
FROM Combined;

select dre, count(*) from SCS_EEGUtil.EEG.rnDRE GROUP BY DRE;
select count(*) from SCS_EEGUtil.EEG.rnDRE WHERE IntractableCount >= 1;
select count(*) from SCS_EEGUtil.EEG.rnDRE WHERE ASMCount >= 2;
select count(*) from SCS_EEGUtil.EEG.rnDRE WHERE ASMCountLowDoseExcluded >= 2;
