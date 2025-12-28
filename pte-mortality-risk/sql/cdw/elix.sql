DROP TABLE IF EXISTS #my_spatient
CREATE TABLE #my_spatient (
	PatientSID INT PRIMARY KEY,
	PatientICN VARCHAR(50),
    FirstDXDateTime DATETIME
)

INSERT INTO
	#my_spatient
SELECT
	spat.PatientSID,
	coh.PatientICN,
    coh.FirstDXDateTime
FROM
	[SCS_EEGUtil].[EEG].[rn_cohort2] coh
INNER JOIN
	[CDWWork].[SPatient].[SPatient] spat
	ON
	coh.PatientICN = spat.PatientICN

CREATE INDEX idxPatientICN
ON #my_spatient (PatientICN)

/*  THIS PROGRAM WILL DEFINE ELIXHAUSER VARIABLES FROM THE FOLLOWING SOURCES AND CREATE A FINAL DATASETs THAT INCLUDES DATES OF DX AND SOURCE OF DX

VA OUTPATIENT
	Outpat_Workload
	Outpat_VDiagnosis
VA INPATIENT
	Inpat_InpatientDiagnosis
	Inpat_Inpatient
FEE OUTPATIENT
	Fee_FeeServiceProvided
	Fee_FeeInitialTreatment
FEE INPATIENT
	Fee_FeeInpatInvoice
	Fee_FeeInpatInvoiceICDDiagnosis

						#ICDflag	= all outpatient visits in time frame with icd9/10 codes, 
	
						#ICDflag_IN	= all inpatient dxs in time frame with icd9/10 codes, 
	
						#ICDflag_FO	= all outpatient FEE visits in time frame with icd9/10 codes,
	
						#ICDflag_Fi	= all inpatient dxs in time frame with icd9/10 codes, and dates
	
	#FINAL_ELIX							= dx y/n in all datasources during time period

Congestive heart failure 
Cardiac arrhythmias
Valvular disease
Pulmonary circulation disorder
Peripheral vascular disorder
Hypertension, uncomplicated 
Hypertension, complicated 
Paralysis
Other neurological
Chronic pulmonary disease 
Diabetes w/o chronic complications
Diabetes w/ chronic complications 
Hypothyroidism 
Renal failure 
Liver disease 
Chronic Peptic ulcer disease (includes bleeding only if obstruction is also present) 
HIV and AIDS 
Lymphoma 
Metastatic cancer 
Solid tumor without metastasis 
Rheumatoid arthritis/collagen vascular diseases 
Coagulation deficiency 
Obesity
Weight loss 
Fluid and electrolyte disorders 
Blood loss anemia
Deficiency anemias 
Alcohol abuse 
Drug abuse 
Psychoses 
Depression 
	*/
USE [CDWWork]
GO



----PULLING ICD10 FIRST FROM ALL SOURCES, THEN ICD9
/* Step 0: Pull in diagnosis codes from va inpatient and va outpatient  in the year prior to separation*/
-- looking for outpatient ICD10 codes


drop table if exists #ICDvisits_o;

select 'VA OUTPAT' AS DATASOURCE, 
			s.PATIENTICN, s.patientSID, b.visitSID, b.sta3n, b.ICD10SID, d.icd10code, b.ICD9SID, F.icd9code, e.StopCode, e.StopCodeName, c.visitdatetime as dxdate
into #ICDvisits_o
from 	#my_spatient s 		
inner join CDWWork.[Outpat].[WorkloadVDiagnosis] b 
	on s.patientSID = b.patientSID
inner join CDWWork.[Outpat].[Workload] c 
	on s.patientSID = c.patientSID and b.visitSID = c.visitSID
LEFT join CDWWork.Dim.ICD10 as d 
	on b.ICD10SID=d.ICD10SID	
LEFT join CDWWork.Dim.ICD9 as F 
	on b.ICD9SID=F.ICD9SID
INNER join CDWWork.Dim.StopCode as e 
	on c.PrimaryStopCodeSID=e.StopCodeSID
WHERE DATEDIFF(year, c.VisitDateTime, s.FirstDXDateTime) BETWEEN 0 AND 5
-- where (c.visitdatetime between convert(datetime2(0), '1999-01-01') and  convert(datetime2(0), '2024-01-01'))

