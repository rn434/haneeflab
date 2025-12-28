/* 

This file builds a table with all the 1:1 patient identifier.

Estimated runtime = 3 m.

*/

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnIdentifiers;
SELECT DISTINCT spat.PatientICN,
    MIN(spat.SCRSSN) AS SCRSSN,
    MIN(spat.PatientSSN) AS PatientSSN
INTO SCS_EEGUtil.EEG.rnIdentifiers
FROM SCS_EEGUtil.EEG.rnEpilepsy epi
    INNER JOIN CDWWork.SPatient.SPatient spat
        ON epi.PatientICN = spat.PatientICN
GROUP BY spat.PatientICN;

-- 18 patients have multiple SCRSSN or PatientSSN (using PatientICN as the 100% unique id)
-- according to the below if I don't use an aggregate based on PatientICN
SELECT PatientICN FROM SCS_EEGUtil.EEG.rnIdentifiers GROUP BY PatientICN HAVING COUNT(*) > 1;

