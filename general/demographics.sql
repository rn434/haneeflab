/*

This file gathers demographics data for all epilepsy patients.

Estimated runtime = 10 m.

*/

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnDemographicsAll;
SELECT spat.PatientICN,
    MIN(CAST(spat.BirthDateTime AS DATE)) AS BirthDate,
    MIN(CAST(spat.DeathDateTime AS DATE)) AS DeathDate,
    MAX(spat.Gender) AS Sex
INTO SCS_EEGUtil.EEG.rnDemographicsAll
FROM CDWWork.SPatient.SPatient spat
    LEFT JOIN CDWWork.PatSub.PatientRace race
        ON spat.PatientSID = race.PatientSID
    LEFT JOIN CDWWork.PatSub.PatientEthnicity eth
        ON spat.PatientSID = eth.PatientSID
GROUP BY PatientICN;

