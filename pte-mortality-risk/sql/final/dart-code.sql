/************************************************************************ 

Project		: Haneef_202402056D
Type		: Cohort Creation
PI			: Haneef
Author		: R.Bell
Date		: 5/03/2024
Server		: RB03
Data Source	: CDWWork (VistA), CDWWork2 (Millennium)

--------------------------------------------------------------------------

Requests from Attrition Table:
Inclusion Criteria
	1.	(H7)	Number of distinct Veterans seen in nationwide outpatient or inpatient or non-VA community care settings from 1999-01-01 through date of query.
	2.	(H8)	Number of row 7 patients seen with Epilepsy ICD9 and ICD10 codes specified in Excel ICD tabs in nationwide outpatient or inpatient or non-VA community care settings from 1999-01-01 through date of query.

--------------------------------------------------------------------------
Change Log:
Date:			By Whom:				Description of Change:	


*************************************************************************/

/********************************  H7  **********************************
	
	1.	Number of distinct Veterans seen in nationwide outpatient or 
		inpatient or non-VA community care settings from 1999-01-01 
		through date of query.

*************************************************************************/

/****************************************************
	VistA Visits SOP;		Updated: 10/12/2023
*****************************************************/

--	1.1		Get Outpatient, Inpatient, Purchased Care (Fee Basis), and IVC_CDS Visits

DROP TABLE IF EXISTS #VistA_Visits;

;WITH VISITS AS(
	-- Outpatient VistA
	SELECT 
			V.PatientSID
			--,V.VisitDateTime AS VisitDateTime
			--,V.Sta3n
		FROM 
			--CDWWork.Outpat.Workload	AS V
			CDWWork.Outpat.Visit AS V		-- Use Outpat.Visit for ORD Cohort Provisioning Projects
		WHERE
				V.VisitDateTime >= CAST('1999-01-01' AS DateTime2(0))
			AND V.VisitDateTime < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0))
			--AND V.Sta3n = XXX 

	-- Outpatient Fee Basis
	UNION
	SELECT 
			FeeT.PatientSID 
			--,FeeT.InitialTreatmentDateTime AS VisitDateTime
			--,FeeT.Sta3n
		FROM 
			CDWWork.Fee.FeeInitialTreatment AS FeeT
		WHERE
				FeeT.InitialTreatmentDateTime >= CAST('1999-01-01' AS DateTime2(0)) 
			AND FeeT.InitialTreatmentDateTime < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0))
			--AND FeeT.Sta3n = XXX 

	-- Inpatient VistA
	UNION
	SELECT 
			I.PatientSID
			--,CASE 
			--	WHEN I.DischargeDateTime < GETDATE() THEN I.DischargeDateTime
			--	 ELSE I.AdmitDateTime END AS VisitDateTime
			--,I.Sta3n
		FROM 
			CDWWork.Inpat.Inpatient AS I
		WHERE
				(I.DischargeDateTime >= CAST('1999-01-01' AS DateTime2(0)) -- Enter Study Window Start Date Here
					OR I.DischargeDateTime IS NULL) -- Patients can be currently inpatient
			AND I.AdmitDateTime >= CAST('10/01/1999' AS DateTime2(0)) -- Only get records after the start of EHR Records
			AND I.AdmitDateTime < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0)) -- Enter Study Window End Date Here		
			--AND I.Sta3n = XXX

	-- Inpatient Fee Basis
	UNION
	SELECT 
			FeeI.PatientSID 
			--,CASE 
			--		WHEN FeeI.TreatmentToDateTime < GETDATE() THEN FeeI.TreatmentToDateTime
			--		ELSE FeeI.TreatmentFromDateTime END AS VisitDateTime
			--,FeeI.Sta3n
		FROM 
			CDWWork.Fee.FeeInpatInvoice AS FeeI
		WHERE
				(FeeI.TreatmentToDateTime >= CAST('1999-01-01' AS DateTime2(0)) -- Enter Study Window Start Date Here
					OR FeeI.TreatmentToDateTime IS NULL) -- Patients can be currently inpatient
			AND FeeI.TreatmentFromDateTime >= CAST('10/01/1999' AS DateTime2(0)) -- Only get records after the start of EHR Records
			AND FeeI.TreatmentFromDateTime < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0)) -- Enter Study Window End Date Here			
			--AND FeeI.Sta3n = XXX
	
	-- Inpatient VistA Fee
	UNION
	SELECT 
			IPFee.PatientSID
			--,CASE 
			--	WHEN IPFee.DischargeDateTime < GETDATE() THEN IPFee.DischargeDateTime
			--	 ELSE IPFee.AdmitDateTime END AS VisitDateTime
			--,IPFee.Sta3n
		FROM 
			CDWWork.Inpat.InpatientFeeBasis AS IPFee
		WHERE
				(IPFee.DischargeDateTime >= CAST('1999-01-01' AS DateTime2(0)) -- Enter Study Window Start Date Here
					OR IPFee.DischargeDateTime IS NULL) -- Patients can be currently inpatient
			AND IPFee.AdmitDateTime >= CAST('10/01/1999' AS DateTime2(0)) -- Only get records after the start of EHR Records
			AND IPFee.AdmitDateTime < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0)) -- Enter Study Window End Date Here	
			--AND IPFee.Sta3n = XXX 
)
SELECT
		PAT.PatientICN
		--,CTE.VisitDateTime
		--,Sta3n
	INTO
		#VistA_Visits
	FROM 
		VISITS AS CTE
	INNER JOIN
		CDWWork.Patient.Patient AS PAT
		ON		CTE.PatientSID = PAT.PatientSID
		
UNION
SELECT
		[Patient_ICN] AS PatientICN
		--,CASE 
		--	WHEN IVC_CH.Service_End_Date < GETDATE() THEN IVC_CH.Service_End_Date
		--	ELSE IVC_CH.Service_Start_Date END AS VisitDateTime
		--,TRY_CONVERT(SmallINT,(LEFT(IVC_CH.Station_Number, 3))) AS Sta3n 
	FROM
		[VINCI_IVC_CDS].[IVC_CDS].[CDS_Claim_Header] AS IVC_CH
	WHERE
			(IVC_CH.Service_End_Date >= CAST('1999-01-01' AS DATE)  -- Enter Study Window Start Date Here
				OR IVC_CH.Service_End_Date IS NULL) -- Patients can be currently inpatient
		AND IVC_CH.Service_Start_Date >= CAST('10/01/1999' AS DATE) -- Only get records after the start of EHR Records
		AND IVC_CH.Service_Start_Date < CAST(GETDATE() AS DATE) -- Enter Study Window End Date Here	
		--AND LEFT(IVC_CH.Station_Number, 3) = 'XXX' -- This is Sta6a taking left 3 to match Sta3n
		--To differentiate between Inpatient and Outpatient is more indepth and nuanced. Please reference:
		-- https://www.hsrd.research.va.gov/centers/core/accent/Finding-Inpatient-Stays-in-CDS.pdf
