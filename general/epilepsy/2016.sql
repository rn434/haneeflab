/*

This file implements epilepsy criteria to identify patients with 
epilepsy in 2016.

*/


DROP TABLE IF EXISTS #ASMFills;
SELECT coh.PatientICN,
    CAST(fill.FillDateTime AS DATE) AS FillDate,
    -- 0 AS GabapentinFlag
    CASE WHEN asm.DrugNameWithoutDose LIKE 'gabapentin' THEN 1
        WHEN asm.DrugNameWithoutDose LIKE 'pregabalin' THEN 1
        ELSE 0 END AS GabapentinFlag
INTO #ASMFills
FROM CDWWork.Patient.Patient coh
    INNER JOIN CDWWork.RxOut.RxOutpatFill fill
        ON coh.PatientSID = fill.PatientSID
    INNER JOIN SCS_EEGUtil.EEG.rnASM asm
        ON fill.NationalDrugSID = asm.NationalDrugSID
WHERE fill.DaysSupply >= 30
    AND fill.FillDateTime BETWEEN '2016-01-01' AND '2016-12-31';



DROP TABLE IF EXISTS #SeizureDx;
With AllVHADx AS (
    SELECT merged.PatientSID, 
        merged.DxDate,
        merged.ICD9SID,
        merged.ICD10SID,
        merged.ServiceCategory
    FROM (
        SELECT dx.PatientSID,
            CAST(dx.VDiagnosisDateTime AS DATE) AS DxDate,
            dx.ICD9SID,
            dx.ICD10SID,
            vis.ServiceCategory
        FROM CDWWork.Outpat.Visit vis
            INNER JOIN CDWWork.Outpat.VDiagnosis dx
                ON vis.VisitSID = dx.VisitSID
            LEFT JOIN SCS_EEGUtil.EEG.rnStopCode s1
                ON vis.PrimaryStopCodeSID = s1.StopCodeSID
            LEFT JOIN SCS_EEGUtil.EEG.rnStopCode s2
                ON vis.SecondaryStopCodeSID = s2.StopCodeSID
        WHERE s1.StopCodeSID IS NULL
            AND s2.StopCodeSID IS NULL
            AND dx.VDiagnosisDateTime BETWEEN '2014-01-01' AND '2016-12-31'
    ) merged)
, RawSeizureDx AS (
    SELECT dx.PatientSID,
        dx.DxDate,
        icd.DxType,
        icd.GabapentinFlag,
        dx.ServiceCategory
    FROM AllVHADx dx
        INNER JOIN SCS_EEGUtil.EEG.rnSeizureICD9 icd
            ON dx.ICD9SID = icd.ICD9SID
    
    UNION ALL

    SELECT dx.PatientSID,
        dx.DxDate,
        icd.DxType,
        icd.GabapentinFlag,
        dx.ServiceCategory
    FROM AllVHADx dx
        INNER JOIN SCS_EEGUtil.EEG.rnSeizureICD10 icd
            ON dx.ICD10SID = icd.ICD10SID)
SELECT coh.PatientICN,
    rawdx.DxDate,
    rawdx.DxType,
    rawdx.GabapentinFlag,
    rawdx.ServiceCategory
INTO #SeizureDx
FROM RawSeizureDx rawdx
    INNER JOIN CDWWork.Patient.Patient coh
        ON rawdx.PatientSID = coh.PatientSID;


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
WHERE (YEAR(asm.FillDate) - YEAR(dx.DxDate)) BETWEEN 0 AND 2
    AND (asm.GabapentinFlag = 0 OR dx.GabapentinFlag = 1)
GROUP BY dx.PatientICN;
    

-- Criteria 2 (estimated runtime = <1 m.)

DROP TABLE IF EXISTS #Criteria2;
SELECT PatientICN,
    MIN(DxDate) AS DxDate
INTO #Criteria2
FROM #SeizureDx
WHERE ServiceCategory IN ('D', 'H', 'I', 'O')
    AND DxType = 'Epilepsy'
    AND DxDate BETWEEN '2016-01-01' AND '2016-12-31'
GROUP BY PatientICN;


-- Criteria 3 (estimated runtime = <1 m.)

