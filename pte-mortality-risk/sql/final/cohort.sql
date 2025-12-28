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
    ORD_Haneef_202402056D.Dflt.rnEpilepsyFinal
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
EXEC ORD_Haneef_202402056D.Dflt.ComputeECI '##EpilepsyDxDate';


DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnCohortInfoFinal2;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnCohortInfoFinal2 (
    PatientICN VARCHAR(10) PRIMARY KEY,

    DxDate DATE,

    BirthDate DATE,
    DeathDate DATE,
    Gender VARCHAR(1),
    Race VARCHAR(50),
    Ethnicity VARCHAR(50),

    ECI INT,

    FollowUpDate DATE,

    AllTBIClassKarlanderAny VARCHAR(20),
    AllTBIClassKarlanderMode VARCHAR(20),
    AllTBIClassKarlanderWorst VARCHAR(20),
    
    TBIClassKarlanderAny VARCHAR(20),
    TBIClassKarlanderMode VARCHAR(20),
    TBIClassKarlanderWorst VARCHAR(20),

    TBIClassArmedAny VARCHAR(20),
    TBIClassArmedMode VARCHAR(20),
    TBIClassArmedWorst VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnCohortInfoFinal2 (
    PatientICN,

    DxDate,

    BirthDate,
    DeathDate,
    Gender,
    Race,
    Ethnicity,

    ECI,

    FollowUpDate,

    AllTBIClassKarlanderAny,
    AllTBIClassKarlanderMode,
    AllTBIClassKarlanderWorst,
    
    TBIClassKarlanderAny,
    TBIClassKarlanderMode,
    TBIClassKarlanderWorst,

    TBIClassArmedAny,
    TBIClassArmedMode,
    TBIClassArmedWorst
)
SELECT
    epi.PatientICN,

    epi.DxDate,

    dem.BirthDate,
    dem.DeathDate,
    dem.Gender,
    dem.Race,
    dem.Ethnicity,

    eci.ECI,

    latest.FollowUpDate,

    allpte.TBIClassKarlanderAny AS AllTBIClassKarlanderAny,
    allpte.TBIClassKarlanderMode AS AllTBIClassKarlanderMode,
    allpte.TBIClassKarlanderWorst AS AllTBIClassKarlanderWorst,
    
    pte.TBIClassKarlanderAny,
    pte.TBIClassKarlanderMode,
    pte.TBIClassKarlanderWorst,

    pte.TBIClassArmedAny,
    pte.TBIClassArmedMode,
    pte.TBIClassArmedWorst 
FROM
    ORD_Haneef_202402056D.Dflt.rnEpilepsyFinal epi
    Left JOIN
    ORD_Haneef_202402056D.Dflt.rnDemographicsFinal dem
        ON
        epi.PatientICN = dem.PatientICN
    Left JOIN
    #ECI eci
        ON
        epi.PatientICN = eci.PatientICN
    Left JOIN
    ORD_Haneef_202402056D.Dflt.rnLatest latest
        ON
        epi.PatientICN = latest.PatientICN
    LEFT JOIN
    ORD_Haneef_202402056D.Dflt.rnPTEAllFinal allpte
        ON
        epi.PatientICN = allpte.PatientICN
    LEFT JOIN
    ORD_Haneef_202402056D.Dflt.rnPTEFinal pte
        ON
        epi.PatientICN = pte.PatientICN
;
