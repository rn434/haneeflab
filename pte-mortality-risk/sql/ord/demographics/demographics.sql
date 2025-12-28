/*

This file gathers demographic information for each patient available in 
ORD_Haneef_202402056D. The demographic variables of interest are birthdate, 
death date, gender, race, and ethnicity. The procedure is as follows:

    1. Gather demographic information for each PatientSID.
    2. For each PatientICN, look through all the demographic records for each 
       associated PatientSID to find the most common value for each of the 
       demographic variables that is not null.

*/


SELECT
    coh.PatientICN,
    CAST(spat.BirthDateTime AS DATE) AS BirthDate,
    CAST(spat.DeathDateTime AS DATE) AS DeathDate,
    spat.Gender, -- this is sex
    race.Race,
    eth.Ethnicity
INTO
    #MultipleDemographics
FROM 
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
    FULL OUTER JOIN 
        ORD_Haneef_202402056D.Src.SPatient_SPatient spat
        ON 
        coh.PatientSID = spat.PatientSID
    FULL OUTER JOIN 
        ORD_Haneef_202402056D.Src.PatSub_PatientRace race
        ON 
        coh.PatientSID = race.PatientSID
    FULL OUTER JOIN 
        ORD_Haneef_202402056D.Src.PatSub_PatientEthnicity eth
        ON 
        coh.PatientSID = eth.PatientSID
;


EXEC ComputeMode '#MultipleDemographics', 'PatientICN', 'BirthDate';
EXEC ComputeMode '#MultipleDemographics', 'PatientICN', 'DeathDate';
EXEC ComputeMode '#MultipleDemographics', 'PatientICN', 'Gender';
EXEC ComputeMode '#MultipleDemographics', 'PatientICN', 'Race';
EXEC ComputeMode '#MultipleDemographics', 'PatientICN', 'Ethnicity';
    

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnDemographics;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnDemographics (
    PatientICN VARCHAR(10) PRIMARY KEY,
    BirthDate DATE,
    DeathDate DATE,
    Gender VARCHAR(1),
    Race VARCHAR(50),
    Ethnicity VARCHAR(50)
);

WITH UniquePatient AS (
    SELECT DISTINCT
        PatientICN
    FROM
        ORD_Haneef_202402056D.Src.CohortCrosswalk
)
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnDemographics (
        PatientICN,
        BirthDate,
        DeathDate,
        Gender,
        Race,
        Ethnicity
    )
SELECT
    birth.PatientICN,
    birth.BirthDate,
    death.DeathDate,
    gender.Gender,
    race.Race,
    ethnicity.Ethnicity
FROM
    Patient pat
    LEFT JOIN
    #BirthDateMode birth
        ON
        pat.PatientICN = birth.PatientICN
    LEFT JOIN
    #DeathDateMode death
        ON
        pat.PatientICN = death.PatientICN
    LEFT JOIN
    #GenderMode gender
        ON
        pat.PatientICN = gender.PatientICN
    LEFT JOIN
    #RaceMode race
        ON
        pat.PatientICN = race.PatientICN
    LEFT JOIN
    #EthnicityMode ethnicity
        ON
        pat.PatientICN = ethnicity.PatientICN
;