DROP TABLE IF EXISTS #Criteria3;
WITH DiagnosisCounts AS (
    SELECT PatientICN,
        YEAR(DxDate) AS DxYear
    FROM #SeizureDx
    WHERE ServiceCategory IN ('A', 'R', 'S', 'T', 'X')
        AND DxType = 'Epilepsy'
        AND DxDate BETWEEN '2016-01-01' AND '2016-12-31'
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

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnEpilepsy2016;
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
INTO SCS_EEGUtil.EEG.rnEpilepsy2016
FROM MergedCriteria merged
GROUP BY merged.PatientICN;

SELECT COUNT(*) from #Criteria1;
SELECT COUNT(*) from #Criteria2;
SELECT COUNT(*) from #Criteria3;
SELECT COUNT(*) FROM SCS_EEGUtil.EEG.rnEpilepsy2016;

-- DRE Criteria (3 Year)

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
    FROM SCS_EEGUtil.EEG.rnEpilepsy2016 coh
        INNER JOIN CDWWork.Patient.Patient pat
            ON coh.PatientICN = pat.PatientICN
        INNER JOIN CDWWork.RxOut.RxOutpatFill fill
            ON pat.PatientSID = fill.PatientSID
        INNER JOIN SCS_EEGUtil.EEG.rnASM asm
            ON fill.NationalDrugSID = asm.NationalDrugSID
    WHERE fill.DaysSupply >= 30
        AND asm.DrugNameWithoutDose NOT IN (
            'gabapentin', 'pregabalin', 'midazolam', 'diazepam')
        AND fill.FillDateTime BETWEEN '2014-01-01' AND '2016-12-31')
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

SET @query = 'DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnASMExposures1416;
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
INTO SCS_EEGUtil.EEG.rnASMExposures1416
FROM SCS_EEGUtil.EEG.rnEpilepsy2016 epi
    LEFT JOIN PivotAllFills Pivot1
        ON epi.PatientICN = Pivot1.PatientICN
    LEFT JOIN PivotSufficientDoseFills Pivot2
        ON Pivot1.PatientICN = Pivot2.PatientICN;';

EXEC sp_executesql @query;


-- 2. Intractable ICD codes (estimated runtime = 2 m.)

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnIntractable1416;
WITH Cohort AS (
    SELECT epi.PatientICN,
        pat.PatientSID
    FROM SCS_EEGUtil.EEG.rnEpilepsy2016 epi
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
INTO SCS_EEGUtil.EEG.rnIntractable1416
FROM Cohort coh
-- FROM RawIntractableDx dx
    INNER JOIN CDWWork.Outpat.WorkloadVDiagnosis dx
        ON dx.PatientSID = coh.PatientSID
    LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD9 icd9
        ON dx.ICD9SID = icd9.ICD9SID
    LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD10 icd10
        ON dx.ICD10SID = icd10.ICD10SID
WHERE dx.VDiagnosisDateTime BETWEEN '2014-01-01' AND '2016-12-31' 
    AND (icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL);

SELECT * INTO #IntractableDx FROM SCS_EEGUtil.EEG.rnIntractable1416;

-- 3. EEG/MRI (estimated runtime = 0 m.)
    -- Already gathered

-- 4. Implement Criteria (estimated runtime = <1 m.)

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnDRE2016;
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
    WHERE EEGDate BETWEEN '2014-01-01' AND '2016-12-31'
    GROUP BY PatientICN)
, MRICounts AS (
    SELECT PatientICN,
        COUNT(DISTINCT MRIDate) AS MRICount,
        MIN(MRIDate) AS InitialMRI
    FROM SCS_EEGUtil.EEG.rnMRI
    WHERE MRIDate BETWEEN '2014-01-01' AND '2016-12-31'
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
    FROM SCS_EEGUtil.EEG.rnEpilepsy2016 epi
        LEFT JOIN ASMCounts asm
            ON epi.PatientICN = asm.PatientICN
        LEFT JOIN IntractableCounts intr
            ON epi.PatientICN = intr.PatientICN
        LEFT JOIN EEGCounts eeg
            ON epi.PatientICN = eeg.PatientICN
        LEFT JOIN MRICounts mri
            ON epi.PatientICN = mri.PatientICN)
SELECT *,
    CASE WHEN ASMCountLowDoseExcluded >= 2
        AND IntractableCount >= 1
        AND (EEGCount + MRICount) >= 1
        THEN 1 ELSE 0
    END AS DRE
INTO SCS_EEGUtil.EEG.rnDRE2016
FROM Combined;

select dre, count(*) from SCS_EEGUtil.EEG.rnDRE2016 GROUP BY DRE;
select count(*) from SCS_EEGUtil.EEG.rnDRE2016 WHERE IntractableCount >= 1;
select count(*) from SCS_EEGUtil.EEG.rnDRE2016 WHERE ASMCount >= 2;
select count(*) from SCS_EEGUtil.EEG.rnDRE2016 WHERE ASMCountLowDoseExcluded >= 2;
select count(*) from SCS_EEGUtil.EEG.rnDRE2016 WHERE EEGCount >= 1;
select count(*) from SCS_EEGUtil.EEG.rnDRE2016 WHERE MRICount >= 1;
select count(*) from SCS_EEGUtil.EEG.rnEpilepsy2016;

