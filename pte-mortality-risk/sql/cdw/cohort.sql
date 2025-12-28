DROP TABLE IF EXISTS #epilepsy_concepts_icd9
SELECT DISTINCT
    ICD9Code,
    ICD9Description,
    DOMAIN_ID,
    CONCEPT_ID,
    CONCEPT_NAME
INTO #epilepsy_concepts_icd9
FROM CDWWork.OMOPV5Dim.ICD9_CONCEPT
WHERE ICD9Code LIKE '345%'

DROP TABLE IF EXISTS #epilepsy_concepts_icd10
SELECT DISTINCT
    ICD10Code,
    ICD10Description,
    DOMAIN_ID,
    CONCEPT_ID,
    CONCEPT_NAME
INTO #epilepsy_concepts_icd10
FROM CDWWork.OMOPV5Dim.ICD10_CONCEPT
WHERE ICD10Code LIKE 'G40%'

DROP TABLE IF EXISTS #all_epilepsy_concepts
SELECT *
INTO #all_epilepsy_concepts
FROM (
    SELECT CONCEPT_NAME, CONCEPT_ID FROM #epilepsy_concepts_icd9
    UNION
    SELECT CONCEPT_NAME, CONCEPT_ID FROM #epilepsy_concepts_icd10
) tmp
WHERE CONCEPT_NAME NOT IN ('Seizure', 'Seizure disorder', 'Refractory migraine');

DROP TABLE IF EXISTS #seizure_concepts_icd10
SELECT DISTINCT
	m.ICD10Code,
	m.ICD10Description,
	m.DOMAIN_ID,
	m.CONCEPT_ID,
	m.CONCEPT_NAME
INTO #seizure_concepts_icd10
FROM CDWWork.OMOPV5Dim.ICD10_CONCEPT AS m
WHERE
	1 = 1
	AND m.ICD10Code = 'R40.4'
	OR m.ICD10Code = 'R56.1'
	OR m.ICD10Code = 'R56.9'
;

DROP TABLE IF EXISTS #seizure_concepts_icd9
SELECT DISTINCT
	m.ICD9Code,
	m.ICD9Description,
	m.DOMAIN_ID,
	m.CONCEPT_ID,
	m.CONCEPT_NAME
INTO #seizure_concepts_icd9
FROM CDWWork.OMOPV5Dim.ICD9_CONCEPT AS m
WHERE
	1 = 1
	AND m.ICD9Code = '345.8'
	OR m.ICD9Code = '780.39'
;

DROP TABLE IF EXISTS #all_seizure_concepts
SELECT *
INTO #all_seizure_concepts
FROM (
    SELECT CONCEPT_NAME, CONCEPT_ID FROM #seizure_concepts_icd9
    UNION
    SELECT CONCEPT_NAME, CONCEPT_ID FROM #seizure_concepts_icd10
) tmp
WHERE 
    1 = 1
;

DROP TABLE IF EXISTS #asm_concepts
SELECT DISTINCT
	c.CONCEPT_ID,
	c.CONCEPT_NAME
INTO #asm_concepts
FROM CDWWork.OMOPV5.CONCEPT AS c
WHERE
	1=1
	AND (
		LOWER(c.CONCEPT_NAME) LIKE '%brivaracetam%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%cannabidiol%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%carbamazepine%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%cenobamate%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%clobazam%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%diazepam%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%divalproex%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%eslicarbazepine%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%ethosuximide%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%ethotoin%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%ezogabine%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%felbamate%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%fosphenytoin%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%gabapentin%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%lacosamide%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%lamotrigine%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%levetiracetam%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%methsuximide%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%midazolam%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%oxcarbazepine%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%perampanel%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%phenobarbital%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%phenytoin%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%pregabalin%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%primidone%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%rufinamide%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%tiagabine%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%topiramate%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%valproic%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%valproate%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%vigabatrin%'
		OR LOWER(c.CONCEPT_NAME) LIKE '%zonisamide%'
		)
	AND c.DOMAIN_ID IN (SELECT DOMAIN_ID FROM CDWWork.OMOPV5.DOMAIN WHERE LOWER(DOMAIN_NAME) = 'drug')
	AND c.STANDARD_CONCEPT = 'S'
	AND c.CONCEPT_NAME NOT LIKE '%extract%'
	AND c.CONCEPT_NAME NOT LIKE '% / %'
	AND LOWER(c.CONCEPT_NAME) NOT LIKE '%chlordiazepam%'
	AND LOWER(c.CONCEPT_NAME) NOT LIKE '%diazepam%oral%'
	AND LOWER(c.CONCEPT_NAME) NOT LIKE '%diazepam%syringe%'
	AND LOWER(c.CONCEPT_NAME) NOT LIKE '%diazepam%intramusc%'
	AND LOWER(c.CONCEPT_NAME) NOT LIKE '%midazolam%oral%'
	AND LOWER(c.CONCEPT_NAME) NOT LIKE '%midazolam%syringe%'
	AND LOWER(c.CONCEPT_NAME) NOT LIKE '%midazolam%intramusc%'
	AND LOWER(c.CONCEPT_NAME) NOT LIKE '%midazolam%inject%'
