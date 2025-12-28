-- 119497
DROP TABLE IF EXISTS #restricted_cohort
SELECT
    *
INTO #restricted_cohort
FROM [SCS_EEGUtil].[EEG].[rn_full_cohort]
WHERE [FIRST_DX_DATE] BETWEEN '01-01-2004' AND '01-01-2024' 

DROP TABLE IF EXISTS #new_cohort_with_info
SELECT
    [sq].[PatientICN],
    [sq].[BirthDateTime],
    [sq].[DeathDateTime],
    [sq].[LatestVisitDateTime] 
INTO #new_cohort_with_info
FROM (
    SELECT
        [sp].[PatientICN],
        [sp].[BirthDateTime],
        [sp].[DeathDateTime],
        [v].[VisitDateTime] AS LatestVisitDateTime, 
        ROW_NUMBER() OVER(PARTITION BY [sp].[PatientICN] ORDER BY v.VisitDateTime desc) AS rn
    FROM [CDWWork].[Outpat].[Visit] v
    INNER JOIN [CDWWork].[SPatient].[SPatient] sp
        ON [v].[PatientSID] = [sp].[PatientSID]
    INNER JOIN [#restricted_cohort] coh
        ON [sp].[PatientICN] = [coh].[PatientICN]
) sq
WHERE sq.rn = 1

-- DROP TABLE IF EXISTS #new_cohort_with_info
-- SELECT
--     [PatientICN],
--     [BirthDateTime],
--     [DeathDateTime],
--     [LatestVisitDateTime]
-- INTO #new_cohort_with_info
-- FROM (
--     SELECT
--         [coh].[PatientICN],
--         [coh].[DeathDateTime],
--         [coh].[LatestVisitDateTime],
--         [sp].[BirthDateTime],
--         ROW_NUMBER() OVER(PARTITION BY [sp].[PatientICN] ORDER BY [sp].[BirthDateTime]) AS rn
--     FROM #new_cohort_with_latest_visit_and_death coh
--     INNER JOIN [CDWWork].[SPatient].[SPatient] sp
--         ON [coh].[PatientICN] = [sp].[PatientICN]
-- ) sq
-- WHERE sq.rn = 1

-- SELECT TOP 5
--     *
-- FROM #new_cohort_with_info

DROP TABLE IF EXISTS [SCS_EEGUtil].[EEG].[rn_cohort_with_info_new]
SELECT
    [coh].[PatientICN],
    [coh].[FIRST_DX_DATE] AS FirstDXDateTime,
    [coh].[PTE],
    [info].[BirthDateTime],
    [info].[DeathDateTime],
    [info].[LatestVisitDateTime]
INTO [SCS_EEGUtil].[EEG].[rn_cohort_with_info_new]
FROM #new_cohort_with_info info
INNER JOIN [SCS_EEGUtil].[EEG].[rn_full_cohort] coh
    ON [info].[PatientICN] = [coh].[PatientICN]

SELECT TOP 5
    *
FROM [SCS_EEGUtil].[EEG].[rn_cohort_with_info_new]

-- SELECT
--     *
-- FROM [CDWWork].[Outpat].[Visit]
-- WHERE VisitDateTime = '2022-05-17 10:28:00'



-- SELECT TOP 5
--     *
-- FROM [CDWWork].[Meta].[DWViewField]
-- WHERE [DWViewName] = 'Patient'
--     AND [DWViewFieldName] = 'Patient SID'

-- SELECT TOP 5
--     [v].[VisitSID], 
--     [v].[VisitDateTime], 
--     [p].[PatientSID], 
--     [p].[PatientICN]
-- FROM [CDWWork].[Outpat].[Visit] v
-- INNER JOIN [CDWWork].[Patient].[Patient] p
--     ON [v].[PatientSID] = [p].[PatientSID]
-- INNER JOIN [SCS_EEGUtil].[EEG].[rn_full_cohort] coh
--     ON [p].[PatientICN] = [coh].[PatientICN]


DROP TABLE IF EXISTS #all_epileptic
SELECT
    PatientICN,
    FirstDXDateTime
INTO #all_epileptic
FROM [SCS_EEGUtil].[EEG].[rn_elix]



DROP TABLE IF EXISTS #cohort_trauma_icd10_records
SELECT DISTINCT
	coh.PatientICN,
    coh.FirstDXDateTime,
	v.VisitDateTime,
	icd.ICD10Code
INTO #cohort_trauma_icd10_records
FROM #all_epileptic AS coh
INNER JOIN CDWWork.SPatient.SPatient AS sp
ON sp.PatientICN = coh.PatientICN
INNER JOIN CDWWork.Outpat.WorkloadVDiagnosis AS v
ON sp.PatientSID = v.PatientSID
INNER JOIN CDWWork.Dim.ICD10 AS icd
ON icd.ICD10SID = v.ICD10SID
INNER JOIN [SCS_EEGUtil].[EEG].[rn_tbi_codes_icd10] rnt
ON icd.ICD10Code = rnt.ICD10_Code
;

DROP TABLE IF EXISTS #cohort_trauma_icd9_records
SELECT DISTINCT
	coh.PatientICN,
    coh.FirstDXDateTime,
	v.VisitDateTime,
	icd.ICD9Code
INTO #cohort_trauma_icd9_records
FROM #all_epileptic AS coh
INNER JOIN CDWWork.SPatient.SPatient AS sp
ON sp.PatientICN = coh.PatientICN
INNER JOIN CDWWork.Outpat.WorkloadVDiagnosis AS v
ON sp.PatientSID = v.PatientSID
INNER JOIN CDWWork.Dim.ICD9 AS icd
ON icd.ICD9SID = v.ICD9SID
INNER JOIN [SCS_EEGUtil].[EEG].[rn_tbi_codes_icd9] rnt
ON icd.ICD9Code = rnt.ICD9_Code
;

DROP TABLE IF EXISTS [SCS_EEGUtil].[EEG].[rn_pte]
SELECT DISTINCT
	coh.PatientICN,
    MAX(coh.VisitDateTime) AS MostRecentTBIVisitDateTime
INTO [SCS_EEGUtil].[EEG].[rn_pte]
FROM (
    SELECT * FROM #cohort_trauma_icd10_records
    UNION ALL
    SELECT * FROM #cohort_trauma_icd9_records
) coh
WHERE coh.VisitDateTime < coh.FirstDXDateTime
GROUP BY coh.PatientICN
