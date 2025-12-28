DROP TABLE IF EXISTS [SCS_EEGUtil].[EEG].[rn_demographics]
CREATE TABLE [SCS_EEGUtil].[EEG].[rn_demographics] (
    PatientICN VARCHAR(50) PRIMARY KEY,
    Gender VARCHAR(50),
    Race VARCHAR(50),
    Ethnicity VARCHAR(50),
    ServiceConnectedPercent DECIMAL
)

DROP TABLE IF EXISTS #demographics_by_sid
SELECT
    coh.PatientICN,
    pat.Gender,
    rac.Race,
    eth.Ethnicity,
    dis.ServiceConnectedPercent
INTO 
    #demographics_by_sid
FROM 
    [SCS_EEGUtil].[EEG].[rn_cohort2] coh
INNER JOIN 
    CDWWork.Patient.Patient pat
    ON 
    coh.PatientICN = pat.PatientICN
LEFT JOIN 
    CDWWork.PatSub.PatientRace rac
    ON 
    pat.PatientSID = rac.PatientSID
LEFT JOIN 
    CDWWork.PatSub.PatientEthnicity eth
    ON 
    pat.PatientSID = eth.PatientSID
LEFT JOIN 
    CDWWork.SPatient.SPatientDisability dis
    ON 
    pat.PatientSID = dis.PatientSID



INSERT INTO [SCS_EEGUtil].[EEG].[rn_demographics] (
    PatientICN,
    Gender,
    Race,
    Ethnicity,
    ServiceConnectedPercent
) 
SELECT
    gen.PatientICN,
    gen.Gender,
    rac.Race,
    eth.Ethnicity,
    ser.ServiceConnectedPercent
FROM (
    SELECT
        PatientICN,
        Gender
    FROM (
        SELECT
            PatientICN,
            Gender,
            COUNT(*) AS cnt,
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
LEFT JOIN (
    SELECT
        PatientICN,
        Race
    FROM (
        SELECT
            PatientICN,
            Race,
            COUNT(*) AS cnt,
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
LEFT JOIN (
    SELECT
        PatientICN,
        Ethnicity
    FROM (
        SELECT
            PatientICN,
            Ethnicity,
            COUNT(*) AS cnt,
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
LEFT JOIN (
    SELECT
        PatientICN,
        ServiceConnectedPercent
    FROM (
        SELECT
            PatientICN,
            ServiceConnectedPercent,
            COUNT(*) AS cnt,
            ROW_NUMBER() OVER (PARTITION BY PatientICN ORDER BY COUNT(*) DESC) AS rn
        FROM 
            #demographics_by_sid
        WHERE 
            ServiceConnectedPercent IS NOT NULL
        GROUP BY 
            PatientICN, 
            ServiceConnectedPercent
    ) sub
    WHERE sub.rn = 1
) ser
    ON
    gen.PatientICN = ser.PatientICN


