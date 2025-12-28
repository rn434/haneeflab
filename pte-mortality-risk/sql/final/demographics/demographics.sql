/*

This file gathers demographic information for each patient available in 
ORD_Haneef_202402056D. The demographic variables of interest are birthdate, 
death date, gender, race, and ethnicity. The procedure is as follows:

    1. Gather demographic information for each PatientSID.
    2. For each PatientICN, look through all the demographic records for each 
       associated PatientSID to find the most common value for each of the 
       demographic variables that is not null.

*/

USE ORD_Haneef_202402056D;
GO

DROP TABLE IF EXISTS #MultipleDemographics;
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

DROP TABLE IF EXISTS #BirthDateMode;
CREATE TABLE #BirthDateMode (
    PatientICN VARCHAR(10) PRIMARY KEY,
    BirthDate VARCHAR(25)
);
INSERT INTO #BirthDateMode
EXEC ORD_Haneef_202402056D.Dflt.ComputeMode '#MultipleDemographics', 'PatientICN', 'BirthDate'
;

DROP TABLE IF EXISTS #DeathDateMode;
CREATE TABLE #DeathDateMode (
    PatientICN VARCHAR(10) PRIMARY KEY,
    DeathDate VARCHAR(25)
);
INSERT INTO #DeathDateMode
EXEC ORD_Haneef_202402056D.Dflt.ComputeMode '#MultipleDemographics', 'PatientICN', 'DeathDate'
;

DROP TABLE IF EXISTS #GenderMode;
CREATE TABLE #GenderMode (
    PatientICN VARCHAR(10) PRIMARY KEY,
    Gender VARCHAR(25)
);
INSERT INTO #GenderMode
EXEC ORD_Haneef_202402056D.Dflt.ComputeMode '#MultipleDemographics', 'PatientICN', 'Gender'
;

DROP TABLE IF EXISTS #RaceMode;
CREATE TABLE #RaceMode (
    PatientICN VARCHAR(10) PRIMARY KEY,
    Race VARCHAR(50)
);
INSERT INTO #RaceMode
EXEC ORD_Haneef_202402056D.Dflt.ComputeMode '#MultipleDemographics', 'PatientICN', 'Race'
;

DROP TABLE IF EXISTS #EthnicityMode;
CREATE TABLE #EthnicityMode (
    PatientICN VARCHAR(10) PRIMARY KEY,
    Ethnicity VARCHAR(25)
);
INSERT INTO #EthnicityMode
EXEC ORD_Haneef_202402056D.Dflt.ComputeMode '#MultipleDemographics', 'PatientICN', 'Ethnicity'
;
    

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnDemographicsFinal;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnDemographicsFinal (
    PatientICN VARCHAR(10) PRIMARY KEY,
    BirthDate DATE,
    DeathDate DATE,
    Gender VARCHAR(1),
    Race VARCHAR(50),
    Ethnicity VARCHAR(50)
);
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnDemographicsFinal (
        PatientICN,
        BirthDate,
        DeathDate,
        Gender,
        Race,
        Ethnicity
    )
SELECT
    coh.PatientICN,
    birth.BirthDate,
    death.DeathDate,
    gender.Gender,
    race.Race,
    ethnicity.Ethnicity
FROM
    (SELECT DISTINCT PatientICN FROM ORD_Haneef_202402056D.Src.CohortCrosswalk) coh
    FULL JOIN
    #BirthDateMode birth
        ON
        coh.PatientICN = birth.PatientICN
    FULL JOIN
    #DeathDateMode death
        ON
        coh.PatientICN = death.PatientICN
    FULL JOIN
    #GenderMode gender
        ON
        coh.PatientICN = gender.PatientICN
    FULL JOIN
    #RaceMode race
        ON
        coh.PatientICN = race.PatientICN
    FULL JOIN
    #EthnicityMode ethnicity
        ON
        coh.PatientICN = ethnicity.PatientICN
;

select top 100 * from ORD_Haneef_202402056D.Dflt.rnDemographicsFinal