;

DROP TABLE IF EXISTS #all_asm_exposures
SELECT DISTINCT
	de.PERSON_ID,
	MIN(de.DRUG_EXPOSURE_START_DATE) AS FIRST_EXPOSURE,
	MAX(de.DRUG_EXPOSURE_END_DATE) AS LATEST_EXPOSURE
INTO #all_asm_exposures
FROM CDWWork.OMOPV5.DRUG_EXPOSURE AS de
	INNER JOIN #asm_concepts AS asm ON asm.CONCEPT_ID = de.DRUG_CONCEPT_ID
	INNER JOIN CDWWork.OMOPV5.DRUG_STRENGTH AS ds ON ds.DRUG_CONCEPT_ID = de.DRUG_CONCEPT_ID
	INNER JOIN CDWWork.OMOPV5.CONCEPT AS au ON au.CONCEPT_ID = ds.AMOUNT_UNIT_CONCEPT_ID
	INNER JOIN CDWWork.OMOPV5.CONCEPT AS di ON di.CONCEPT_ID = ds.INGREDIENT_CONCEPT_ID
WHERE
	1=1
	AND ds.AMOUNT_VALUE != 0.0
	AND de.DAYS_SUPPLY != 0
	AND asm.CONCEPT_NAME NOT LIKE '%gabapentin%'
	AND de.DRUG_EXPOSURE_START_DATE >= '2004-01-01' --EDIT HERE TO CHANGE DATES OF COHORT!
	AND de.DRUG_EXPOSURE_START_DATE < '2024-01-01'
GROUP BY de.PERSON_ID, di.CONCEPT_NAME
HAVING SUM(de.DAYS_SUPPLY) >= 30
;

--Next, take the person_id for all of these rows
--Get all condition occurrence of seizure related icd code in that year of ASM usage plus last two years
DROP TABLE IF EXISTS #epilepsy1_pt_only;
SELECT DISTINCT
	asm.PERSON_ID
INTO #epilepsy1_pt_only
FROM #all_asm_exposures AS asm
	INNER JOIN CDWWork.OMOPV5.CONDITION_OCCURRENCE AS co 
	ON co.PERSON_ID = asm.PERSON_ID
	INNER JOIN CDWWork.OMOPV5.VISIT_OCCURRENCE AS vo
	ON vo.VISIT_OCCURRENCE_ID = co.VISIT_OCCURRENCE_ID
	LEFT JOIN CDWWork.OUTPAT.Visit AS v
	ON v.VisitSID = vo.x_Source_ID_Primary
	LEFT JOIN CDWWork.DIM.StopCode AS sc
	ON sc.StopCodeSID = v.PrimaryStopCodeSID
