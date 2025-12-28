/* 

This file combines data into one larger table on which analysis can be 
conducted. The values present in this table are:


*/

USE ORD_Haneef_202402056D;
GO

DROP TABLE IF EXISTS ##EpilepsyDxDate;
CREATE TABLE ##EpilepsyDxDate (
    PatientICN VARCHAR(10) PRIMARY KEY,
    IndexDate DATE
);
INSERT INTO ##EpilepsyDxDate (
    PatientICN,
    IndexDate
)
SELECT
    PatientICN,
    DxDate AS IndexDate
FROM
    ORD_Haneef_202402056D.Dflt.rnEpilepsy
;

DROP TABLE IF EXISTS #ECI;
CREATE TABLE #ECI (
    PatientICN VARCHAR(10) PRIMARY KEY,
    ECI INT
);
INSERT INTO #ECI (
    PatientICN,
    ECI
)
EXEC ComputeECI '##EpilepsyDxDate';

DROP TABLE IF EXISTS #ESCI;
CREATE TABLE #ESCI (
    PatientICN VARCHAR(10) PRIMARY KEY,
    ESCI INT
);
INSERT INTO #ESCI (
    PatientICN,
    ESCI
)
EXEC ComputeESCI '##EpilepsyDxDate';


DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnCohortInfoDebug;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnCohortInfoDebug (
    PatientICN VARCHAR(10) PRIMARY KEY,

    DxDate DATE,
    ServiceConnected BIT,

    BirthDate DATE,
    DeathDate DATE,
    Gender VARCHAR(1),
    Race VARCHAR(50),
    Ethnicity VARCHAR(50),

    ECI INT,
    ESCI INT,

    FollowUpDate DATE,
    
    PTE BIT,
    TBIClassChristensen VARCHAR(20),
    TBIClassKarlander VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnCohortInfoDebug (
    PatientICN,

    DxDate,
    ServiceConnected,

    BirthDate,
    DeathDate,
    Gender,
    Race,
    Ethnicity,

    ECI,
    ESCI,

    FollowUpDate,
    
    PTE,
    TBIClassChristensen,
    TBIClassKarlander
)
SELECT
    epi.PatientICN,

    epi.DxDate,
    epi.ServiceConnected,

    dem.BirthDate,
    dem.DeathDate,
    dem.Gender,
    dem.Race,
    dem.Ethnicity,

    eci.ECI,
    esci.ESCI,

    latest.FollowUpDate,
    
    CASE WHEN pte.PatientICN IS NULL THEN 0 ELSE 1 END AS PTE,
    pte.TBIClassChristensen,
    pte.TBIClassKarlander
FROM
    ORD_Haneef_202402056D.Dflt.rnEpilepsy epi
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnDemographics dem
        ON
        epi.PatientICN = dem.PatientICN
    INNER JOIN
    #ECI eci
        ON
        epi.PatientICN = eci.PatientICN
    INNER JOIN
    #ESCI esci
        ON
        epi.PatientICN = esci.PatientICN
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnLatest latest
        ON
        epi.PatientICN = latest.PatientICN
    LEFT JOIN
    ORD_Haneef_202402056D.Dflt.rnPTEDebug pte
        ON
        epi.PatientICN = pte.PatientICN
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnCohortInfo2;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnCohortInfo2 (
    PatientICN VARCHAR(10) PRIMARY KEY,

    DxDate DATE,
    ServiceConnected BIT,

    BirthDate DATE,
    DeathDate DATE,
    Gender VARCHAR(1),
    Race VARCHAR(50),
    Ethnicity VARCHAR(50),

    ECI INT,
    ESCI INT,

    FollowUpDate DATE,
    
    PTE BIT,
    TBIClassChristensen VARCHAR(20),
    TBIClassKarlander VARCHAR(20),

    PTE2 BIT,
    TBISeverity VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnCohortInfo2 (
    PatientICN,

    DxDate,
    ServiceConnected,

    BirthDate,
    DeathDate,
    Gender,
    Race,
    Ethnicity,

    ECI,
    ESCI,

    FollowUpDate,
    
    PTE,
    TBIClassChristensen,
    TBIClassKarlander,

    PTE2,
    TBISeverity
)
SELECT
    coh.PatientICN,

    coh.DxDate,
    coh.ServiceConnected,

    coh.BirthDate,
    coh.DeathDate,
    coh.Gender,
    coh.Race,
    coh.Ethnicity,

    coh.ECI,
    coh.ESCI,

    coh.FollowUpDate,
    
    CASE WHEN pte.PatientICN IS NULL THEN 0 ELSE 1 END AS PTE,
    pte.TBIClassChristensen,
    pte.TBIClassKarlander,

    CASE WHEN pte2.PatientICN IS NULL THEN 0 ELSE 1 END AS PTE2,
    pte2.TBISeverity
FROM
    ORD_Haneef_202402056D.Dflt.rnCohortInfo coh
    LEFT JOIN
    ORD_Haneef_202402056D.Dflt.rnPTE pte
        ON
        coh.PatientICN = pte.PatientICN
    LEFT JOIN
    ORD_Haneef_202402056D.Dflt.rnPTE2 pte2
        ON
        coh.PatientICN = pte2.PatientICN
;
