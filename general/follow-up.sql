/* 

This file determines the latest VHA encounter or Rx fill for epilepsy patients.

TODO: capture death date as well

Estimated runtime = 4 m.

*/

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnFollowUp;
WITH LatestVHADx AS (
    SELECT epi.PatientICN,
        MAX(CAST(dx.VDiagnosisDateTime AS DATE)) AS LatestDate
    FROM SCS_EEGUtil.EEG.rnEpilepsy epi
        INNER JOIN CDWWork.Patient.Patient pat
            ON epi.PatientICN = pat.PatientICN
        INNER JOIN CDWWork.Outpat.VDiagnosis dx
            ON pat.PatientSID = dx.PatientSID
    GROUP BY epi.PatientICN)
, LatestRx AS(
    SELECT epi.PatientICN,
        MAX(CAST(rx.FillDateTime AS DATE)) AS LatestDate
    FROM SCS_EEGUtil.EEG.rnEpilepsy epi
        INNER JOIN CDWWork.Patient.Patient pat
            ON epi.PatientICN = pat.PatientICN
        INNER JOIN CDWWork.RxOut.RxOutpatFill rx
            ON pat.PatientSID = rx.PatientSID
    GROUP BY epi.PatientICN)
SELECT PatientICN,
    MAX(LatestDate) AS FollowUpDate
INTO SCS_EEGUtil.EEG.rnFollowUp
FROM (SELECT * FROM LatestVHADx
    UNION SELECT * FROM LatestRx) AS Combined
GROUP BY PatientICN;