/* Step 1: Elixhauser Comorbidities */
drop table if exists #icdFlag;
select PATIENTICN, patientSID, visitSID, Sta3n, ICD10SID, ICD10code, ICD9SID, ICD9code, dxdate
	, CASE
	when SUBSTRING(ICD10code, 1, 5) in ('I09.9','I11.0','I13.0','I13.2','I25.5','I42.0','I42.5','I42.6','I42.7','I42.8','I42.9','P29.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I43','I50') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('425.4','425.5','425.7','425.8','425.9') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('428') then 1	
	when SUBSTRING(ICD9code, 1, 6) in ('398.91','402.01','402.11','402.91','404.01','404.03','404.11','404.13','404.91','404.93') then 1
	else 0 end as CHF /* Congestive heart failure */
	
	, CASE
	when SUBSTRING(ICD10code, 1, 5)  in ('I44.1','I44.2','I44.3','I45.6','I45.9','R00.0','R00.1','R00.8','T82.1','Z45.0','Z95.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I47','I48','I49') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('426.0','426.7','426.9','427.0','427.1','427.2','427.3','427.4','427.6','427.8','427.9','785.0','V45.0','V53.3') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('426.13','426.10','426.12', '996.01','996.04') then 1
	else 0 end as ARRHY /* Cardiac arrhythmias */
			
		
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('A52.0','I09.1','I09.8','Q23.0','Q23.1','Q23.2','Q23.3','Z95.2','Z95.4') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I05','I06','I07','I08','I34','I35','I36','I37','I38','I39') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('394','395','396','397','424') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('093.2','746.3','746.4','746.5','746.6','V42.2','V43.3') then 1
	else 0 end as VALVE /* Valvular disease */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I28.0','I28.8','I28.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I26','I27') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('415.0','415.1','417.0','417.8','417.9') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('416') then 1
	else 0 end as PULMCIRC /* Pulmonary circulation disorder */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I73.1','I73.8','I73.9','I77.1','I79.0','I79.2','K55.1','K55.8','K55.9','Z95.8','Z95.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I70','I71') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('440','441') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('093.0','437.3','443.1','443.2','443.8','443.9','447.1','557.1','557.9','V43.4') then 1
	else 0 end as PERIVASC /* Peripheral vascular disorder */

	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('I10') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('401') then 1
	else 0 end as HTN /* Hypertension, uncomplicated */
		
	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('I11','I12','I13','I15') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('402','403','404','405') then 1
	else 0 end as HTNCX /* Hypertension, complicated */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('G04.1','G11.4','G80.1','G80.2','G83.0','G83.1','G83.2','G83.3','G83.4','G83.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('G81','G82') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('342','343') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('334.1','344.0','344.1','344.2','344.3','344.4','344.5','344.6','344.9') then 1
	else 0 end as PARA /* Paralysis */
	


	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('G25.4','G25.5','G31.2','G31.8','G31.9','G93.1','G93.4','R47.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('G10','G11','G12','G13','G20','G21','G22','G32','G35','G36','G37','G41','R56','G40') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('331.9','332.0','332.1','333.4','333.5','336.2','348.1','348.3','784.3') then 1
	when  SUBSTRING(ICD9code, 1, 3)  in ('334','335','340','341','345') then 1
	when  SUBSTRING(ICD9code, 1, 6)  in ('333.92','780.3') then 1
	else 0 end as NEURO /* Other neurological */

	, CASE
	when SUBSTRING(ICD10code, 1, 5) in ('I27.8','I27.9','J68.4','J70.1','J70.3') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('J40','J41','J42','J43','J44','J45','J46','J47','J60','J61','J62','J63','J64','J65','J66','J67') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('490','491','492','493','494','495','496','500','501','502','503','504','505') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('416.8','416.9','506.4','508.1','508.8') then 1
	else 0 end as CHRNLUNG /* Chronic pulmonary disease */


	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E10.0','E10.1','E10.9','E11.0','E11.1','E11.9','E12.0','E12.1','E12.9','E13.0','E13.1','E13.9','E14.0','E14.1','E14.9') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('250.0','250.1','250.2','250.3') then 1
	else 0 end as DM /* Diabetes w/o chronic complications*/

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E10.2','E10.3','E10.4','E10.5','E10.6','E10.7','E10.8', 'E11.2','E11.3','E11.4','E11.5','E11.6','E11.7','E11.8','E12.2','E12.3','E12.4','E12.5','E12.6','E12.7','E12.8','E13.2','E13.3','E13.4','E13.5','E13.6','E13.7','E13.8','E14.2','E14.3','E14.4','E14.5','E14.6','E14.7','E14.8') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('250.4','250.5','250.6','250.7','250.8','250.9') then 1
	else 0 end as DMCX /* Diabetes w/ chronic complications */

/*STOP HERE*/
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E89.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('E00','E01','E02','E03') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('243','244') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('240.9','246.1','246.8') then 1
	else 0 end as HYPOTHY /* Hypothyroidism */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I12.0','I13.1','N25.0','Z49.0','Z49.1','Z49.2','Z94.0','Z99.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('N18','N19') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('V56','585','586') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('588.0','V42.0','V45.1') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('403.01','403.11','403.91','404.02','404.03','404.12','404.13','404.92','404.93') then 1
	else 0 end as RENLFAIL /* Renal failure */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I86.4','I98.2','K71.1','K71.3','K71.4','K71.5','K71.7','K76.0','K76.2','K76.3','K76.4''K76.5','K76.6','K76.7','K76.8','K76.9','Z94.4') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('B18','I85','K70','K72','K73','K74') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('570','571') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('070.6','070.9','456.0','456.1','456.2','572.2','572.3','572.4','572.8','573.3','573.4','573.8','573.9','V42.7') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('070.22','070.23','070.32','070.33','070.44','070.54') then 1
	else 0 end as LIVER /* Liver disease */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('K25.7','K25.9','K26.7','K26.9','K27.7','K27.9','K28.7','K28.9') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('531.7','531.9','532.7','532.9','533.7','533.9','534.7','534.9') then 1
	else 0 end as ULCER /* Chronic Peptic ulcer disease (includes bleeding only if obstruction is also present) */

	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('B20','B21','B22','B24') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('042','043','044') then 1
	else 0 end as AIDS /* HIV and AIDS */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('C90.0','C90.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('C81','C82','C83','C84','C85','C88','C96') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('200','201','202') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('203.0','238.6') then 1
	else 0 end as LYMPH /* Lymphoma */

	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('C77','C78','C79','C80') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('196','197','198','199') then 1
	else 0 end as METS /* Metastatic cancer */

	
	, CASE
	when SUBSTRING(ICD10code, 1, 3) in
	(
	'C00','C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','C11','C12','C13','C14','C15','C16','C17','C18',
	'C19','C20','C21','C22','C23','C24','C25','C26','C30','C31','C32','C34','C37','C38','C39','C40','C41','C43','C45',
	'C46','C47','C48','C49','C50','C51','C52','C53','C54','C55','C56','C57','C58','C60','C61','C62','C63','C64','C65',
	'C66','C67','C68','C69','C70','C71','C72','C73','C74','C75','C76','C97'
	) then 1
	when SUBSTRING(ICD9code, 1, 3) in ('140','141','142','143','144','145','146','147','148','149','150','151','152',
		                  '153','154','155','156','157','158','159','160','161','162','163','164','165','166','167',
		                  '168','169','170','171','172','174','175','176','177','178','179','180','181','182','183',
		                  '184','185','186','187','188','189','190','191','192','193','194','195') then 1
	else 0 end as TUMOR /* Solid tumor without metastasis */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('L94.0','L94.1','L94.3','M12.0','M12.3','M31.0','M31.1','M31.2','M31.3','M46.1','M46.8','M46.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('M05','M06','M08','M30','M32','M33','M34','M35','M45') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('446','714','720','725') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('701.0','710.0','710.1','710.2','710.3','710.4','710.8','710.9','711.2','719.3','728.5') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('728.89','729.30') then 1
	else 0 end as ARTH /* Rheumatoid arthritis/collagen vascular diseases */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('D69.1','D69.3','D69.4','D69.5','D69.6') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('D65','D66','D67','D68') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('286') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('287.1','287.3','287.4','287.5') then 1
	else 0 end as COAG /* Coagulation deficiency */
	
	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('E66') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('278.0') then 1
	else 0 end as OBESE /* Obesity */
	

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('R63.4') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('E40','E41','E42','E43','E44','E45','E46','R64') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('260','261','262','263') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('783.2','799.4') then 1
	else 0 end as WGHTLOSS /* Weight loss */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E22.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('E86','E87') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('276') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('253.6') then 1
	else 0 end as LYTES /* Fluid and electrolyte disorders */


	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('D50.0') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('280.0') then 1
	else 0 end as BLDLOSS /* Blood loss anemia */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('D50.8','D50.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('D51','D52','D53') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('280.1','280.8','280.9') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('281') then 1
	else 0 end as ANEMDEF /* Deficiency anemias */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('G62.1','I42.6','K29.2','K70.0','K70.3','K70.9','Z50.2','Z71.4','Z72.1') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F10','E52','T51') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('265.2','291.1','291.2','291.3','291.5','291.8','291.9','303.0','303.9','305.0',
		'357.5','425.5','535.3','571.0','571.1','571.2','571.3','V11.3') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('980') then 1
	else 0 end as ALCOHOL /* Alcohol abuse */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('Z71.5','Z72.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F11','F12','F13','F14','F15','F16','F18','F19') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('292','304') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('305.2','305.3','305.4','305.5','305.6','305.7','305.8','305.9') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('V65.42') then 1
	else 0 end as DRUG /* Drug abuse */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('F30.2','F31.2','F31.5') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F20','F22','F23','F24','F25','F28','F29') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('293.8') then 1
	when  SUBSTRING(ICD9code, 1, 3)  in ('295','297','298') then 1
	when  SUBSTRING(ICD9code, 1, 6)  in ('296.04','296.14','296.44','296.54') then 1
	else 0 end as PSYCH /* Psychoses */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('F20.4','F31.3','F31.4','F31.5','F34.1','F41.2','F43.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F32','F33') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('309','311') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('296.2','296.3','296.5','300.4') then 1
	else 0 end as DEPRESS /* Depression */

	
into #ICDflag
from #ICDvisits_o;


drop table if exists #ICDvisits_in;
select 'VA INPAT' AS DATASOURCE, s.PATIENTICN, s.patientSID, b.InpatientSID, b.sta3n, b.ICD10SID, d.icd10code, b.ICD9SID, F.icd9code,
				C.AdmitWardLocationSID
				,Y.SpecialtySID
				,Y.SpecialtyPrintName
				,Y.Specialty
				,Y.BedSectionName
				,Y.PTFCode as BedSection
				,c.DischargeDateTime  as dxdate
into #ICDvisits_in
from 	#my_spatient s 		
inner join  [CDWWork].Inpat.InpatientDiagnosis b 
	on s.patientSID = b.patientSID
inner join [CDWWork].[Inpat].[Inpatient] c 
	on s.patientSID = c.patientSID and b.InpatientSID = c.InpatientSID
LEFT join CDWWork.Dim.ICD10 as d 
	on b.ICD10SID=d.ICD10SID

LEFT join CDWWork.Dim.ICD9 as F 
	on b.ICD9SID=F.ICD9SID
INNER JOIN CDWWork.Dim.WardLocation AS X ON C.AdmitWardLocationSID=X.WardLocationSID
INNER JOIN CDWWork.Dim.Specialty AS Y ON X.SpecialtySID=Y.SpecialtySID
WHERE DATEDIFF(year, c.DischargeDateTime, s.FirstDXDateTime) BETWEEN 0 AND 5
-- where (c.DischargeDateTime between convert(datetime2(0), '1999-01-01') and  convert(datetime2(0), '2024-01-01'))

/* Step 1: Elixhauser Comorbidities */
drop table if exists #icdFlag_in;
select PATIENTICN, patientSID, InpatientSID, Sta3n, ICD10SID, ICD10code, ICD9SID, ICD9code, dxdate
		, CASE
	when SUBSTRING(ICD10code, 1, 5) in ('I09.9','I11.0','I13.0','I13.2','I25.5','I42.0','I42.5','I42.6','I42.7','I42.8','I42.9','P29.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I43','I50') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('425.4','425.5','425.7','425.8','425.9') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('428') then 1	
	when SUBSTRING(ICD9code, 1, 6) in ('398.91','402.01','402.11','402.91','404.01','404.03','404.11','404.13','404.91','404.93') then 1
	else 0 end as CHF /* Congestive heart failure */
	
	, CASE
	when SUBSTRING(ICD10code, 1, 5)  in ('I44.1','I44.2','I44.3','I45.6','I45.9','R00.0','R00.1','R00.8','T82.1','Z45.0','Z95.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I47','I48','I49') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('426.0','426.7','426.9','427.0','427.1','427.2','427.3','427.4','427.6','427.8','427.9','785.0','V45.0','V53.3') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('426.13','426.10','426.12', '996.01','996.04') then 1
	else 0 end as ARRHY /* Cardiac arrhythmias */
			
		
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('A52.0','I09.1','I09.8','Q23.0','Q23.1','Q23.2','Q23.3','Z95.2','Z95.4') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I05','I06','I07','I08','I34','I35','I36','I37','I38','I39') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('394','395','396','397','424') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('093.2','746.3','746.4','746.5','746.6','V42.2','V43.3') then 1
	else 0 end as VALVE /* Valvular disease */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I28.0','I28.8','I28.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I26','I27') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('415.0','415.1','417.0','417.8','417.9') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('416') then 1
	else 0 end as PULMCIRC /* Pulmonary circulation disorder */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I73.1','I73.8','I73.9','I77.1','I79.0','I79.2','K55.1','K55.8','K55.9','Z95.8','Z95.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I70','I71') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('440','441') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('093.0','437.3','443.1','443.2','443.8','443.9','447.1','557.1','557.9','V43.4') then 1
	else 0 end as PERIVASC /* Peripheral vascular disorder */

	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('I10') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('401') then 1
	else 0 end as HTN /* Hypertension, uncomplicated */
		
	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('I11','I12','I13','I15') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('402','403','404','405') then 1
	else 0 end as HTNCX /* Hypertension, complicated */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('G04.1','G11.4','G80.1','G80.2','G83.0','G83.1','G83.2','G83.3','G83.4','G83.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('G81','G82') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('342','343') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('334.1','344.0','344.1','344.2','344.3','344.4','344.5','344.6','344.9') then 1
	else 0 end as PARA /* Paralysis */
	


	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('G25.4','G25.5','G31.2','G31.8','G31.9','G93.1','G93.4','R47.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('G10','G11','G12','G13','G20','G21','G22','G32','G35','G36','G37','G41','R56','G40') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('331.9','332.0','332.1','333.4','333.5','336.2','348.1','348.3','784.3') then 1
	when  SUBSTRING(ICD9code, 1, 3)  in ('334','335','340','341','345') then 1
	when  SUBSTRING(ICD9code, 1, 6)  in ('333.92','780.3') then 1
	else 0 end as NEURO /* Other neurological */

	, CASE
	when SUBSTRING(ICD10code, 1, 5) in ('I27.8','I27.9','J68.4','J70.1','J70.3') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('J40','J41','J42','J43','J44','J45','J46','J47','J60','J61','J62','J63','J64','J65','J66','J67') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('490','491','492','493','494','495','496','500','501','502','503','504','505') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('416.8','416.9','506.4','508.1','508.8') then 1
	else 0 end as CHRNLUNG /* Chronic pulmonary disease */


	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E10.0','E10.1','E10.9','E11.0','E11.1','E11.9','E12.0','E12.1','E12.9','E13.0','E13.1','E13.9','E14.0','E14.1','E14.9') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('250.0','250.1','250.2','250.3') then 1
	else 0 end as DM /* Diabetes w/o chronic complications*/

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E10.2','E10.3','E10.4','E10.5','E10.6','E10.7','E10.8', 'E11.2','E11.3','E11.4','E11.5','E11.6','E11.7','E11.8','E12.2','E12.3','E12.4','E12.5','E12.6','E12.7','E12.8','E13.2','E13.3','E13.4','E13.5','E13.6','E13.7','E13.8','E14.2','E14.3','E14.4','E14.5','E14.6','E14.7','E14.8') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('250.4','250.5','250.6','250.7','250.8','250.9') then 1
	else 0 end as DMCX /* Diabetes w/ chronic complications */

/*STOP HERE*/
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E89.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('E00','E01','E02','E03') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('243','244') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('240.9','246.1','246.8') then 1
	else 0 end as HYPOTHY /* Hypothyroidism */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I12.0','I13.1','N25.0','Z49.0','Z49.1','Z49.2','Z94.0','Z99.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('N18','N19') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('V56','585','586') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('588.0','V42.0','V45.1') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('403.01','403.11','403.91','404.02','404.03','404.12','404.13','404.92','404.93') then 1
	else 0 end as RENLFAIL /* Renal failure */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I86.4','I98.2','K71.1','K71.3','K71.4','K71.5','K71.7','K76.0','K76.2','K76.3','K76.4''K76.5','K76.6','K76.7','K76.8','K76.9','Z94.4') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('B18','I85','K70','K72','K73','K74') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('570','571') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('070.6','070.9','456.0','456.1','456.2','572.2','572.3','572.4','572.8','573.3','573.4','573.8','573.9','V42.7') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('070.22','070.23','070.32','070.33','070.44','070.54') then 1
	else 0 end as LIVER /* Liver disease */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('K25.7','K25.9','K26.7','K26.9','K27.7','K27.9','K28.7','K28.9') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('531.7','531.9','532.7','532.9','533.7','533.9','534.7','534.9') then 1
	else 0 end as ULCER /* Chronic Peptic ulcer disease (includes bleeding only if obstruction is also present) */

	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('B20','B21','B22','B24') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('042','043','044') then 1
	else 0 end as AIDS /* HIV and AIDS */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('C90.0','C90.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('C81','C82','C83','C84','C85','C88','C96') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('200','201','202') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('203.0','238.6') then 1
	else 0 end as LYMPH /* Lymphoma */

	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('C77','C78','C79','C80') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('196','197','198','199') then 1
	else 0 end as METS /* Metastatic cancer */

	
	, CASE
	when SUBSTRING(ICD10code, 1, 3) in
	(
	'C00','C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','C11','C12','C13','C14','C15','C16','C17','C18',
	'C19','C20','C21','C22','C23','C24','C25','C26','C30','C31','C32','C34','C37','C38','C39','C40','C41','C43','C45',
	'C46','C47','C48','C49','C50','C51','C52','C53','C54','C55','C56','C57','C58','C60','C61','C62','C63','C64','C65',
	'C66','C67','C68','C69','C70','C71','C72','C73','C74','C75','C76','C97'
	) then 1
	when SUBSTRING(ICD9code, 1, 3) in ('140','141','142','143','144','145','146','147','148','149','150','151','152',
		                  '153','154','155','156','157','158','159','160','161','162','163','164','165','166','167',
		                  '168','169','170','171','172','174','175','176','177','178','179','180','181','182','183',
		                  '184','185','186','187','188','189','190','191','192','193','194','195') then 1
	else 0 end as TUMOR /* Solid tumor without metastasis */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('L94.0','L94.1','L94.3','M12.0','M12.3','M31.0','M31.1','M31.2','M31.3','M46.1','M46.8','M46.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('M05','M06','M08','M30','M32','M33','M34','M35','M45') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('446','714','720','725') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('701.0','710.0','710.1','710.2','710.3','710.4','710.8','710.9','711.2','719.3','728.5') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('728.89','729.30') then 1
	else 0 end as ARTH /* Rheumatoid arthritis/collagen vascular diseases */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('D69.1','D69.3','D69.4','D69.5','D69.6') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('D65','D66','D67','D68') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('286') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('287.1','287.3','287.4','287.5') then 1
	else 0 end as COAG /* Coagulation deficiency */
	
	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('E66') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('278.0') then 1
	else 0 end as OBESE /* Obesity */
	

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('R63.4') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('E40','E41','E42','E43','E44','E45','E46','R64') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('260','261','262','263') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('783.2','799.4') then 1
	else 0 end as WGHTLOSS /* Weight loss */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E22.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('E86','E87') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('276') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('253.6') then 1
	else 0 end as LYTES /* Fluid and electrolyte disorders */


	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('D50.0') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('280.0') then 1
	else 0 end as BLDLOSS /* Blood loss anemia */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('D50.8','D50.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('D51','D52','D53') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('280.1','280.8','280.9') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('281') then 1
	else 0 end as ANEMDEF /* Deficiency anemias */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('G62.1','I42.6','K29.2','K70.0','K70.3','K70.9','Z50.2','Z71.4','Z72.1') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F10','E52','T51') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('265.2','291.1','291.2','291.3','291.5','291.8','291.9','303.0','303.9','305.0',
		'357.5','425.5','535.3','571.0','571.1','571.2','571.3','V11.3') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('980') then 1
	else 0 end as ALCOHOL /* Alcohol abuse */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('Z71.5','Z72.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F11','F12','F13','F14','F15','F16','F18','F19') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('292','304') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('305.2','305.3','305.4','305.5','305.6','305.7','305.8','305.9') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('V65.42') then 1
	else 0 end as DRUG /* Drug abuse */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('F30.2','F31.2','F31.5') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F20','F22','F23','F24','F25','F28','F29') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('293.8') then 1
	when  SUBSTRING(ICD9code, 1, 3)  in ('295','297','298') then 1
	when  SUBSTRING(ICD9code, 1, 6)  in ('296.04','296.14','296.44','296.54') then 1
	else 0 end as PSYCH /* Psychoses */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('F20.4','F31.3','F31.4','F31.5','F34.1','F41.2','F43.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F32','F33') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('309','311') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('296.2','296.3','296.5','300.4') then 1
	else 0 end as DEPRESS /* Depression */

into #ICDflag_in
from #ICDvisits_in;
	
	/*COLLECTING ICD10 FROM FEE INPATIENT AND OUTPATIENT DATA*/

drop table if exists #ICDvisits_FO;
select 'FEE OUTPAT' AS DATASOURCE
				, s.patienticn
				, s.patientSID
				, FIT.FeeInitialTreatmentSID
				, FSP.ICD10SID
				, d.icd10code
				, FSP.ICD9SID
				, F.icd9code
				, FSP.Sta3n
				, PS.IBPlaceOfService 
				, PS.IBPlaceOfServiceCode
				, FIT.InitialTreatmentDateTime as dxdate
into #ICDvisits_FO
from 	#my_spatient s 		
inner join [CDWWork].Fee.FeeServiceProvided  FSP 
	on s.patientSID = FSP.patientSID
inner join [CDWWork].Fee.FeeInitialTreatment FIT 
	on s.patientSID = FIT.patientSID and FSP.FeeInitialTreatmentSID = FIT.FeeInitialTreatmentSID
inner join CDWWork.Dim.IBPlaceOfService as PS 
	on FSP.IBPlaceOfServiceSID=PS.IBPlaceOfServiceSID

LEFT join CDWWork.Dim.ICD10 as d 
	on FSP.ICD10SID=d.ICD10SID

LEFT join CDWWork.Dim.ICD9 as F 
	on FSP.ICD9SID=F.ICD9SID

WHERE DATEDIFF(year, fit.InitialTreatmentDateTime, s.FirstDXDateTime) BETWEEN 0 AND 5
-- where (FIT.InitialTreatmentDateTime between convert(datetime2(0), '1999-01-01') and  convert(datetime2(0), '2024-01-01'))
	
	
	--Select top 100 *from #ICDvisits_FO

/* Step 1: Elixhauser Comorbidities */
drop table if exists #icdFlag_FO;
select patienticn, patientSID, FeeInitialTreatmentSID,  ICD10SID, ICD10code, ICD9SID, ICD9code, dxdate
		, CASE
	when SUBSTRING(ICD10code, 1, 5) in ('I09.9','I11.0','I13.0','I13.2','I25.5','I42.0','I42.5','I42.6','I42.7','I42.8','I42.9','P29.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I43','I50') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('425.4','425.5','425.7','425.8','425.9') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('428') then 1	
	when SUBSTRING(ICD9code, 1, 6) in ('398.91','402.01','402.11','402.91','404.01','404.03','404.11','404.13','404.91','404.93') then 1
	else 0 end as CHF /* Congestive heart failure */
	
	, CASE
	when SUBSTRING(ICD10code, 1, 5)  in ('I44.1','I44.2','I44.3','I45.6','I45.9','R00.0','R00.1','R00.8','T82.1','Z45.0','Z95.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I47','I48','I49') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('426.0','426.7','426.9','427.0','427.1','427.2','427.3','427.4','427.6','427.8','427.9','785.0','V45.0','V53.3') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('426.13','426.10','426.12', '996.01','996.04') then 1
	else 0 end as ARRHY /* Cardiac arrhythmias */
			
		
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('A52.0','I09.1','I09.8','Q23.0','Q23.1','Q23.2','Q23.3','Z95.2','Z95.4') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I05','I06','I07','I08','I34','I35','I36','I37','I38','I39') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('394','395','396','397','424') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('093.2','746.3','746.4','746.5','746.6','V42.2','V43.3') then 1
	else 0 end as VALVE /* Valvular disease */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I28.0','I28.8','I28.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I26','I27') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('415.0','415.1','417.0','417.8','417.9') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('416') then 1
	else 0 end as PULMCIRC /* Pulmonary circulation disorder */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I73.1','I73.8','I73.9','I77.1','I79.0','I79.2','K55.1','K55.8','K55.9','Z95.8','Z95.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I70','I71') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('440','441') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('093.0','437.3','443.1','443.2','443.8','443.9','447.1','557.1','557.9','V43.4') then 1
	else 0 end as PERIVASC /* Peripheral vascular disorder */

	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('I10') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('401') then 1
	else 0 end as HTN /* Hypertension, uncomplicated */
		
	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('I11','I12','I13','I15') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('402','403','404','405') then 1
	else 0 end as HTNCX /* Hypertension, complicated */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('G04.1','G11.4','G80.1','G80.2','G83.0','G83.1','G83.2','G83.3','G83.4','G83.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('G81','G82') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('342','343') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('334.1','344.0','344.1','344.2','344.3','344.4','344.5','344.6','344.9') then 1
	else 0 end as PARA /* Paralysis */
	


	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('G25.4','G25.5','G31.2','G31.8','G31.9','G93.1','G93.4','R47.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('G10','G11','G12','G13','G20','G21','G22','G32','G35','G36','G37','G41','R56','G40') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('331.9','332.0','332.1','333.4','333.5','336.2','348.1','348.3','784.3') then 1
	when  SUBSTRING(ICD9code, 1, 3)  in ('334','335','340','341','345') then 1
	when  SUBSTRING(ICD9code, 1, 6)  in ('333.92','780.3') then 1
	else 0 end as NEURO /* Other neurological */

	, CASE
	when SUBSTRING(ICD10code, 1, 5) in ('I27.8','I27.9','J68.4','J70.1','J70.3') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('J40','J41','J42','J43','J44','J45','J46','J47','J60','J61','J62','J63','J64','J65','J66','J67') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('490','491','492','493','494','495','496','500','501','502','503','504','505') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('416.8','416.9','506.4','508.1','508.8') then 1
	else 0 end as CHRNLUNG /* Chronic pulmonary disease */


	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E10.0','E10.1','E10.9','E11.0','E11.1','E11.9','E12.0','E12.1','E12.9','E13.0','E13.1','E13.9','E14.0','E14.1','E14.9') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('250.0','250.1','250.2','250.3') then 1
	else 0 end as DM /* Diabetes w/o chronic complications*/

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E10.2','E10.3','E10.4','E10.5','E10.6','E10.7','E10.8', 'E11.2','E11.3','E11.4','E11.5','E11.6','E11.7','E11.8','E12.2','E12.3','E12.4','E12.5','E12.6','E12.7','E12.8','E13.2','E13.3','E13.4','E13.5','E13.6','E13.7','E13.8','E14.2','E14.3','E14.4','E14.5','E14.6','E14.7','E14.8') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('250.4','250.5','250.6','250.7','250.8','250.9') then 1
	else 0 end as DMCX /* Diabetes w/ chronic complications */

/*STOP HERE*/
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E89.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('E00','E01','E02','E03') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('243','244') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('240.9','246.1','246.8') then 1
	else 0 end as HYPOTHY /* Hypothyroidism */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I12.0','I13.1','N25.0','Z49.0','Z49.1','Z49.2','Z94.0','Z99.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('N18','N19') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('V56','585','586') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('588.0','V42.0','V45.1') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('403.01','403.11','403.91','404.02','404.03','404.12','404.13','404.92','404.93') then 1
	else 0 end as RENLFAIL /* Renal failure */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I86.4','I98.2','K71.1','K71.3','K71.4','K71.5','K71.7','K76.0','K76.2','K76.3','K76.4''K76.5','K76.6','K76.7','K76.8','K76.9','Z94.4') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('B18','I85','K70','K72','K73','K74') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('570','571') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('070.6','070.9','456.0','456.1','456.2','572.2','572.3','572.4','572.8','573.3','573.4','573.8','573.9','V42.7') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('070.22','070.23','070.32','070.33','070.44','070.54') then 1
	else 0 end as LIVER /* Liver disease */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('K25.7','K25.9','K26.7','K26.9','K27.7','K27.9','K28.7','K28.9') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('531.7','531.9','532.7','532.9','533.7','533.9','534.7','534.9') then 1
	else 0 end as ULCER /* Chronic Peptic ulcer disease (includes bleeding only if obstruction is also present) */

	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('B20','B21','B22','B24') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('042','043','044') then 1
	else 0 end as AIDS /* HIV and AIDS */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('C90.0','C90.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('C81','C82','C83','C84','C85','C88','C96') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('200','201','202') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('203.0','238.6') then 1
	else 0 end as LYMPH /* Lymphoma */

	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('C77','C78','C79','C80') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('196','197','198','199') then 1
	else 0 end as METS /* Metastatic cancer */

	
	, CASE
	when SUBSTRING(ICD10code, 1, 3) in
	(
	'C00','C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','C11','C12','C13','C14','C15','C16','C17','C18',
	'C19','C20','C21','C22','C23','C24','C25','C26','C30','C31','C32','C34','C37','C38','C39','C40','C41','C43','C45',
	'C46','C47','C48','C49','C50','C51','C52','C53','C54','C55','C56','C57','C58','C60','C61','C62','C63','C64','C65',
	'C66','C67','C68','C69','C70','C71','C72','C73','C74','C75','C76','C97'
	) then 1
	when SUBSTRING(ICD9code, 1, 3) in ('140','141','142','143','144','145','146','147','148','149','150','151','152',
		                  '153','154','155','156','157','158','159','160','161','162','163','164','165','166','167',
		                  '168','169','170','171','172','174','175','176','177','178','179','180','181','182','183',
		                  '184','185','186','187','188','189','190','191','192','193','194','195') then 1
	else 0 end as TUMOR /* Solid tumor without metastasis */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('L94.0','L94.1','L94.3','M12.0','M12.3','M31.0','M31.1','M31.2','M31.3','M46.1','M46.8','M46.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('M05','M06','M08','M30','M32','M33','M34','M35','M45') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('446','714','720','725') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('701.0','710.0','710.1','710.2','710.3','710.4','710.8','710.9','711.2','719.3','728.5') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('728.89','729.30') then 1
	else 0 end as ARTH /* Rheumatoid arthritis/collagen vascular diseases */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('D69.1','D69.3','D69.4','D69.5','D69.6') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('D65','D66','D67','D68') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('286') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('287.1','287.3','287.4','287.5') then 1
	else 0 end as COAG /* Coagulation deficiency */
	
	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('E66') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('278.0') then 1
	else 0 end as OBESE /* Obesity */
	

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('R63.4') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('E40','E41','E42','E43','E44','E45','E46','R64') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('260','261','262','263') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('783.2','799.4') then 1
	else 0 end as WGHTLOSS /* Weight loss */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E22.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('E86','E87') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('276') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('253.6') then 1
	else 0 end as LYTES /* Fluid and electrolyte disorders */


	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('D50.0') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('280.0') then 1
	else 0 end as BLDLOSS /* Blood loss anemia */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('D50.8','D50.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('D51','D52','D53') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('280.1','280.8','280.9') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('281') then 1
	else 0 end as ANEMDEF /* Deficiency anemias */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('G62.1','I42.6','K29.2','K70.0','K70.3','K70.9','Z50.2','Z71.4','Z72.1') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F10','E52','T51') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('265.2','291.1','291.2','291.3','291.5','291.8','291.9','303.0','303.9','305.0',
		'357.5','425.5','535.3','571.0','571.1','571.2','571.3','V11.3') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('980') then 1
	else 0 end as ALCOHOL /* Alcohol abuse */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('Z71.5','Z72.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F11','F12','F13','F14','F15','F16','F18','F19') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('292','304') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('305.2','305.3','305.4','305.5','305.6','305.7','305.8','305.9') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('V65.42') then 1
	else 0 end as DRUG /* Drug abuse */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('F30.2','F31.2','F31.5') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F20','F22','F23','F24','F25','F28','F29') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('293.8') then 1
	when  SUBSTRING(ICD9code, 1, 3)  in ('295','297','298') then 1
	when  SUBSTRING(ICD9code, 1, 6)  in ('296.04','296.14','296.44','296.54') then 1
	else 0 end as PSYCH /* Psychoses */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('F20.4','F31.3','F31.4','F31.5','F34.1','F41.2','F43.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F32','F33') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('309','311') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('296.2','296.3','296.5','300.4') then 1
	else 0 end as DEPRESS /* Depression */

into #ICDflag_FO
from #ICDvisits_FO;

	--INPATIENT FEE

drop table if exists #ICDvisits_FI;
select 'FEE IN' AS DATASOURCE
				, s.patienticn
				, s.patientSID
				, FINV.FeeInpatInvoiceSID
				, FICD.ICD10SID
				, d.icd10code
				, FICD.ICD9SID
				, F.icd9code
				,(CASE WHEN TreatmentToDateTime < GETDATE() THEN FINV.TreatmentToDateTime
			  ELSE FINV.TreatmentFromDateTime END ) AS DxDate 
into #ICDvisits_FI
from 	#my_spatient s
	

inner join [CDWWork].Fee.FeeInpatInvoice  FINV 
	on s.patientSID = FINV.patientSID


inner join [CDWWork].Fee.FeeInpatInvoiceICDDiagnosis FICD 

ON 
					FICD.FeeInpatInvoiceSID = FINV.FeeInpatInvoiceSID

LEFT join CDWWork.Dim.ICD10 as d 
	on FICD.ICD10SID=d.ICD10SID

LEFT join CDWWork.Dim.ICD9 as F 
	on FICD.ICD9SID=F.ICD9SID

WHERE
    DATEDIFF(year, FINV.TreatmentToDateTime, s.FirstDXDateTime) BETWEEN 0 AND 5
    OR
    DATEDIFF(year, FINV.TreatmentFromDateTime, s.FirstDXDateTime) BETWEEN 0 AND 5

			-- WHERE 
			-- 	FINV.TreatmentToDateTime >= convert(datetime2(0), '1999-01-01') AND 
			-- 	FINV.TreatmentToDateTime< convert(datetime2(0), '2024-03-01')
			-- 		OR
			-- 	FINV.TreatmentFromDateTime >= convert(datetime2(0), '1999-01-01') AND 
			-- 	FINV.TreatmentFromDateTime< convert(datetime2(0), '2024-03-01')
	
/* Step 1: Elixhauser Comorbidities */
drop table if exists #icdFlag_FI;
select patienticn, patientSID, FeeInpatInvoiceSID,  ICD10SID, ICD10code, ICD9SID, ICD9code, dxdate
		, CASE
	when SUBSTRING(ICD10code, 1, 5) in ('I09.9','I11.0','I13.0','I13.2','I25.5','I42.0','I42.5','I42.6','I42.7','I42.8','I42.9','P29.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I43','I50') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('425.4','425.5','425.7','425.8','425.9') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('428') then 1	
	when SUBSTRING(ICD9code, 1, 6) in ('398.91','402.01','402.11','402.91','404.01','404.03','404.11','404.13','404.91','404.93') then 1
	else 0 end as CHF /* Congestive heart failure */
	
	, CASE
	when SUBSTRING(ICD10code, 1, 5)  in ('I44.1','I44.2','I44.3','I45.6','I45.9','R00.0','R00.1','R00.8','T82.1','Z45.0','Z95.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I47','I48','I49') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('426.0','426.7','426.9','427.0','427.1','427.2','427.3','427.4','427.6','427.8','427.9','785.0','V45.0','V53.3') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('426.13','426.10','426.12', '996.01','996.04') then 1
	else 0 end as ARRHY /* Cardiac arrhythmias */
			
		
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('A52.0','I09.1','I09.8','Q23.0','Q23.1','Q23.2','Q23.3','Z95.2','Z95.4') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I05','I06','I07','I08','I34','I35','I36','I37','I38','I39') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('394','395','396','397','424') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('093.2','746.3','746.4','746.5','746.6','V42.2','V43.3') then 1
	else 0 end as VALVE /* Valvular disease */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I28.0','I28.8','I28.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I26','I27') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('415.0','415.1','417.0','417.8','417.9') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('416') then 1
	else 0 end as PULMCIRC /* Pulmonary circulation disorder */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I73.1','I73.8','I73.9','I77.1','I79.0','I79.2','K55.1','K55.8','K55.9','Z95.8','Z95.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('I70','I71') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('440','441') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('093.0','437.3','443.1','443.2','443.8','443.9','447.1','557.1','557.9','V43.4') then 1
	else 0 end as PERIVASC /* Peripheral vascular disorder */

	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('I10') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('401') then 1
	else 0 end as HTN /* Hypertension, uncomplicated */
		
	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('I11','I12','I13','I15') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('402','403','404','405') then 1
	else 0 end as HTNCX /* Hypertension, complicated */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('G04.1','G11.4','G80.1','G80.2','G83.0','G83.1','G83.2','G83.3','G83.4','G83.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('G81','G82') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('342','343') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('334.1','344.0','344.1','344.2','344.3','344.4','344.5','344.6','344.9') then 1
	else 0 end as PARA /* Paralysis */
	


	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('G25.4','G25.5','G31.2','G31.8','G31.9','G93.1','G93.4','R47.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('G10','G11','G12','G13','G20','G21','G22','G32','G35','G36','G37','G41','R56','G40') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('331.9','332.0','332.1','333.4','333.5','336.2','348.1','348.3','784.3') then 1
	when  SUBSTRING(ICD9code, 1, 3)  in ('334','335','340','341','345') then 1
	when  SUBSTRING(ICD9code, 1, 6)  in ('333.92','780.3') then 1
	else 0 end as NEURO /* Other neurological */

	, CASE
	when SUBSTRING(ICD10code, 1, 5) in ('I27.8','I27.9','J68.4','J70.1','J70.3') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('J40','J41','J42','J43','J44','J45','J46','J47','J60','J61','J62','J63','J64','J65','J66','J67') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('490','491','492','493','494','495','496','500','501','502','503','504','505') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('416.8','416.9','506.4','508.1','508.8') then 1
	else 0 end as CHRNLUNG /* Chronic pulmonary disease */


	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E10.0','E10.1','E10.9','E11.0','E11.1','E11.9','E12.0','E12.1','E12.9','E13.0','E13.1','E13.9','E14.0','E14.1','E14.9') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('250.0','250.1','250.2','250.3') then 1
	else 0 end as DM /* Diabetes w/o chronic complications*/

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E10.2','E10.3','E10.4','E10.5','E10.6','E10.7','E10.8', 'E11.2','E11.3','E11.4','E11.5','E11.6','E11.7','E11.8','E12.2','E12.3','E12.4','E12.5','E12.6','E12.7','E12.8','E13.2','E13.3','E13.4','E13.5','E13.6','E13.7','E13.8','E14.2','E14.3','E14.4','E14.5','E14.6','E14.7','E14.8') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('250.4','250.5','250.6','250.7','250.8','250.9') then 1
	else 0 end as DMCX /* Diabetes w/ chronic complications */

/*STOP HERE*/
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E89.0') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('E00','E01','E02','E03') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('243','244') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('240.9','246.1','246.8') then 1
	else 0 end as HYPOTHY /* Hypothyroidism */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I12.0','I13.1','N25.0','Z49.0','Z49.1','Z49.2','Z94.0','Z99.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('N18','N19') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('V56','585','586') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('588.0','V42.0','V45.1') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('403.01','403.11','403.91','404.02','404.03','404.12','404.13','404.92','404.93') then 1
	else 0 end as RENLFAIL /* Renal failure */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('I86.4','I98.2','K71.1','K71.3','K71.4','K71.5','K71.7','K76.0','K76.2','K76.3','K76.4''K76.5','K76.6','K76.7','K76.8','K76.9','Z94.4') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('B18','I85','K70','K72','K73','K74') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('570','571') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('070.6','070.9','456.0','456.1','456.2','572.2','572.3','572.4','572.8','573.3','573.4','573.8','573.9','V42.7') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('070.22','070.23','070.32','070.33','070.44','070.54') then 1
	else 0 end as LIVER /* Liver disease */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('K25.7','K25.9','K26.7','K26.9','K27.7','K27.9','K28.7','K28.9') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('531.7','531.9','532.7','532.9','533.7','533.9','534.7','534.9') then 1
	else 0 end as ULCER /* Chronic Peptic ulcer disease (includes bleeding only if obstruction is also present) */

	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('B20','B21','B22','B24') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('042','043','044') then 1
	else 0 end as AIDS /* HIV and AIDS */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('C90.0','C90.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('C81','C82','C83','C84','C85','C88','C96') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('200','201','202') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('203.0','238.6') then 1
	else 0 end as LYMPH /* Lymphoma */

	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('C77','C78','C79','C80') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('196','197','198','199') then 1
	else 0 end as METS /* Metastatic cancer */

	
	, CASE
	when SUBSTRING(ICD10code, 1, 3) in
	(
	'C00','C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','C11','C12','C13','C14','C15','C16','C17','C18',
	'C19','C20','C21','C22','C23','C24','C25','C26','C30','C31','C32','C34','C37','C38','C39','C40','C41','C43','C45',
	'C46','C47','C48','C49','C50','C51','C52','C53','C54','C55','C56','C57','C58','C60','C61','C62','C63','C64','C65',
	'C66','C67','C68','C69','C70','C71','C72','C73','C74','C75','C76','C97'
	) then 1
	when SUBSTRING(ICD9code, 1, 3) in ('140','141','142','143','144','145','146','147','148','149','150','151','152',
		                  '153','154','155','156','157','158','159','160','161','162','163','164','165','166','167',
		                  '168','169','170','171','172','174','175','176','177','178','179','180','181','182','183',
		                  '184','185','186','187','188','189','190','191','192','193','194','195') then 1
	else 0 end as TUMOR /* Solid tumor without metastasis */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('L94.0','L94.1','L94.3','M12.0','M12.3','M31.0','M31.1','M31.2','M31.3','M46.1','M46.8','M46.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('M05','M06','M08','M30','M32','M33','M34','M35','M45') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('446','714','720','725') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('701.0','710.0','710.1','710.2','710.3','710.4','710.8','710.9','711.2','719.3','728.5') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('728.89','729.30') then 1
	else 0 end as ARTH /* Rheumatoid arthritis/collagen vascular diseases */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('D69.1','D69.3','D69.4','D69.5','D69.6') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('D65','D66','D67','D68') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('286') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('287.1','287.3','287.4','287.5') then 1
	else 0 end as COAG /* Coagulation deficiency */
	
	, CASE
	when SUBSTRING(ICD10code, 1, 3) in ('E66') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('278.0') then 1
	else 0 end as OBESE /* Obesity */
	

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('R63.4') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('E40','E41','E42','E43','E44','E45','E46','R64') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('260','261','262','263') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('783.2','799.4') then 1
	else 0 end as WGHTLOSS /* Weight loss */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('E22.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('E86','E87') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('276') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('253.6') then 1
	else 0 end as LYTES /* Fluid and electrolyte disorders */


	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('D50.0') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('280.0') then 1
	else 0 end as BLDLOSS /* Blood loss anemia */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('D50.8','D50.9') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('D51','D52','D53') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('280.1','280.8','280.9') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('281') then 1
	else 0 end as ANEMDEF /* Deficiency anemias */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('G62.1','I42.6','K29.2','K70.0','K70.3','K70.9','Z50.2','Z71.4','Z72.1') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F10','E52','T51') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('265.2','291.1','291.2','291.3','291.5','291.8','291.9','303.0','303.9','305.0',
		'357.5','425.5','535.3','571.0','571.1','571.2','571.3','V11.3') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('980') then 1
	else 0 end as ALCOHOL /* Alcohol abuse */
	
	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('Z71.5','Z72.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F11','F12','F13','F14','F15','F16','F18','F19') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('292','304') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('305.2','305.3','305.4','305.5','305.6','305.7','305.8','305.9') then 1
	when SUBSTRING(ICD9code, 1, 6) in ('V65.42') then 1
	else 0 end as DRUG /* Drug abuse */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('F30.2','F31.2','F31.5') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F20','F22','F23','F24','F25','F28','F29') then 1
	when  SUBSTRING(ICD9code, 1, 5)  in ('293.8') then 1
	when  SUBSTRING(ICD9code, 1, 3)  in ('295','297','298') then 1
	when  SUBSTRING(ICD9code, 1, 6)  in ('296.04','296.14','296.44','296.54') then 1
	else 0 end as PSYCH /* Psychoses */

	, CASE
	when  SUBSTRING(ICD10code, 1, 5)  in ('F20.4','F31.3','F31.4','F31.5','F34.1','F41.2','F43.2') then 1
	when SUBSTRING(ICD10code, 1, 3) in ('F32','F33') then 1
	when SUBSTRING(ICD9code, 1, 3) in ('309','311') then 1
	when SUBSTRING(ICD9code, 1, 5) in ('296.2','296.3','296.5','300.4') then 1
	else 0 end as DEPRESS /* Depression */

into #ICDflag_FI
from #ICDvisits_FI;

  use [CDWWork]
go 
	
Drop Table If Exists #ALL_ELIX;
WITH CTE2 AS
(

			SELECT 'VA OUTPAT' AS DATASOURCE
					 ,PATIENTICN 
					,ICD10CODE 
					,ICD9CODE 
					,DXDATE
					,CHF
					,ARRHY
					,VALVE
					,PULMCIRC
					,PERIVASC
					,HTN
					,HTNCX
					,PARA
					,NEURO
					,CHRNLUNG
					,DM
					,DMCX
					,HYPOTHY
					,RENLFAIL
					,LIVER
					,ULCER
					,AIDS
					,LYMPH 
					,METS 
					,TUMOR 
					,ARTH
					,COAG 
					,OBESE
					,WGHTLOSS 
					,LYTES
					,BLDLOSS 
					,ANEMDEF 
					,ALCOHOL
					,DRUG
					,PSYCH 
					,DEPRESS 
				


			FROM 
					#ICDflag 
			   
	
	

	UNION

				SELECT  'VA INPAT' AS DATASOURCE
					,PATIENTICN 
					,ICD10CODE 
					,ICD9CODE 
					,DXDATE
					,CHF
					,ARRHY
					,VALVE
					,PULMCIRC
					,PERIVASC
					,HTN
					,HTNCX
					,PARA
					,NEURO
					,CHRNLUNG
					,DM
					,DMCX
					,HYPOTHY
					,RENLFAIL
					,LIVER
					,ULCER
					,AIDS
					,LYMPH 
					,METS 
					,TUMOR 
					,ARTH
					,COAG 
					,OBESE
					,WGHTLOSS 
					,LYTES
					,BLDLOSS 
					,ANEMDEF 
					,ALCOHOL
					,DRUG
					,PSYCH 
					,DEPRESS 
					

		FROM 
					#ICDflag_in




	UNION


			SELECT 'FEE OUT' AS DATASOURCE
					 ,PATIENTICN 
					,ICD10CODE 
					,ICD9CODE 
					,DXDATE
					,CHF
					,ARRHY
					,VALVE
					,PULMCIRC
					,PERIVASC
					,HTN
					,HTNCX
					,PARA
					,NEURO
					,CHRNLUNG
					,DM
					,DMCX
					,HYPOTHY
					,RENLFAIL
					,LIVER
					,ULCER
					,AIDS
					,LYMPH 
					,METS 
					,TUMOR 
					,ARTH
					,COAG 
					,OBESE
					,WGHTLOSS 
					,LYTES
					,BLDLOSS 
					,ANEMDEF 
					,ALCOHOL
					,DRUG
					,PSYCH 
					,DEPRESS 
					
					

			FROM 
						#ICDflag_FO
			


			UNION
			
		
			SELECT 'FEE IN' AS DATASOURCE
					,PATIENTICN 
					,ICD10CODE
					,ICD9CODE  
					,DXDATE
					,CHF
					,ARRHY
					,VALVE
					,PULMCIRC
					,PERIVASC
					,HTN
					,HTNCX
					,PARA
					,NEURO
					,CHRNLUNG
					,DM
					,DMCX
					,HYPOTHY
					,RENLFAIL
					,LIVER
					,ULCER
					,AIDS
					,LYMPH 
					,METS 
					,TUMOR 
					,ARTH
					,COAG 
					,OBESE
					,WGHTLOSS 
					,LYTES
					,BLDLOSS 
					,ANEMDEF 
					,ALCOHOL
					,DRUG
					,PSYCH 
					,DEPRESS 

					
			FROM 
						#ICDflag_Fi
			
					
)



SELECT
					DATASOURCE
					,PATIENTICN 
					,ICD10CODE 
					,ICD9CODE 
					,DXDATE
					,CHF
					,ARRHY
					,VALVE
					,PULMCIRC
					,PERIVASC
					,HTN
					,HTNCX
					,PARA
					,NEURO
					,CHRNLUNG
					,DM
					,DMCX
					,HYPOTHY
					,RENLFAIL
					,LIVER
					,ULCER
					,AIDS
					,LYMPH 
					,METS 
					,TUMOR 
					,ARTH
					,COAG 
					,OBESE
					,WGHTLOSS 
					,LYTES
					,BLDLOSS 
					,ANEMDEF 
					,ALCOHOL
					,DRUG
					,PSYCH 
					,DEPRESS 
					
INTO
		#ALL_ELIX
FROM
		CTE2;



--Get the ECI directly without importing into R
DROP TABLE IF EXISTS #ECI_FINAL;
WITH AggregatedElix AS (
	SELECT
		PatientICN,
		MAX(CHF) AS CHF,
		--MAX(ARRHY) AS ARRHY,
		MAX(PULMCIRC) AS PULMCIRC,
		MAX(PERIVASC) AS PERIVASC,
		MAX(HTN) AS HTN,
		MAX(HTNCX) AS HTNCX,
		MAX(PARA) AS PARA,
		MAX(NEURO) AS NEURO,
		MAX(CHRNLUNG) AS CHRNLUNG,
		MAX(DM) AS DM,
		MAX(DMCX) AS DMCX,
		MAX(HYPOTHY) AS HYPOTHY,
		MAX(RENLFAIL) AS RENLFAIL,
		MAX(LIVER) AS LIVER,
		MAX(ULCER) AS ULCER,
		MAX(AIDS) AS AIDS,
		MAX(LYMPH) AS LYMPH,
		MAX(METS) AS METS,
		MAX(TUMOR) AS TUMOR,
		MAX(ARTH) AS ARTH,
		MAX(COAG) AS COAG,
		MAX(OBESE) AS OBESE,
		MAX(WGHTLOSS) AS WGHTLOSS,
		MAX(LYTES) AS LYTES,
		MAX(BLDLOSS) AS BLDLOSS,
		MAX(ANEMDEF) AS ANEMDEF,
		MAX(ALCOHOL) AS ALCOHOL,
		MAX(DRUG) AS DRUG,
		MAX(PSYCH) AS PSYCH,
		MAX(DEPRESS) AS DEPRESS
	FROM #ALL_ELIX
	-- WHERE DXDATE < '2024-01-01'
	GROUP BY PATIENTICN
)
SELECT
	*,
	(
		CHF*9 +
		PULMCIRC*0 +
		PERIVASC*6 +
		HTN*3 +
		HTNCX*-1 +
		PARA*-1 +
		NEURO*5 +
		CHRNLUNG*5 +
		DM*3 +
		DMCX*0 +
		HYPOTHY*-3 +
		RENLFAIL*6 +
		LIVER*4 +
		ULCER*0 +
		AIDS*0 +
		LYMPH*6 +
		METS*14 +
		TUMOR*7 +
		ARTH*0 +
		COAG*11 +
		OBESE*-5 +
		WGHTLOSS*9 +
		LYTES*11 +
		BLDLOSS*-3 +
		ANEMDEF*-2 +
		ALCOHOL*-1 +
		DRUG*-7 +
		PSYCH*6 +
		DEPRESS*-5
	) AS ECI
INTO #ECI_FINAL
FROM AggregatedElix


DROP TABLE IF EXISTS [SCS_EEGUtil].[EEG].[rn_elix3]
CREATE TABLE [SCS_EEGUtil].[EEG].[rn_elix3] (
    PatientICN VARCHAR(50) PRIMARY KEY,
    CHF FLOAT,
    -- ARRHY FLOAT,
    PULMCIRC FLOAT,
    PERIVASC FLOAT,
    HTN FLOAT,
    HTNCX FLOAT,
    PARA FLOAT,
    NEURO FLOAT,
    CHRNLUNG FLOAT,
    DM FLOAT,
    DMCX FLOAT,
    HYPOTHY FLOAT,
    RENLFAIL FLOAT,
    LIVER FLOAT,
    ULCER FLOAT,
    AIDS FLOAT,
    LYMPH FLOAT,
    METS FLOAT,
    TUMOR FLOAT,
    ARTH FLOAT,
    COAG FLOAT,
    OBESE FLOAT,
    WGHTLOSS FLOAT,
    LYTES FLOAT,
    BLDLOSS FLOAT,
    ANEMDEF FLOAT,
    ALCOHOL FLOAT,
    DRUG FLOAT,
    PSYCH FLOAT,
    DEPRESS FLOAT,
    ECI FLOAT
)

INSERT INTO [SCS_EEGUtil].[EEG].[rn_elix3] 
SELECT
    coh.PatientICN,
    ecif.CHF,
    -- ecif.ARRHY
    ecif.PULMCIRC,
    ecif.PERIVASC,
    ecif.HTN,
    ecif.HTNCX,
    ecif.PARA,
    ecif.NEURO,
    ecif.CHRNLUNG,
    ecif.DM,
    ecif.DMCX,
    ecif.HYPOTHY,
    ecif.RENLFAIL,
    ecif.LIVER,
    ecif.ULCER,
    ecif.AIDS,
    ecif.LYMPH,
    ecif.METS,
    ecif.TUMOR,
    ecif.ARTH,
    ecif.COAG,
    ecif.OBESE,
    ecif.WGHTLOSS,
    ecif.LYTES,
    ecif.BLDLOSS,
    ecif.ANEMDEF,
    ecif.ALCOHOL,
    ecif.DRUG,
    ecif.PSYCH,
    ecif.DEPRESS,
    ecif.ECI
FROM
    #ECI_FINAL ecif
INNER JOIN 
    [SCS_EEGUtil].[EEG].[rn_cohort2] coh
	ON 
    ecif.PatientICN = coh.PatientICN

select 
	avg(eci) 
from
	SCS_EEGUtil.EEG.rn_elix3

select 
	avg(eci) 
from
	SCS_EEGUtil.EEG.rn_elix2