-- DRE Criteria (5 Year)

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
    FROM SCS_EEGUtil.EEG.rnEpilepsy2016 coh
        INNER JOIN CDWWork.Patient.Patient pat
            ON coh.PatientICN = pat.PatientICN
        INNER JOIN CDWWork.RxOut.RxOutpatFill fill
            ON pat.PatientSID = fill.PatientSID
        INNER JOIN SCS_EEGUtil.EEG.rnASM asm
            ON fill.NationalDrugSID = asm.NationalDrugSID
    WHERE fill.DaysSupply >= 30
        AND asm.DrugNameWithoutDose NOT IN (
            'gabapentin', 'pregabalin', 'midazolam', 'diazepam')
        AND fill.FillDateTime BETWEEN '2012-01-01' AND '2016-12-31')
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

SET @query = 'DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnASMExposures1216;
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
INTO SCS_EEGUtil.EEG.rnASMExposures1216
FROM SCS_EEGUtil.EEG.rnEpilepsy2016 epi
    LEFT JOIN PivotAllFills Pivot1
        ON epi.PatientICN = Pivot1.PatientICN
    LEFT JOIN PivotSufficientDoseFills Pivot2
        ON Pivot1.PatientICN = Pivot2.PatientICN;';

EXEC sp_executesql @query;


-- 2. Intractable ICD codes (estimated runtime = 2 m.)

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnIntractable1216;
WITH Cohort AS (
    SELECT epi.PatientICN,
        pat.PatientSID
    FROM SCS_EEGUtil.EEG.rnEpilepsy2016 epi
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
INTO SCS_EEGUtil.EEG.rnIntractable1216
FROM Cohort coh
-- FROM RawIntractableDx dx
    INNER JOIN CDWWork.Outpat.WorkloadVDiagnosis dx
        ON dx.PatientSID = coh.PatientSID
    LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD9 icd9
        ON dx.ICD9SID = icd9.ICD9SID
    LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD10 icd10
        ON dx.ICD10SID = icd10.ICD10SID
WHERE dx.VDiagnosisDateTime BETWEEN '2012-01-01' AND '2016-12-31' 
    AND (icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL);

SELECT * INTO #IntractableDx FROM SCS_EEGUtil.EEG.rnIntractable1216;

-- 3. EEG/MRI (estimated runtime = 0 m.)
    -- Already gathered

-- 4. Implement Criteria (estimated runtime = <1 m.)

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnDRE2016Five;
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
    FROM SCS_EEGUtil.EEG.rnIntractable1216
    GROUP BY PatientICN)
, EEGCounts AS (
    SELECT PatientICN,
        COUNT(DISTINCT EEGDate) AS EEGCount,
        MIN(EEGDate) AS InitialEEG
    FROM SCS_EEGUtil.EEG.rnEEG
    WHERE EEGDate BETWEEN '2012-01-01' AND '2016-12-31'
    GROUP BY PatientICN)
, MRICounts AS (
    SELECT PatientICN,
        COUNT(DISTINCT MRIDate) AS MRICount,
        MIN(MRIDate) AS InitialMRI
    FROM SCS_EEGUtil.EEG.rnMRI
    WHERE MRIDate BETWEEN '2012-01-01' AND '2016-12-31'
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
    FROM SCS_EEGUtil.EEG.rnEpilepsy2016 epi
        LEFT JOIN ASMCounts asm
            ON epi.PatientICN = asm.PatientICN
        LEFT JOIN IntractableCounts intr
            ON epi.PatientICN = intr.PatientICN
        LEFT JOIN EEGCounts eeg
            ON epi.PatientICN = eeg.PatientICN
        LEFT JOIN MRICounts mri
            ON epi.PatientICN = mri.PatientICN)
SELECT *,
    CASE WHEN ASMCountLowDoseExcluded >= 2
        AND IntractableCount >= 1
        AND (EEGCount + MRICount) >= 1
        THEN 1 ELSE 0
    END AS DRE
INTO SCS_EEGUtil.EEG.rnDRE2016Five
FROM Combined;

select dre, count(*) from SCS_EEGUtil.EEG.rnDRE2016Five GROUP BY DRE;
select count(*) from SCS_EEGUtil.EEG.rnDRE2016Five WHERE IntractableCount >= 1;
select count(*) from SCS_EEGUtil.EEG.rnDRE2016Five WHERE ASMCount >= 2;
select count(*) from SCS_EEGUtil.EEG.rnDRE2016Five WHERE ASMCountLowDoseExcluded >= 2;
select count(*) from SCS_EEGUtil.EEG.rnDRE2016Five WHERE EEGCount >= 1;
select count(*) from SCS_EEGUtil.EEG.rnDRE2016Five WHERE MRICount >= 1;

select top 10 * from SCS_EEGUtil.EEG.rnDRE2016Five

