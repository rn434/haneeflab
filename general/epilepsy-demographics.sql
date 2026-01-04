/*

This file gathers demographics data for all epilepsy patients.

Estimated runtime = 1 m.

*/

DROP TABLE IF EXISTS #MultipleDemographics;
SELECT coh.PatientICN,
    CAST(spat.BirthDateTime AS DATE) AS BirthDate,
    CAST(spat.DeathDateTime AS DATE) AS DeathDate,
    spat.Gender AS Sex,
    race.Race,
    eth.Ethnicity
INTO #MultipleDemographics
FROM SCS_EEGUtil.EEG.rnEpilepsyComplete coh
    INNER JOIN CDWWork.SPatient.SPatient spat
        ON coh.PatientICN = spat.PatientICN
    LEFT JOIN CDWWork.PatSub.PatientRace race
        ON spat.PatientSID = race.PatientSID
    LEFT JOIN CDWWork.PatSub.PatientEthnicity eth
        ON spat.PatientSID = eth.PatientSID;

DROP TABLE IF EXISTS #BirthDateMode;
CREATE TABLE #BirthDateMode (
    PatientICN VARCHAR(10) PRIMARY KEY,
    BirthDate VARCHAR(25)
);
INSERT INTO #BirthDateMode
EXEC SCS_EEGUtil.EEG.rnComputeMode '#MultipleDemographics', 'PatientICN', 'BirthDate';

DROP TABLE IF EXISTS #DeathDateMode;
CREATE TABLE #DeathDateMode (
    PatientICN VARCHAR(10) PRIMARY KEY,
    DeathDate VARCHAR(25)
);
INSERT INTO #DeathDateMode
EXEC SCS_EEGUtil.EEG.rnComputeMode '#MultipleDemographics', 'PatientICN', 'DeathDate';

DROP TABLE IF EXISTS #SexMode;
CREATE TABLE #SexMode (
    PatientICN VARCHAR(10) PRIMARY KEY,
    Sex VARCHAR(25)
);
INSERT INTO #SexMode
EXEC SCS_EEGUtil.EEG.rnComputeMode '#MultipleDemographics', 'PatientICN', 'Sex';

DROP TABLE IF EXISTS #RaceMode;
CREATE TABLE #RaceMode (
    PatientICN VARCHAR(10) PRIMARY KEY,
    Race VARCHAR(50)
);
INSERT INTO #RaceMode
EXEC SCS_EEGUtil.EEG.rnComputeMode '#MultipleDemographics', 'PatientICN', 'Race';

DROP TABLE IF EXISTS #EthnicityMode;
CREATE TABLE #EthnicityMode (
    PatientICN VARCHAR(10) PRIMARY KEY,
    Ethnicity VARCHAR(25)
);
INSERT INTO #EthnicityMode
EXEC SCS_EEGUtil.EEG.rnComputeMode '#MultipleDemographics', 'PatientICN', 'Ethnicity';

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnDemographics;
SELECT coh.PatientICN,
    birth.BirthDate,
    death.DeathDate,
    sex.Sex,
    race.Race,
    ethnicity.Ethnicity
INTO SCS_EEGUtil.EEG.rnDemographics
FROM SCS_EEGUtil.EEG.rnEpilepsyComplete coh
    FULL JOIN #BirthDateMode birth
        ON coh.PatientICN = birth.PatientICN
    FULL JOIN #DeathDateMode death
        ON coh.PatientICN = death.PatientICN
    FULL JOIN #SexMode sex
        ON coh.PatientICN = sex.PatientICN
    FULL JOIN #RaceMode race
        ON coh.PatientICN = race.PatientICN
    FULL JOIN #EthnicityMode ethnicity
        ON coh.PatientICN = ethnicity.PatientICN;