;	
--	18252013 Rows;		6m:28s



/********************************************************************************
	VistA Standard Exclusion SOP;		Updated: 11/17/2023
*********************************************************************************/

--	1.2		Standard Exclusion Criteria - Delete patients from cohort

;WITH BasicExc AS( -- Basic Exclusions for Feasibilities, CTRs, Cohort Creations, etc.
	SELECT
			COH.PatientICN
		FROM
			#VistA_Visits AS COH -- Press CTRL+SHIFT+M to populate with your Cohort Table
		INNER JOIN
			CDWWork.Patient.Patient AS PAT
			ON		COH.PatientICN = PAT.PatientICN
		WHERE
				PAT.PatientSID < 1 -- Missing ICN (unlikely, but just in case)
			OR	PAT.CDWPossibleTestPatientFlag <> 'N' -- Test Patient (see documentation for how this is determined)
			OR	PAT.PatientICN IN ('*Missing*','*Unknown at this time*') -- Missing ICN (unlikely, but just in case)
	UNION
	SELECT
			COH.PatientICN
		FROM
			#VistA_Visits AS COH -- Press CTRL+SHIFT+M to populate with your Cohort Table
		WHERE
			NOT EXISTS (SELECT TOP 1 1 FROM CDWWork.Veteran.MVIPerson AS MVI WHERE COH.PatientICN = MVI.MVIPersonICN)

	UNION -- UNION because we exclude test patients AND/OR non-Veteran
	SELECT
			COH.PatientICN
		FROM
			#VistA_Visits AS COH
		INNER JOIN
			CDWWork.Veteran.MVIPerson AS MVI
			ON		COH.PatientICN = MVI.MVIPersonICN
		LEFT JOIN
			CDWWork.Patient.Patient AS PAT
			ON		COH.PatientICN = PAT.PatientICN
		LEFT JOIN
			CDWWork.Veteran.ADRPerson AS ADR
			ON		COH.PatientICN = ADR.ADRPersonICN
		GROUP BY -- group so we can consider all VeteranFlags for each patient
				COH.PatientICN
		HAVING -- Logic: if patient has ANY VeteranFlag = 'Y', consider them a Veteran. Prioritize ADR over Patient.
			MAX(
				CASE -- use CASE for non-Y/N values
					WHEN 
						ISNULL(ADR.VeteranFlag, PAT.VeteranFlag) = 'Y'  -- Prioritize ADR over Patient
						OR MVI.InteroperabilityPersonType = 'VETERAN (per VA)' -- OR use MVI (documentation: https://www.hsrd.research.va.gov/for_researchers/cyber_seminars/archives/6303-notes.pdf slide 29)
						THEN 'Y' 
						ELSE 'N' 
					END
				) <> 'Y'
)
DELETE -- deletion is more efficient than another SELECT
		COH
	FROM
		#VistA_Visits AS COH -- Press CTRL+SHIFT+M to populate with your Cohort Table
	LEFT JOIN
		BasicExc AS B
		ON		COH.PatientICN = B.PatientICN
	WHERE
			B.PatientICN IS NOT NULL
		OR	COH.PatientICN IS NULL;

--	2457534 Deletions;	3m:09s



/****************************************************
	Millennium Visit SOP;		Updated: 02/05/2024
*****************************************************/

--	1.3		Get Millennium Visits

DROP TABLE IF EXISTS #MillVisits;

SELECT 
		ENC.PersonSID
		--,COALESCE(ENC.RegistrationDateTime, ENC.PreRegistrationDateTime) AS VisitDateTime
	INTO	
		#MillVisits
	FROM	
		CDWWORK2.EncMill.Encounter AS ENC
	INNER JOIN 
		CDWWork2.Mill.VALocations AS VALC 
		ON 		VALC.OrganizationNameSID = ENC.OrganizationNameSID
	WHERE	
			ENC.BeginEffectiveDateTime <= CAST(GETDATE() AS Datetime2(0))
		AND ENC.EndEffectiveDateTime >= CAST(GETDATE() AS Datetime2(0))
		AND ENC.ActiveIndicator = 1
		AND ENC.EncounterTypeClass IN ('OUTPATIENT','EMERGENCY','HOME HEALTH','RECURRING') 
		AND	(ENC.EncounterType IN 
				('EMERGENCY','HOME HEALTH' ,'DAY SURGERY','OCCUPATIONAL HEALTH'
				,'TELEHEALTH','OUTPATIENT','OUTPATIENT IN A BED','CARE COORDINATION'
				,'CARE TRANSITIONS','RECURRING' ,'HBPC','TELEPHONE')	
		-- Community Care
			OR ENC.EncounterType like '%Community%Care%' -- Uncomment if community care data is needed
			)
		AND COALESCE(ENC.RegistrationDateTime, ENC.PreRegistrationDateTime) >= CAST('1999-01-01' AS Datetime2(0)) 
		AND COALESCE(ENC.RegistrationDateTime, ENC.PreRegistrationDateTime) < CAST(GetDate() AS Datetime2(0))
		--AND VALC.STAPA = 'XXXXX'--Uncomment out this line if need to limit StaPa

UNION
SELECT 
		ENC.PersonSID
		--,CASE 
		--	WHEN ENC.DischargeDateTime < GETDATE() THEN ENC.DischargeDateTime
		--	ELSE COALESCE(ENC.InpatientAdmitDateTime, ENC.RegistrationDateTime) 
		--	END AS VisitDateTime
	FROM		
		CDWWORK2.EncMill.Encounter AS ENC
	INNER JOIN 
		CDWWork2.Mill.VALocations AS VALC 
		ON		VALC.OrganizationNameSID = ENC.OrganizationNameSID
	WHERE	
			ENC.BeginEffectiveDateTime <= CAST(GETDATE() AS Datetime2(0))
		AND ENC.EndEffectiveDateTime >= CAST(GETDATE() AS Datetime2(0))
		AND ENC.ActiveIndicator = 1
		AND (ENC.EncounterType IN ('Inpatient','SNF Inpatient','Observation')		
		-- Community Care
			OR ENC.EncounterType IN ('Community Care Inpatient','Community Care SNF') -- Uncomment if community care data is needed
			)
		AND (ENC.DischargeDateTime >= CAST('1999-01-01' AS DateTime2(0)) -- Enter Study Window Start Date Here
				OR ENC.DischargeDateTime IS NULL) -- Patients can be currently inpatient
		AND COALESCE(ENC.InpatientAdmitDateTime, ENC.RegistrationDateTime) >= CAST('10/01/1999' AS DateTime2(0))-- Only get records after the start of EHR Records
		AND COALESCE(ENC.InpatientAdmitDateTime, ENC.RegistrationDateTime) < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0)) -- Enter Study Window End Date Here	
		--AND VALC.STAPA = 'XXXXX'--Uncomment out this line if need to limit StaPa