-- DRE Criteria (20 Year)

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
    FROM SCS_EEGUtil.EEG.rnEpilepsy2016 coh
        INNER JOIN CDWWork.Patient.Patient pat
            ON coh.PatientICN = pat.PatientICN
        INNER JOIN CDWWork.RxOut.RxOutpatFill fill
            ON pat.PatientSID = fill.PatientSID
        INNER JOIN SCS_EEGUtil.EEG.rnASM asm
            ON fill.NationalDrugSID = asm.NationalDrugSID
    WHERE fill.DaysSupply >= 30
        AND asm.DrugNameWithoutDose NOT IN (
            'gabapentin', 'pregabalin', 'midazolam', 'diazepam')
        AND fill.FillDateTime BETWEEN '1996-01-01' AND '2016-12-31')
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

SET @query = 'DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnASMExposuresAll16;
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
INTO SCS_EEGUtil.EEG.rnASMExposuresAll16
FROM SCS_EEGUtil.EEG.rnEpilepsy2016 epi
    LEFT JOIN PivotAllFills Pivot1
        ON epi.PatientICN = Pivot1.PatientICN
    LEFT JOIN PivotSufficientDoseFills Pivot2
        ON Pivot1.PatientICN = Pivot2.PatientICN;';

EXEC sp_executesql @query;


-- 2. Intractable ICD codes (estimated runtime = 2 m.)

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnIntractableAll16;
WITH Cohort AS (
    SELECT epi.PatientICN,
        pat.PatientSID
    FROM SCS_EEGUtil.EEG.rnEpilepsy2016 epi
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
INTO SCS_EEGUtil.EEG.rnIntractableAll16
FROM Cohort coh
-- FROM RawIntractableDx dx
    INNER JOIN CDWWork.Outpat.WorkloadVDiagnosis dx
        ON dx.PatientSID = coh.PatientSID
    LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD9 icd9
        ON dx.ICD9SID = icd9.ICD9SID
    LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD10 icd10
        ON dx.ICD10SID = icd10.ICD10SID
WHERE dx.VDiagnosisDateTime BETWEEN '1996-01-01' AND '2016-12-31' 
    AND (icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL);

SELECT * INTO #IntractableDx FROM SCS_EEGUtil.EEG.rnIntractableAll16;

-- 3. EEG/MRI (estimated runtime = 0 m.)
    -- Already gathered

-- 4. Implement Criteria (estimated runtime = <1 m.)

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnDRE2016All;
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
    FROM SCS_EEGUtil.EEG.rnIntractableAll16
    GROUP BY PatientICN)
, EEGCounts AS (
    SELECT PatientICN,
        COUNT(DISTINCT EEGDate) AS EEGCount,
        MIN(EEGDate) AS InitialEEG
    FROM SCS_EEGUtil.EEG.rnEEG
    WHERE EEGDate BETWEEN '1996-01-01' AND '2016-12-31'
    GROUP BY PatientICN)
, MRICounts AS (
    SELECT PatientICN,
        COUNT(DISTINCT MRIDate) AS MRICount,
        MIN(MRIDate) AS InitialMRI
    FROM SCS_EEGUtil.EEG.rnMRI
    WHERE MRIDate BETWEEN '1996-01-01' AND '2016-12-31'
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
    FROM SCS_EEGUtil.EEG.rnEpilepsy2016 epi
        LEFT JOIN ASMCounts asm
            ON epi.PatientICN = asm.PatientICN
        LEFT JOIN IntractableCounts intr
            ON epi.PatientICN = intr.PatientICN
        LEFT JOIN EEGCounts eeg
            ON epi.PatientICN = eeg.PatientICN
        LEFT JOIN MRICounts mri
            ON epi.PatientICN = mri.PatientICN)
SELECT *,
    CASE WHEN ASMCountLowDoseExcluded >= 2
        AND IntractableCount >= 1
        AND (EEGCount + MRICount) >= 1
        THEN 1 ELSE 0
    END AS DRE
INTO SCS_EEGUtil.EEG.rnDRE2016All
FROM Combined;

select dre, count(*) from SCS_EEGUtil.EEG.rnDRE2016All GROUP BY DRE;
select count(*) from SCS_EEGUtil.EEG.rnDRE2016All WHERE IntractableCount >= 1;
select count(*) from SCS_EEGUtil.EEG.rnDRE2016All WHERE ASMCount >= 2;
select count(*) from SCS_EEGUtil.EEG.rnDRE2016All WHERE ASMCountLowDoseExcluded >= 2;
select count(*) from SCS_EEGUtil.EEG.rnDRE2016All WHERE EEGCount >= 1;
select count(*) from SCS_EEGUtil.EEG.rnDRE2016All WHERE MRICount >= 1;