WHERE
	1=1
	AND (
		co.CONDITION_CONCEPT_ID IN (SELECT CONCEPT_ID FROM #all_seizure_concepts)
		OR co.CONDITION_CONCEPT_ID IN (SELECT CONCEPT_ID FROM #all_epilepsy_concepts)
		)
	AND co.CONDITION_START_DATE >= '2001-01-01' --EDIT HERE TO CHANGE DATES OF COHORT!
	AND co.CONDITION_START_DATE < '2024-01-01'
	AND sc.StopCode NOT IN (106, 128)


--Now look all the way back on their meds and repeat, but with the condition that the condition start date is within 2 years of a ASM
DROP TABLE IF EXISTS #epilepsy1_exposures
SELECT DISTINCT
	p.PERSON_ID,
	MIN(de.DRUG_EXPOSURE_START_DATE) AS FIRST_EXPOSURE,
	MAX(de.DRUG_EXPOSURE_END_DATE) AS LATEST_EXPOSURE
INTO #epilepsy1_exposures
FROM #epilepsy1_pt_only AS p
	INNER JOIN CDWWork.OMOPV5.DRUG_EXPOSURE AS de
	ON de.PERSON_ID = p.PERSON_ID
	INNER JOIN #asm_concepts AS asm
	ON asm.CONCEPT_ID = de.DRUG_CONCEPT_ID
	INNER JOIN CDWWork.OMOPV5.DRUG_STRENGTH AS ds
	ON ds.DRUG_CONCEPT_ID = de.DRUG_CONCEPT_ID
	INNER JOIN CDWWork.OMOPV5.CONCEPT AS au
	ON au.CONCEPT_ID = ds.AMOUNT_UNIT_CONCEPT_ID
	INNER JOIN CDWWork.OMOPV5.CONCEPT AS di 
	ON di.CONCEPT_ID = ds.INGREDIENT_CONCEPT_ID
WHERE
	1=1
	AND ds.AMOUNT_VALUE != 0.0
	AND de.DAYS_SUPPLY != 0
	AND asm.CONCEPT_NAME NOT LIKE '%gabapentin%'
GROUP BY p.PERSON_ID, di.CONCEPT_NAME
HAVING SUM(de.DAYS_SUPPLY) >= 30 -- how was this decided?


--finalize by selected first_dx_date as the earliest ASM exposure
DROP TABLE IF EXISTS #epilepsy1;
SELECT DISTINCT
	asm.PERSON_ID,
	MIN(asm.FIRST_EXPOSURE) AS FIRST_DX_DATE
INTO #epilepsy1
FROM #epilepsy1_exposures AS asm
	INNER JOIN CDWWork.OMOPV5.CONDITION_OCCURRENCE AS co 
	ON co.PERSON_ID = asm.PERSON_ID
	INNER JOIN CDWWork.OMOPV5.VISIT_OCCURRENCE AS vo
	ON vo.VISIT_OCCURRENCE_ID = co.VISIT_OCCURRENCE_ID
	LEFT JOIN CDWWork.OUTPAT.Visit AS v
	ON v.VisitSID = vo.x_Source_ID_Primary
	LEFT JOIN CDWWork.DIM.StopCode AS sc
	ON sc.StopCodeSID = v.PrimaryStopCodeSID
WHERE
	1=1
	AND (
		co.CONDITION_CONCEPT_ID IN (SELECT CONCEPT_ID FROM #all_seizure_concepts)
		OR co.CONDITION_CONCEPT_ID IN (SELECT CONCEPT_ID FROM #all_epilepsy_concepts)
		)
	AND YEAR(asm.FIRST_EXPOSURE) - YEAR(co.CONDITION_START_DATE) <= 2
	AND YEAR(asm.LATEST_EXPOSURE) - YEAR(co.CONDITION_START_DATE) >= 0
	AND sc.StopCode NOT IN (106, 128)
GROUP BY asm.PERSON_ID

DROP TABLE IF EXISTS #epilepsy2;
SELECT
	co.PERSON_ID,
	MIN(co.CONDITION_START_DATE) AS FIRST_DX_DATE
INTO #epilepsy2
FROM CDWWork.OMOPV5.CONDITION_OCCURRENCE AS co
	INNER JOIN CDWWork.OMOPV5.VISIT_OCCURRENCE AS vo
	ON vo.VISIT_OCCURRENCE_ID = co.VISIT_OCCURRENCE_ID
	LEFT JOIN CDWWork.OMOPV5Map.Institution_Code_CARE_SITE AS ics -- relevance
	ON ics.CARE_SITE_ID = vo.CARE_SITE_ID
	LEFT JOIN CDWWork.OUTPAT.Visit AS v
	ON v.VisitSID = vo.x_Source_ID_Primary
	LEFT JOIN CDWWork.DIM.StopCode AS sc
	ON sc.StopCodeSID = v.PrimaryStopCodeSID
WHERE
	1=1
	AND co.CONDITION_CONCEPT_ID IN (SELECT CONCEPT_ID FROM #all_epilepsy_concepts)
	AND vo.VISIT_CONCEPT_ID = 9201 --Inpat CHECK THIS!!!, check where?
	--AND co.CONDITION_START_DATE >= '2022-01-01' --EDIT HERE TO CHANGE DATES OF COHORT!
	--AND co.CONDITION_START_DATE < '2023-01-01'
	AND sc.StopCode NOT IN (106, 128) -- EEG, EEG Monitoring
GROUP BY co.PERSON_ID
HAVING SUM(CASE WHEN co.CONDITION_START_DATE >= '2004-01-01' AND co.CONDITION_START_DATE < '2024-01-01' THEN 1 ELSE 0 END) > 0;

DROP TABLE IF EXISTS #epilepsy3_pt_only;
SELECT
	co.PERSON_ID
INTO #epilepsy3_pt_only
FROM CDWWork.OMOPV5.CONDITION_OCCURRENCE AS co
	INNER JOIN CDWWork.OMOPV5.VISIT_OCCURRENCE AS vo
	ON vo.VISIT_OCCURRENCE_ID = co.VISIT_OCCURRENCE_ID
	LEFT JOIN CDWWork.OUTPAT.Visit AS v
	ON v.VisitSID = vo.x_Source_ID_Primary
	LEFT JOIN CDWWork.DIM.StopCode AS sc
	ON sc.StopCodeSID = v.PrimaryStopCodeSID
WHERE
	1=1
	AND co.CONDITION_CONCEPT_ID IN (SELECT CONCEPT_ID FROM #all_epilepsy_concepts)
	AND vo.VISIT_CONCEPT_ID = 9202 --Outpat
	AND co.CONDITION_START_DATE >= '2004-01-01' --EDIT HERE TO CHANGE DATES OF COHORT!
	AND co.CONDITION_START_DATE < '2024-01-01'
	AND sc.StopCode NOT IN (106, 128)
	AND vo.x_Source_Table != 'Fee_Inpatient_Merged' -- why exclude? -- fee table?
GROUP BY co.PERSON_ID
HAVING
	COUNT(DISTINCT vo.VISIT_START_DATE) >= 2

--how to get the actual first_dx_date 
--1. Get the list of patients who qualify
--2. Re run code with that subset of patients, getting their set of all outpatient visits which qualify
--3. Get the day they met criteria, based on that list of visits

DROP TABLE IF EXISTS #epilepsy3_all_visits
SELECT DISTINCT
	p.PERSON_ID,
	co.CONDITION_START_DATE
INTO #epilepsy3_all_visits
FROM #epilepsy3_pt_only AS p
	INNER JOIN CDWWork.OMOPV5.CONDITION_OCCURRENCE AS co
	ON co.PERSON_ID = p.PERSON_ID
	INNER JOIN CDWWork.OMOPV5.VISIT_OCCURRENCE AS vo
	ON vo.VISIT_OCCURRENCE_ID = co.VISIT_OCCURRENCE_ID
	LEFT JOIN CDWWork.OUTPAT.Visit AS v
	ON v.VisitSID = vo.x_Source_ID_Primary
	LEFT JOIN CDWWork.DIM.StopCode AS sc
	ON sc.StopCodeSID = v.PrimaryStopCodeSID
WHERE
	1=1
	AND co.CONDITION_CONCEPT_ID IN (SELECT CONCEPT_ID FROM #all_epilepsy_concepts)
	AND vo.VISIT_CONCEPT_ID = 9202 --Outpat
	AND sc.StopCode NOT IN (106, 128)
	AND vo.x_Source_Table != 'Fee_Inpatient_Merged'

-- question here 

DROP TABLE IF EXISTS #epilepsy3
SELECT DISTINCT
	rv.PERSON_ID,
	rv.CONDITION_START_DATE AS FIRST_DX_DATE
INTO #epilepsy3
FROM (
	SELECT DISTINCT
		v1.PERSON_ID,
		v1.CONDITION_START_DATE,
		ROW_NUMBER() OVER (PARTITION BY v1.PERSON_ID ORDER BY v1.CONDITION_START_DATE) AS VISIT_RANK
	FROM #epilepsy3_all_visits AS v1
	INNER JOIN #epilepsy3_all_visits AS v2
	ON v1.PERSON_ID = v2.PERSON_ID
	WHERE ABS(DATEDIFF(DAY, v1.CONDITION_START_DATE, v2.CONDITION_START_DATE)) <= 365
) AS rv
WHERE VISIT_RANK = 2



DROP TABLE IF EXISTS #all_epileptic;
WITH ordered_dx AS (
SELECT 
	PERSON_ID,
	FIRST_DX_DATE,
	ROW_NUMBER() OVER (PARTITION BY PERSON_ID ORDER BY FIRST_DX_DATE) AS rn
FROM
(
	SELECT * FROM #epilepsy2
	UNION
	SELECT * FROM #epilepsy3
	UNION
	SELECT * FROM #epilepsy1
) AS COMBINED
)
SELECT DISTINCT
	ordered_dx.PERSON_ID,
	pmap.PatientICN,
	FIRST_DX_DATE
INTO #all_epileptic
FROM ordered_dx
LEFT JOIN CDWWork.OMOPV5Map.SPatient_PERSON AS pmap
ON pmap.PERSON_ID = ordered_dx.PERSON_ID
WHERE rn = 1;


DROP TABLE IF EXISTS #cohort_trauma_icd10_records
SELECT DISTINCT
	coh.PatientICN,
	coh.FIRST_DX_DATE,
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
	coh.FIRST_DX_DATE,
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



DROP TABLE IF EXISTS #recent_tbi
SELECT
	sq.PatientICN,
	sq.TBIDateTime,
	CASE
		WHEN sq.ICD9Code IS NOT NULL THEN 0
		WHEN sq.ICD10Code IS NOT NULL THEN 1
	END AS ICD10
INTO 
	#recent_tbi
FROM (
	SELECT
		coh.PatientICN,
		coh.VisitDateTime,
		coh.ICD9Code,
		coh.ICD10Code,
		ROW_NUMBER() OVER(PARTITION BY [coh].[PatientICN] ORDER BY coh.VisitDateTime desc) AS v
	FROM (
		SELECT * FROM #cohort_trauma_icd10_records
		UNION ALL
		SELECT * FROM #cohort_trauma_icd9_records
	) coh
	WHERE coh.VisitDateTime < coh.FIRST_DX_DATE
) sq




DROP TABLE IF EXISTS [SCS_EEGUtil].[EEG].[rn_cohort2]
CREATE TABLE [SCS_EEGUtil].[EEG].[rn_cohort2] (
    PatientICN VARCHAR(50) PRIMARY KEY,
    BirthDateTime DATETIME,
    FirstDXDateTime DATETIME,
    LatestVisitDateTime DATETIME,
    DeathDateTime DATETIME,
    TBIDateTime DATETIME,
	TBIICDCode VARCHAR(10),
	ICD10 BIT -- 0 if ICD-9, 1 if ICD-10
)

INSERT INTO [SCS_EEGUtil].[EEG].[rn_cohort2] (
    PatientICN,
    BirthDateTime,
    FirstDXDateTime,
    LatestVisitDateTime,
    DeathDateTime,
    TBIDateTime,
	TBIICDCode,
	ICD10
) 
SELECT
    sq.PatientICN,
    sq.BirthDateTime,
    sq.FirstDXDateTime,
    sq.LatestVisitDateTime,
    sq.DeathDateTime,
    sq.TBIDateTime,
	sq.TBIICDCode,
	sq.ICD10
FROM (
    SELECT
        [coh].[PatientICN],
        [coh].[FIRST_DX_DATE] AS FirstDXDateTime,
        [sp].[BirthDateTime],
        [sp].[DeathDateTime],
        [v].[VisitDateTime] AS LatestVisitDateTime, 
		[rec].[MostRecentTBIVisitDateTime] AS TBIDateTime,
		[rec].[TBIICDCode],
		[rec].[ICD10],
        ROW_NUMBER() OVER(PARTITION BY [sp].[PatientICN] ORDER BY v.VisitDateTime desc) AS rn
    FROM [CDWWork].[Outpat].[Visit] v
    INNER JOIN [CDWWork].[SPatient].[SPatient] sp
        ON [v].[PatientSID] = [sp].[PatientSID]
    INNER JOIN [#all_epileptic] coh
        ON [sp].[PatientICN] = [coh].[PatientICN]
    LEFT JOIN [#recent_tbi] rec
        ON [sp].[PatientICN] = [rec].[PatientICN]
    WHERE
        [v].[VisitDateTime] < GETDATE()
) sq
WHERE sq.rn = 1



-- DROP TABLE IF EXISTS #tmp
-- SELECT
--     coh.PatientICN,
--     v.PatientPercentServiceConnect
-- INTO
--     #tmp
-- FROM
--     [SCS_EEGUtil].[EEG].[rn_cohort2] coh
--     INNER JOIN
--     CDWWork.Patient.Patient pat
--         ON
--         coh.PatientICN = pat.PatientICN
--     INNER JOIN
--     CDWWork.Outpat.Visit v
--         ON
--         pat.PatientSID = v.PatientSID
--         AND
--         coh.FirstDXDateTime = v.VisitDateTime
    

-- SELECT * FROM #tmp