;
--	186223 rows;		00m:42s



/****************************************************
	Millennium Get ICN SOP;		Updated: 8/3/2022
*****************************************************/

--	1.4		Get all ICN for Cohort

DROP TABLE IF EXISTS #MillICNCohort;

SELECT DISTINCT 
		COH.PersonSID
		,LEFT(SPA.AliasName,10) AS PatientICN 
	INTO
		#MillICNCohort
	FROM 
		#MillVisits as COH  
	LEFT JOIN 
		CDWWork2.SVeteranMill.SPersonAlias AS SPA 
		ON		SPA.PersonSID = COH.PersonSID
			AND	SPA.ActiveIndicator = 1
			AND GETDATE() BETWEEN SPA.BeginEffectiveDateTime AND SPA.EndEffectiveDateTime
			AND SPA.AliasPool = 'ICN' 
			AND SPA.PersonAliasType = 'Veteran ID'
		WHERE
			1 = 1
;
--	186223 rows;		00m:02s



--	1.5		Update Cohort with ICN using EDIPI

UPDATE COH
	SET	COH.PatientICN = D.MVIPersonICN 
	FROM 
		#MillICNCohort AS COH
	INNER JOIN 
		CDWWork2.SVeteranMill.SPersonAlias AS B 
		ON		COH.PersonSID = B.PersonSID
			AND B.ActiveIndicator = 1
			AND GETDATE() BETWEEN B.BeginEffectiveDateTime AND B.EndEffectiveDateTime
			AND B.PersonAliasTypeCodeValueSID= 1800223089 --'EDIPI'
	INNER JOIN 
		CDWWork.SVeteran.SMVIPersonSiteAssociation AS D 
		ON		B.AliasName = D.EDIPI
			AND D.MVIAssigningAuthoritySID = 3 
			AND	(D.ActiveMergedIdentifierCode IS NULL OR D.ActiveMergedIdentifierCode = 'A')
	WHERE 
		COH.PatientICN IS NULL
		
CREATE CLUSTERED COLUMNSTORE INDEX CCI ON #MillICNCohort		
;
--	74 rows;		1m:40s	



/****************************************************
	Millennium Standard Exclusion SOP;		Updated: 3/12/2024
*****************************************************/

--	1.6		Delete test patients from Millennium Cohort

