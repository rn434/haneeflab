SELECT 
    * 
FROM CDWWork.Meta.DWViewField
WHERE DWViewFieldName LIKE '%PatientSID%'
;
--
SELECT TOP 100
    *
FROM SCS_EEGUtil.EEG.rn_demographics
--
-- SELECT TOP 5 * FROM [SCS_EEGUtil].[EEG].[rn_cohort_with_info_new]


DROP TABLE IF EXISTS [SCS_EEGUtil].[EEG].[rn_cohort]
CREATE TABLE [SCS_EEGUtil].[EEG].[rn_cohort] (
    PatientICN VARCHAR(50) PRIMARY KEY,
    BirthDateTime DATETIME,
    FirstDXDateTime DATETIME,
    LatestVisitDateTime DATETIME,
    DeathDateTime DATETIME,
    TBIDateTime DATETIME
)

INSERT INTO [SCS_EEGUtil].[EEG].[rn_cohort] (
    PatientICN,
    BirthDateTime,
    FirstDXDateTime,
    LatestVisitDateTime,
    DeathDateTime,
    TBIDateTime
) 
SELECT
    coh.PatientICN,
    coh.BirthDateTime,
    coh.FirstDXDateTime,
    coh.LatestVisitDateTime,
    coh.DeathDateTime,
    p.MostRecentTBIVisitDateTime as TBIDateTime
FROM [SCS_EEGUtil].[EEG].[rn_cohort_with_info_new] coh
LEFT JOIN [SCS_EEGUtil].[EEG].[rn_pte] p
    ON coh.PatientICN = p.PatientICN


DROP TABLE IF EXISTS [SCS_EEGUtil].[EEG].[rn_demographics]
CREATE TABLE [SCS_EEGUtil].[EEG].[rn_demographics] (
    PatientICN VARCHAR(50) PRIMARY KEY,
    Gender VARCHAR(1),
    Race VARCHAR(10),
    Ethnicity VARCHAR(10),
    ServiceConnection DECIMAL
)

DROP TABLE IF EXISTS #demographics_by_sid
SELECT
    coh.PatientICN,
    pat.Gender,
    rac.Race,
    eth.Ethnicity,
    dis.ServiceConnection
INTO 
    #demographics_by_sid
FROM 
    [SCS_EEGUtil].[EEG].[rn_cohort] coh
INNER JOIN 
    CDWWork.Patient.Patient pat
    ON 
    coh.PatientICN = pat.PatientICN
INNER JOIN 
    CDWWork.PatSub.PatientRace rac
    ON 
    pat.PatientSID = rac.PatientSID
INNER JOIN 
    CDWWork.PatSub.PatientEthnicity eth
    ON 
    pat.PatientSID = eth.PatientSID
INNER JOIN 
    CDWWork.SPatient.SPatientDisability dis
    ON 
    pat.PatientSID = dis.PatientSID



INSERT INTO [SCS_EEGUtil].[EEG].[rn_demographics] (
    PatientICN,
    Gender,
    Race,
    Ethnicity,
    ServiceConnection
) 
SELECT
    PatientICN,
    Gender,
    Race,
    Ethnicity,
    ServiceConnection
FROM (
    SELECT
        PatientICN,
        Gender
    FROM (
        SELECT
            PatientICN,
            Gender,
            COUNT(*),
            ROW_NUMBER() OVER (PARTITION BY PatientICN ORDER BY COUNT(*) DESC) AS rn
        FROM 
            #demographics_by_sid
        WHERE 
            Gender IS NOT NULL
        GROUP BY 
            PatientICN, 
            Gender
    ) sub
    WHERE sub.rn = 1
) gen
INNER JOIN (
    SELECT
        PatientICN,
        Race
    FROM (
        SELECT
            PatientICN,
            Race,
            COUNT(*),
            ROW_NUMBER() OVER (PARTITION BY PatientICN ORDER BY COUNT(*) DESC) AS rn
        FROM 
            #demographics_by_sid
        WHERE 
            Race IS NOT NULL
        GROUP BY 
            PatientICN, 
            Race
    ) sub
    WHERE sub.rn = 1
) rac
    ON
    gen.PatientICN = rac.PatientICN
INNER JOIN (
    SELECT
        PatientICN,
        Ethnicity
    FROM (
        SELECT
            PatientICN,
            Ethnicity,
            COUNT(*),
            ROW_NUMBER() OVER (PARTITION BY PatientICN ORDER BY COUNT(*) DESC) AS rn
        FROM 
            #demographics_by_sid
        WHERE 
            Ethnicity IS NOT NULL
        GROUP BY 
            PatientICN, 
            Ethnicity
    ) sub
    WHERE sub.rn = 1
) eth
    ON
    gen.PatientICN = eth.PatientICN
INNER JOIN (
    SELECT
        PatientICN,
        ServiceConnection
    FROM (
        SELECT
            PatientICN,
            ServiceConnection,
            COUNT(*),
            ROW_NUMBER() OVER (PARTITION BY PatientICN ORDER BY COUNT(*) DESC) AS rn
        FROM 
            #demographics_by_sid
        WHERE 
            ServiceConnection IS NOT NULL
        GROUP BY 
            PatientICN, 
            ServiceConnection
    ) sub
    WHERE sub.rn = 1
) ser
    ON
    gen.PatientICN = ser.PatientICN






DROP TABLE IF EXISTS #my_cohort
SELECT
	PatientICN,
	FirstDXDateTime
INTO
	#my_cohort
FROM [SCS_EEGUtil].[EEG].[rn_cohort2]

DROP TABLE IF EXISTS #my_gcs
SELECT
    ClinicalTermSID
INTO 
    #my_gcs
FROM
    CDWWork.Dim.ClinicalTerm
WHERE ClinicalTermIEN = '7751598'


SELECT TOP 1
    coh.PatientICN,
    vd.*
FROM 
    #my_cohort coh
    INNER JOIN
    CDWWork.Patient.Patient pat
        ON
        coh.PatientICN = pat.PatientICN
    INNER JOIN
    CDWWork.Outpat.WorkloadVDiagnosis vd
        ON 
        pat.PatientSID = vd.PatientSID
    INNER JOIN
    #my_gcs gcs
        ON
        vd.ClinicalTermSID = gcs.ClinicalTermSID