;WITH BasicExc AS(
	SELECT DISTINCT
			COH.PatientICN
		FROM 
			#MillICNCohort AS COH  ---CONTAIN PersonSID
		INNER JOIN   
			CDWWork2.SVeteranMill.SPerson AS SP
			ON		COH.PersonSID = SP.PersonSID
		WHERE
				SP.ActiveIndicator = 1
			AND GETDATE() BETWEEN SP.BeginEffectiveDateTime AND SP.EndEffectiveDateTime
			AND (SP.NameLastKey LIKE 'QQ%'
			OR	SP.NameLastKey LIKE 'XX%'
			OR	SP.NameLastKey LIKE 'ZZ%'
			OR	SP.NameLastKey LIKE 'Z%TEST%'
			OR	SP.NameLastKey LIKE 'TEST%TEST%'
			OR	SP.NameLastKey = 'TEST'
			OR	SP.NameLastKey = 'CERNER'
			OR	SP.CDWPossibleTestPatientFlag = 'Y')

	UNION
	SELECT
			COH.PatientICN
		FROM
			#MillICNCohort AS COH
		INNER JOIN
			CDWWork.Veteran.MVIPerson AS MVI
			ON		COH.PatientICN = MVI.MVIPersonICN
		LEFT JOIN
			CDWWork.Patient.Patient AS PAT
			ON		COH.PatientICN = PAT.PatientICN
		LEFT JOIN
			CDWWork.Veteran.ADRPerson AS ADR
			ON		COH.PatientICN = ADR.ADRPersonICN
		GROUP BY -- group so we can consider all VeteranFlags for each patient
				COH.PatientICN
		HAVING -- Logic: if patient has ANY VeteranFlag = 'Y', consider them a Veteran. Prioritize ADR over Patient.
			MAX(
				CASE -- use CASE for non-Y/N values
					WHEN 
						ISNULL(ADR.VeteranFlag, PAT.VeteranFlag) = 'Y'  -- Prioritize ADR over Patient
						OR MVI.InteroperabilityPersonType = 'VETERAN (per VA)' -- OR use MVI (documentation: https://www.hsrd.research.va.gov/for_researchers/cyber_seminars/archives/6303-notes.pdf slide 29)
						THEN 'Y' 
						ELSE 'N' 
					END
				) <> 'Y'
)
DELETE
		COH
	FROM
		#MillICNCohort AS COH
	LEFT JOIN 
		BasicExc AS B
		ON		COH.PatientICN = B.PatientICN
	WHERE
			B.PatientICN IS NOT NULL
		OR	COH.PatientICN IS NULL
;			
--	10906 Deletions;		00m:39s



--	1.7		Rebuild index if already exists if not apply index

IF EXISTS (SELECT 1 FROM tempdb.sys.indexes WHERE NAME ='CCI'-- Name of Index here normally CCI
AND OBJECT_ID = OBJECT_ID ('tempdb..#MillICNCohort')) -- Put Table Here
ALTER INDEX
	CCI ON #MillICNCohort
REBUILD;

ELSE CREATE CLUSTERED COLUMNSTORE INDEX
	CCI ON #MillICNCohort
;
--	:05s



/********************************************************************************
	Combined All Patient Identifiers SOP;		Updated: 05/01/2023
*********************************************************************************/

--	1.8		Get All Patient Identifiers Nationwide

DROP TABLE IF EXISTS #MillVistAAllIdentifiers;

; WITH CombinedICN AS(
	SELECT 
			PatientICN
		FROM
			#VistA_Visits
	UNION
	SELECT 
			PatientICN
		FROM
			#MillICNCohort
)
, MillIdentifier_1 AS(
	SELECT DISTINCT 
			COH.PatientICN
			,MILL.PersonSID 
		FROM
			CombinedICN AS COH  -- use Combined cohort
		INNER JOIN 
			CDWWork.SVeteran.SMVIPersonSiteAssociation AS D 
			ON		D.MVIPersonICN = COH.PatientICN
				AND D.MVIAssigningAuthoritySID = 3 
				AND	(D.ActiveMergedIdentifierCode IS NULL OR D.ActiveMergedIdentifierCode = 'A')
		INNER JOIN
			CDWWork2.SVeteranMill.SPersonAlias AS MILL
			ON		MILL.AliasName = D.EDIPI
				AND MILL.ActiveIndicator = 1
				AND GETDATE() BETWEEN MILL.BeginEffectiveDateTime AND MILL.EndEffectiveDateTime
				AND MILL.PersonAliasTypeCodeValueSID= 1800223089 
)
, MillIdentifier_2 AS(
	SELECT DISTINCT 
			COH.PatientICN
			,MILL.PersonSID
		FROM
			CombinedICN AS COH  -- use Combined cohort
		INNER JOIN
			CDWWork2.SVeteranMill.SPersonAlias AS MILL
			ON		COH.PatientICN = LEFT(MILL.AliasName,10) 
				AND MILL.ActiveIndicator = 1
				AND GETDATE() BETWEEN MILL.BeginEffectiveDateTime AND MILL.EndEffectiveDateTime
				AND MILL.AliasPool = 'ICN' 
				AND MILL.PersonAliasType = 'Veteran ID'
		WHERE 
			NOT EXISTS (SELECT 1 FROM MillIdentifier_1 WHERE MillIdentifier_1.PersonSID = MILL.PersonSID)
)
SELECT DISTINCT
		COH.PatientICN
		,PAT.PatientSID
		,ISNULL(MILL1.PersonSID, MILL2.PersonSID) AS  PersonSID
	INTO
		#MillVistAAllIdentifiers
	FROM
		CombinedICN AS COH
	LEFT JOIN
		CDWWork.Patient.Patient AS PAT
		ON		COH.PatientICN = PAT.PatientICN
	LEFT JOIN
		MillIdentifier_1 AS MILL1
		ON		COH.PatientICN = MILL1.PatientICN
	LEFT JOIN
		MillIdentifier_2 AS MILL2
		ON		COH.PatientICN = MILL2.PatientICN
		
CREATE CLUSTERED COLUMNSTORE INDEX CCI ON #MillVistAAllIdentifiers		
;
--	33386133 rows;		3m:23s



--	1.9		Count distinct patients for Excel H7

SELECT COUNT(DISTINCT PatientICN) AS H7_Patient_Count FROM #MillVistAAllIdentifiers
;
--	15798861 DISTINCT H7 patients



/********************************  H8  **********************************
	
	2.	Number of row 7 patients seen with Epilepsy ICD9 and ICD10 codes 
		specified in Excel ICD tabs in nationwide outpatient or inpatient or 
		non-VA community care settings from 1999-01-01 through date of query.

*************************************************************************/

/*****************************************************
	VistA ICD-9 AND ICD-10 Codes SOP; Updated: 10/12/2023
*****************************************************/

--	2.1		Check ICD-9 Codes for Epilepsy

SELECT DISTINCT
		CODE.ICD9Code
		,DV.ICD9Description
	FROM 
		CDWWork.Dim.ICD9 AS CODE
	INNER JOIN
		CDWWork.Dim.ICD9DescriptionVersion AS DV
		ON		CODE.ICD9SID = DV.ICD9SID
	WHERE 
		(	CODE.ICD9Code LIKE '780.3%'		-- Insert ICD-9 Code
		OR	CODE.ICD9Code LIKE '345%'
		)
		AND DV.CurrentVersionFlag = 'Y'
	ORDER BY
		CODE.ICD9Code
;
--	31 Rows;		:XXs



--	2.2		Check ICD-10 Codes for Epilepsy

SELECT DISTINCT
		CODE.ICD10Code
		,DV.ICD10Description
	FROM 
		CDWWork.Dim.ICD10 AS CODE
	INNER JOIN
		CDWWork.Dim.ICD10DescriptionVersion AS DV
		ON		CODE.ICD10SID = DV.ICD10SID
	WHERE 
		(	CODE.ICD10Code LIKE 'G40%'		-- Insert ICD-10 Code
		OR	CODE.ICD10Code LIKE 'R40.4%'
		OR	CODE.ICD10Code LIKE 'R56.[1,9]%'
		)
		AND DV.CurrentVersionFlag = 'Y'
	ORDER BY
			CODE.ICD10Code;

--	57 Rows;		:05s



--	2.3		Make ICD dim table

DROP TABLE IF EXISTS #ICDSID_Epilepsy;

;WITH CTE AS(
	SELECT
			ICD9SID AS ICDSID
			,ICD9Code AS ICDCode		
			--,'ICD9' AS ICDCodeSource  -- Track ICD 9 or 10 as the source if needed
		FROM 
			CDWWork.Dim.ICD9
		WHERE 
			(	ICD9Code LIKE '780.3%'		-- Insert ICD-9 Code
			OR	ICD9Code LIKE '345%'
			)
	UNION		
	SELECT
			ICD10SID AS ICDSID
			,ICD10Code AS ICDCode		
			--,'ICD10' AS ICDCodeSource  -- Track ICD 9 or 10 as the source if needed
		FROM 
			CDWWork.Dim.ICD10
		WHERE 
			(	ICD10Code LIKE 'G40%'		-- Insert ICD-10 Code
			OR	ICD10Code LIKE 'R40.4%'
			OR	ICD10Code LIKE 'R56.[1,9]%'
			)
)
SELECT DISTINCT
		ICDSID
		,ICDCode
		--,ICDCodeSource
	INTO
		#ICDSID_Epilepsy
	FROM
		CTE
;
--	11440 Rows;		:08s



--	2.4		Find Patients from Cohort with requested ICD Diagnosis Codes

DROP TABLE IF EXISTS #ICD_VistA;

;WITH CTE AS(
--ICD 9 Section
	-- ICD 9 Outpatient
	SELECT
			COH.PatientICN
			--,OUTPAT.VisitDateTime AS DxDate
			--,ICD.ICDCode
			--,ICD.ICDCodeSource
			--,OUTPAT.Sta3n
		FROM 
			#MillVistAAllIdentifiers AS COH  -- Press CTRL+SHIFT+M to populate with your Cohort table
		INNER JOIN
			CDWWork.Outpat.VDiagnosis AS OUTPAT
			ON		OUTPAT.PatientSID = COH.PatientSID
		INNER JOIN 
			#ICDSID_Epilepsy AS ICD 
			ON		ICD.ICDSID = OUTPAT.ICD9SID
		WHERE 
				OUTPAT.VisitDateTime >= CAST('1999-01-01' AS DateTime2(0))
			AND OUTPAT.VisitDateTime < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0))
			--AND OUTPAT.Sta3n = XXX
	UNION
	-- ICD 9 Inpatient
	SELECT
			COH.PatientICN
			--,(CASE WHEN Dx.DischargeDateTime < CAST(GETDATE() AS DATE) THEN Dx.DischargeDateTime
			--  ELSE INPAT.AdmitDateTime END) AS DxDate 
			--,ICD.ICDCode
			--,ICD.ICDCodeSource
			--,INPAT.Sta3n
		FROM 
			#MillVistAAllIdentifiers AS COH  -- Press CTRL+SHIFT+M to populate with your Cohort table
		INNER JOIN
			CDWWork.Inpat.InpatientDiagnosis AS Dx
			ON		Dx.PatientSID = COH.PatientSID
		INNER JOIN
			CDWWork.Inpat.Inpatient AS INPAT
			ON		INPAT.InpatientSID = Dx.InpatientSID
		INNER JOIN 
			#ICDSID_Epilepsy AS ICD 
			ON		ICD.ICDSID = Dx.ICD9SID
		WHERE 
				(Dx.DischargeDateTime >= CAST('1999-01-01' AS DateTime2(0)) -- start date
					OR	Dx.DischargeDateTime IS NULL)
			AND INPAT.AdmitDateTime < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0)) -- end date
			AND INPAT.AdmitDateTime >= CAST('1999-10-01' AS DateTime2(0))
			--AND INPAT.Sta3n = XXX
	UNION
	-- ICD 9 Fee Outpatient
	SELECT
			COH.PatientICN
			--,FIT.InitialTreatmentDateTime AS DxDate
			--,ICD.ICDCode
			--,ICD.ICDCodeSource
			--,FIT.Sta3n
		FROM 
			#MillVistAAllIdentifiers AS COH  -- Press CTRL+SHIFT+M to populate with your Cohort table
		INNER JOIN
			CDWWork.Fee.FeeInitialTreatment AS FIT
			ON		FIT.PatientSID = COH.PatientSID
		INNER JOIN 
			CDWWork.Fee.FeeServiceProvided AS FSP
			ON		FSP.FeeInitialTreatmentSID = FIT.FeeInitialTreatmentSID
		INNER JOIN 
			#ICDSID_Epilepsy AS ICD 
			ON		ICD.ICDSID = FSP.ICD9SID
		WHERE 
				FIT.InitialTreatmentDateTime >= CAST('1999-01-01' AS DateTime2(0))
			AND FIT.InitialTreatmentDateTime < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0))
			--AND FIT.Sta3n = XXX
	UNION
	-- ICD 9 Fee Inpatient
	SELECT
			COH.PatientICN
			--,(CASE WHEN FINV.TreatmentToDateTime < CAST(GETDATE() AS DATE) THEN FINV.TreatmentToDateTime
			--  ELSE FINV.TreatmentFromDateTime END) AS DxDate 
			--,ICD.ICDCode
			--,ICD.ICDCodeSource
			--,FINV.Sta3n
		FROM
			#MillVistAAllIdentifiers AS COH  -- Press CTRL+SHIFT+M to populate with your Cohort table
		INNER JOIN
			CDWWork.Fee.FeeInpatInvoice AS FINV
			ON		FINV.PatientSID = COH.PatientSID
		INNER JOIN
			CDWWork.Fee.FeeInpatInvoiceICDDiagnosis AS FICD
			ON		FICD.FeeInpatInvoiceSID = FINV.FeeInpatInvoiceSID
		INNER JOIN 
			#ICDSID_Epilepsy AS ICD 
			ON		ICD.ICDSID = FICD.ICD9SID
		WHERE 
				(FINV.TreatmentToDateTime >= CAST('1999-01-01' AS DateTime2(0)) -- start date
					OR FINV.TreatmentToDateTime IS NULL)
			AND FINV.TreatmentFromDateTime < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0)) -- end date
			AND FINV.TreatmentFromDateTime >= CAST('1999-10-01' AS DateTime2(0))
			--AND FINV.Sta3n = XXX
	UNION
	-- ICD 9 Inpat.InpatientFeeDiagnosis
	SELECT
			COH.PatientICN
			--,(CASE WHEN IFEE.DischargeDateTime < CAST(GETDATE() AS DATE) THEN IFEE.DischargeDateTime
			--  ELSE IFEE.AdmitDateTime END) AS DxDate 
			--,ICD.ICDCode
			--,ICD.ICDCodeSource
			--,IFEE.Sta3n
		FROM
			#MillVistAAllIdentifiers AS COH  -- Press CTRL+SHIFT+M to populate with your Cohort table
		INNER JOIN
			CDWWork.Inpat.InpatientFeeDiagnosis AS IFEE
			ON		IFEE.PatientSID = COH.PatientSID
		INNER JOIN 
			#ICDSID_Epilepsy AS ICD 
			ON		ICD.ICDSID = IFEE.ICD9SID
		WHERE 
				(IFEE.DischargeDateTime >= CAST('1999-01-01' AS DateTime2(0)) -- start date
					OR IFEE.DischargeDateTime IS NULL)
			AND IFEE.AdmitDateTime < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0)) -- end date
			AND IFEE.AdmitDateTime >= CAST('1999-10-01' AS DateTime2(0))
			--AND IFEE.Sta3n = XXX
	UNION
-- ICD 10 Section 
	-- ICD 10 Outpatient
	SELECT
			COH.PatientICN
			--,OUTPAT.VisitDateTime AS DxDate
			--,ICD.ICDCode
			--,ICD.ICDCodeSource
			--,OUTPAT.Sta3n
		FROM 
			#MillVistAAllIdentifiers AS COH  -- Press CTRL+SHIFT+M to populate with your Cohort table
		INNER JOIN
			CDWWork.Outpat.VDiagnosis AS OUTPAT
			ON		OUTPAT.PatientSID = COH.PatientSID
		INNER JOIN 
			#ICDSID_Epilepsy AS ICD 
			ON		ICD.ICDSID = OUTPAT.ICD10SID
		WHERE 
				OUTPAT.VisitDateTime >= CAST('1999-01-01' AS DateTime2(0))
			AND OUTPAT.VisitDateTime < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0))
			--AND OUTPAT.Sta3n = XXX
	UNION
	-- ICD 10 Inpatient
	SELECT
			COH.PatientICN
			--,(CASE WHEN Dx.DischargeDateTime < CAST(GETDATE() AS DATE) THEN Dx.DischargeDateTime
			--  ELSE INPAT.AdmitDateTime END) AS DxDate 
			--,ICD.ICDCode
			--,ICD.ICDCodeSource
			--,INPAT.Sta3n
		FROM 
			#MillVistAAllIdentifiers AS COH  -- Press CTRL+SHIFT+M to populate with your Cohort table
		INNER JOIN
			CDWWork.Inpat.InpatientDiagnosis AS Dx
			ON		Dx.PatientSID = COH.PatientSID
		INNER JOIN
			CDWWork.Inpat.Inpatient AS INPAT
			ON		INPAT.InpatientSID = Dx.InpatientSID
		INNER JOIN 
			#ICDSID_Epilepsy AS ICD 
			ON		ICD.ICDSID = Dx.ICD10SID
		WHERE 
				(Dx.DischargeDateTime >= CAST('1999-01-01' AS DateTime2(0)) -- start date
					OR	Dx.DischargeDateTime IS NULL)
			AND INPAT.AdmitDateTime < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0)) -- end date
			AND INPAT.AdmitDateTime >= CAST('1999-10-01' AS DateTime2(0))
			--AND INPAT.Sta3n = XXX
	UNION
	-- ICD 10 Fee Outpatient
	SELECT
			COH.PatientICN
			--,FIT.InitialTreatmentDateTime AS DxDate
			--,ICD.ICDCode
			--,ICD.ICDCodeSource
			--,FIT.Sta3n
		FROM 
			#MillVistAAllIdentifiers AS COH  -- Press CTRL+SHIFT+M to populate with your Cohort table
		INNER JOIN
			CDWWork.Fee.FeeInitialTreatment AS FIT
			ON		FIT.PatientSID = COH.PatientSID
		INNER JOIN 
			CDWWork.Fee.FeeServiceProvided AS FSP
			ON		FSP.FeeInitialTreatmentSID = FIT.FeeInitialTreatmentSID
		INNER JOIN 
			#ICDSID_Epilepsy AS ICD 
			ON		ICD.ICDSID = FSP.ICD10SID
		WHERE 
				FIT.InitialTreatmentDateTime >= CAST('1999-01-01' AS DateTime2(0))
			AND FIT.InitialTreatmentDateTime < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0))
			--AND FIT.Sta3n = XXX
	UNION
	-- ICD 10 Fee Inpatient
	SELECT
			COH.PatientICN
			--,(CASE WHEN FINV.TreatmentToDateTime < CAST(GETDATE() AS DATE) THEN FINV.TreatmentToDateTime
			--  ELSE FINV.TreatmentFromDateTime END) AS DxDate 
			--,ICD.ICDCode
			--,ICD.ICDCodeSource
			--,FINV.Sta3n
		FROM
			#MillVistAAllIdentifiers AS COH  -- Press CTRL+SHIFT+M to populate with your Cohort table
		INNER JOIN
			CDWWork.Fee.FeeInpatInvoice AS FINV
			ON		FINV.PatientSID = COH.PatientSID
		INNER JOIN
			CDWWork.Fee.FeeInpatInvoiceICDDiagnosis AS FICD
			ON		FICD.FeeInpatInvoiceSID = FINV.FeeInpatInvoiceSID
		INNER JOIN 
			#ICDSID_Epilepsy AS ICD 
			ON		ICD.ICDSID = FICD.ICD10SID
		WHERE 
				(FINV.TreatmentToDateTime >= CAST('1999-01-01' AS DateTime2(0)) -- start date
					OR FINV.TreatmentToDateTime IS NULL)
			AND FINV.TreatmentFromDateTime < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0)) -- end date
			AND FINV.TreatmentFromDateTime >= CAST('1999-10-01' AS DateTime2(0))
			--AND FINV.Sta3n = XXX
	UNION
	-- ICD 10 Inpat.InpatientFeeDiagnosis
	SELECT
			COH.PatientICN
			--,(CASE WHEN IFEE.DischargeDateTime < CAST(GETDATE() AS DATE) THEN IFEE.DischargeDateTime
			--  ELSE IFEE.AdmitDateTime END) AS DxDate 
			--,ICD.ICDCode
			--,ICD.ICDCodeSource
			--,IFEE.Sta3n
		FROM
			#MillVistAAllIdentifiers AS COH  -- Press CTRL+SHIFT+M to populate with your Cohort table
		INNER JOIN
			CDWWork.Inpat.InpatientFeeDiagnosis AS IFEE
			ON		IFEE.PatientSID = COH.PatientSID
		INNER JOIN 
			#ICDSID_Epilepsy AS ICD 
			ON		ICD.ICDSID = IFEE.ICD10SID
		WHERE 
				(IFEE.DischargeDateTime >= CAST('1999-01-01' AS DateTime2(0)) -- start date
					OR IFEE.DischargeDateTime IS NULL)
			AND IFEE.AdmitDateTime < CAST(CAST(GETDATE() AS DATE) AS DateTime2(0)) -- end date
			AND IFEE.AdmitDateTime >= CAST('1999-10-01' AS DateTime2(0))
			--AND IFEE.Sta3n = XXX
)
SELECT
		PatientICN
		--,DxDate
		--,ICDCode
		--,ICDCodeSource
		--,Sta3n
	INTO
		#ICD_VistA
	FROM
		CTE
		
UNION
SELECT
		COH.PatientICN
		--,CASE 
			--WHEN IVC_CH.Service_End_Date < GETDATE() THEN IVC_CH.Service_End_Date
			--ELSE IVC_CH.Service_Start_Date END AS DxDate
		--,ICD_DIM.ICDCode
		--,ICD_DIM.ICDCodeSource
		--,TRY_CONVERT(SmallINT,(LEFT(IVC_CH.Station_Number, 3))) AS Sta3n 
	FROM
		#MillVistAAllIdentifiers AS COH  -- Press CTRL+SHIFT+M to populate with your Cohort table
	INNER JOIN 
		[VINCI_IVC_CDS].[IVC_CDS].[CDS_Claim_Diagnosis] AS IVC_CD
		ON		IVC_CD.[Patient_ICN] = COH.PatientICN
	INNER JOIN
		#ICDSID_Epilepsy AS ICD_DIM
		ON		REPLACE(ICD_DIM.ICDCode, '.', '') = IVC_CD.[ICD]
	INNER JOIN
		[VINCI_IVC_CDS].[IVC_CDS].[CDS_Claim_Header] AS IVC_CH
		ON		IVC_CH.ClaimSID = IVC_CD.ClaimSID
	WHERE
			(IVC_CH.Service_End_Date >= CAST('1999-01-01' AS DATE) -- Enter Study Window Start Date Here
				OR IVC_CH.Service_End_Date IS NULL) -- Patients can be currently inpatient
		AND IVC_CH.Service_Start_Date >= CAST('10/01/1999' AS DATE) -- Only get records after the start of EHR Records
		AND IVC_CH.Service_Start_Date < CAST(GETDATE() AS DATE) -- Enter Study Window End Date Here		
		--AND LEFT(IVC_CH.Station_Number, 3) = 'XXX' -- This is Sta6a taking left 3 to match Sta3n

UNION
SELECT 
		COH.PatientICN
		--,CASE 
		--	WHEN IVC_CL.Service_End_Date < GETDATE() THEN IVC_CL.Service_End_Date
		--	ELSE IVC_CL.Service_Start_Date END AS DxDate
		--,ICD_DIM.ICDCode
		--,ICD_DIM.ICDCodeSource
		--,TRY_CONVERT(SmallINT,(LEFT(IVC_CL.Station_Number, 3))) AS Sta3n
	FROM
		#MillVistAAllIdentifiers AS COH  -- Press CTRL+SHIFT+M to populate with your Cohort table
	INNER JOIN 
		[VINCI_IVC_CDS].[IVC_CDS].[CDS_Claim_Line_ICD_Detail] AS IVC_CLICD
		ON		IVC_CLICD.[Patient_ICN] = COH.PatientICN
	INNER JOIN
		#ICDSID_Epilepsy AS ICD_DIM
		ON		REPLACE(ICD_DIM.ICDCode, '.', '') = IVC_CLICD.[ICD]
	INNER JOIN
		[VINCI_IVC_CDS].[IVC_CDS].[CDS_Claim_Line] AS IVC_CL
		ON		IVC_CL.ClaimSID = IVC_CLICD.ClaimSID
			AND IVC_CL.[Line_Number] = IVC_CLICD.[Line_Number]
	WHERE
			(IVC_CL.Service_End_Date >= CAST('1999-01-01' AS DATE) -- Enter Study Window Start Date Here
				OR IVC_CL.Service_End_Date IS NULL) -- Patients can be currently inpatient
		AND IVC_CL.Service_Start_Date >= CAST('10/01/1999' AS DATE) -- Only get records after the start of EHR Records
		AND IVC_CL.Service_Start_Date < CAST(GETDATE() AS DATE) -- Enter Study Window End Date Here	
		--AND LEFT(IVC_CL.Station_Number, 3) = 'XXX' -- This is Sta6a taking left 3 to match Sta3n
;
--	754153 Rows;		12m:14s



/*****************************************************
	Millennium ICD Diagnosis SOP; Updated: 6/09/2022
*****************************************************/

--	2.5		Look Up ICD Codes

SELECT DISTINCT
		NC.SourceIdentifier AS [ICD10 Code]
		,NC.SourceString AS [ICD10 Description]
	FROM 
		CDWWork2.NDimMill.Nomenclature AS NC
	WHERE 
		(	REPLACE(NC.SourceIdentifier, '.', '') LIKE 'G40%'  -- Enter ICD code here!, remove all periods from codes
		OR	REPLACE(NC.SourceIdentifier, '.', '') LIKE 'R404%'
		OR	REPLACE(NC.SourceIdentifier, '.', '') LIKE 'R56[1,9]%'
		)
		--AND	REPLACE(NC.SourceIdentifier, '.', '') NOT LIKE 'XXX%'
		AND NC.PrincipleType = 'Disease or Syndrome' 
		AND NC.SourceVocabulary = 'ICD-10-CM'
		AND NC.ActiveIndicator = 1
		AND NC.SourceString IS NOT NULL
	ORDER BY
		NC.SourceIdentifier
;
--	92 rows;		00m:01s



--	2.6		Create DIM Table for ICD Code

DROP TABLE IF EXISTS #MillDiagnosisSID_Epilepsy;

SELECT DISTINCT
		NC.NomenclatureSID
	INTO 
		#MillDiagnosisSID_Epilepsy
	FROM 
		CDWWork2.NDimMill.Nomenclature AS NC
	WHERE 
		(	REPLACE(NC.SourceIdentifier, '.', '') LIKE 'G40%'  -- Enter ICD code here!, remove all periods from codes
		OR	REPLACE(NC.SourceIdentifier, '.', '') LIKE 'R404%'
		OR	REPLACE(NC.SourceIdentifier, '.', '') LIKE 'R56[1,9]%'
		)
		--AND	REPLACE(NC.SourceIdentifier, '.', '') NOT LIKE 'XXX%'
		AND NC.PrincipleType = 'Disease or Syndrome' 
		AND NC.SourceVocabulary = 'ICD-10-CM'
		AND NC.ActiveIndicator = 1
;
--	122 rows;		00m:05s



--	2.7		Get patients with requested ICD Codes

DROP TABLE IF EXISTS #MillICDCohort;

;WITH CTE AS(
	SELECT DISTINCT
			COH.PatientICN
			--,COH.PersonSID
			,ENCR.EncounterSID
			,CHGI.ServiceDateTime AS DiagnosisDateTime
			,NMCT.NomenclatureSID
			,ENCR.EncounterTypeClass
			,ENCR.EncounterType
			,ROW_NUMBER() OVER (PARTITION BY ENCR.EncounterSID, CHGI.BillItemSID, CHGI.ServiceDateTime, CMOD.NomenclatureSID ORDER BY CHGI.ModifiedDateTime DESC, CHGI.ChargeItemSID) AS DataRowID
		FROM  
			#MillVistAAllIdentifiers AS COH 
		INNER JOIN 
			CDWWork2.[EncMill].[Encounter] AS ENCR 
			ON		ENCR.PersonSID = COH.PersonSID 
				AND ENCR.ActiveIndicator = 1
				AND GETDATE() BETWEEN ENCR.BeginEffectiveDateTime AND ENCR.EndEffectiveDateTime 
		INNER JOIN 
			CDWWork2.[BillingMill].[ChargeItem] AS CHGI 
			ON		CHGI.EncounterSID = ENCR.EncounterSID
				AND CHGI.ActiveIndicator = 1
				AND GETDATE() BETWEEN CHGI.BeginEffectiveDateTime AND CHGI.EndEffectiveDateTime
				AND CHGI.ProcessIndicator = 100 
				AND CHGI.ChargeTypeCodeValueSID = 1800253736 ---DEBIT
				AND CHGI.OffsetChargeItemSID < 1
		INNER JOIN 
			CDWWork2.BillingMill.ChargeModification AS CMOD
			ON		CMOD.ChargeItemSID = CHGI.ChargeItemSID
				AND CMOD.ActiveIndicator = 1
				AND GETDATE() BETWEEN CMOD.BeginEffectiveDateTime AND CMOD.EndEffectiveDateTime
				AND CMOD.Field2ID = '1'
				AND CMOD.ModificationTypeCodeValueSID = 1800253705  --BillCode
		INNER JOIN 
			#MillDiagnosisSID_Epilepsy AS NMCT 
			ON		NMCT.NomenclatureSID = CMOD.NomenclatureSID
		--  INNER JOIN --Uncomment out this line if need to limit stapa in the where clause for specific station
			--CDWWork2.[Mill].[VALocations] AS VALC 
			--ON		VALC.OrganizationNameSID = ENCR.OrganizationNameSID 
		WHERE 
				(CHGI.ServiceDateTime >= Cast('1999-01-01' AS DateTime2(0))  -- Enter time frame here!
			AND CHGI.ServiceDateTime < Cast(GetDate() AS DateTime2(0)))
			--AND VALC.STAPA = 'XXXXX'--Uncomment out this line if need to limit stapa in the where clause for specific station
			--AND ENCR.EncounterType NOT LIKE 'Community Care%' --Need uncommented if don't need community care data
)
, CTE2 AS(
	SELECT DISTINCT
			COH.PatientICN
			--,COH.PersonSID
			,ENCD.EncounterSID
			,COALESCE(ENCD.DiagnosisDateTime,ENCR.RegistrationDateTime) AS DiagnosisDateTime
			,ENCD.NomenclatureSID
			,ENCR.EncounterTypeClass
			,ENCR.EncounterType
		FROM 
			#MillVistAAllIdentifiers AS COH 
		INNER JOIN 
			CDWWork2.[EncMill].[Encounter] AS ENCR 
			ON 		ENCR.PersonSID = COH.PersonSID 
				AND	ENCR.ActiveIndicator = 1
				AND GETDATE() BETWEEN ENCR.BeginEffectiveDateTime AND ENCR.EndEffectiveDateTime 
				AND ENCR.EncounterTypeClassCodeValueSID <> 1800360264  ---PREADMIT
		INNER JOIN 
			CDWWork2.[EncMill].[EncounterDiagnosis]	AS ENCD 
			ON		ENCD.EncounterSID = ENCR.EncounterSID
				AND ENCD.ActiveIndicator = 1
				AND GETDATE() BETWEEN ENCD.BeginEffectiveDateTime AND ENCD.EndEffectiveDateTime
		INNER JOIN 
			#MillDiagnosisSID_Epilepsy AS NMCT 
			ON 		NMCT.NomenclatureSID = ENCD.NomenclatureSID
		--INNER JOIN --Uncomment out this line if need to limit stapa in the where clause for specific station
		--	CDWWork2.[Mill].[VALocations] AS VALC 
		--	ON 		VALC.OrganizationNameSID = ENCR.OrganizationNameSID 
		WHERE 
				(COALESCE(ENCD.DiagnosisDateTime,ENCR.RegistrationDateTime) >= Cast('1999-01-01' AS DateTime2(0))  -- Enter time frame here!
			AND COALESCE(ENCD.DiagnosisDateTime,ENCR.RegistrationDateTime) < Cast(GetDate() AS DateTime2(0)))
			--AND VALC.STAPA = 'XXXXX'--Uncomment out this line if need to limit stapa in the where clause for specific station
			--AND  ENCR.EncounterType NOT LIKE 'Community Care%' --Need uncommented out if don't need community care data
)
, CTE3 AS(
	SELECT 
			PatientICN
			--,PersonSID
			,EncounterSID
			,DiagnosisDateTime
			,CONVERT(Date,DiagnosisDateTime) AS DiagnosisDate
			,NomenclatureSID
			,EncounterTypeClass
			,EncounterType
		FROM
			CTE
		WHERE 
			DataRowID = 1
	UNION
	SELECT 
			PatientICN
			--,PersonSID
			,EncounterSID
			,DiagnosisDateTime
			,CONVERT(Date,DiagnosisDateTime) AS DiagnosisDate
			,NomenclatureSID
			,EncounterTypeClass
			,EncounterType
		FROM
			CTE2
)
,CTE4 AS(
	SELECT DISTINCT 
			PatientICN
			--,PersonSID
			,DiagnosisDateTime AS DxDateTime
			,EncounterTypeClass
			,EncounterType
			,ROW_NUMBER() OVER (PARTITION BY EncounterSID, NomenclatureSID, DiagnosisDate ORDER BY DiagnosisDateTime DESC) AS FinalDataRowID
		FROM
			CTE3
)
SELECT DISTINCT
		PatientICN
		--,PersonSID
		--,DxDateTime
		--,EncounterTypeClass -- For Inpatient (Inpatient and Observation) everything else is Outpatient
	INTO
		#MillICDCohort
	FROM
		CTE4
	WHERE
			FinalDataRowID = 1 
		AND EncounterType NOT IN ('History', 'Lifetime Pharmacy')
		
CREATE CLUSTERED COLUMNSTORE INDEX CCI ON #MillICDCohort		
;
--	2812 rows;		2m:50s



--	2.8		Combine VistA & Mill

DROP TABLE IF EXISTS #H8;
SELECT	PatientICN
INTO	#H8
FROM	#ICD_VistA
UNION
SELECT	PatientICN
FROM	#MillICDCohort
;
--	754575 rows;	:01s


--	Count distinct patients for Excel H8

SELECT COUNT(DISTINCT PatientICN) AS H8_Patient_Count FROM #H8
;
--	754575 DISTINCT H8 patients


--------------------------------------------------------------------------------------------------

--	3.1		Cohort Table Final Staging

--DROP TABLE IF EXISTS [VINCI_Services ].COHORT.Haneef_202402056D;

CREATE TABLE [VINCI_Services ].COHORT.Haneef_202402056D(
		[PatientICN] [varchar](50) NOT NULL
		,[CohortName] [varchar](20) NOT NULL)

INSERT INTO [VINCI_Services ].COHORT.Haneef_202402056D (PatientICN, CohortName)

SELECT DISTINCT
		PatientICN
		,Cast('Cohort'+CONVERT(varchar(8),Getdate(),112) AS Varchar(20)) AS CohortName
	FROM
		#H8;
;
--	754575 DISITNCT Patients;		00m:08s


CREATE CLUSTERED COLUMNSTORE INDEX CCI ON [VINCI_Services ].COHORT.Haneef_202402056D
;
-- 00m:04s



--	3.2		Check Cohort Table

SELECT	COUNT(Distinct PatientICN) AS Patient_Count, CohortName
FROM	[VINCI_Services ].COHORT.Haneef_202402056D
GROUP BY CohortName
--	Patient_Count	CohortName
--	754575			Cohort20240503



--	3.3		Cohort Description Table

--Drop Table If Exists [VINCI_Services ].COHORT.Haneef_202402056D_Description;

CREATE TABLE [VINCI_Services ].COHORT.Haneef_202402056D_Description(
			[CohortName] [varchar](20) NOT NULL
			,[CohortDescription] [varchar](4000) NOT NULL
			,[CohortDataSource] [varchar](50) NOT NULL)

INSERT INTO	[VINCI_Services ].COHORT.Haneef_202402056D_Description (CohortName, CohortDescription, CohortDataSource)

SELECT DISTINCT
		Cast('Cohort'+CONVERT(varchar(8),Getdate(),112) AS Varchar(20)) AS CohortName
		,'Distinct, real (non-test) Veterans diagnosed with specified Epilepsy ICD9 and ICD10 codes in '
		+ 'nationwide outpatient or inpatient or non-VA community care settings from 1999-01-01 through 2024-05-03. ' 
		AS CohortDescription
		,'VistA, Millennium' AS CohortDataSource
;
--	1 rows;		00m:00s



--	3.4		Check Cohort Description Table

SELECT * FROM [VINCI_Services ].COHORT.Haneef_202402056D_Description
--	CohortName			CohortDescription
--	Cohort20240503		Distinct, real (non-test) Veterans diagnosed with specified Epilepsy ICD9 and ICD10 codes in nationwide outpatient or inpatient or non-VA community care settings from 1999-01-01 through 2024-05-03. 


/*************************************** END ****************************************************/
