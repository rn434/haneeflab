/*

This file pulls additional data for the VELCRO DRE cohort regarding 
multidisciplinary care received by patients. We do so using the following
stop code defintions:

    106: Routine EEG
    128: Inpatient Video EEG
        - Consider CPT 95720 (not done in this file)
    538: Neuropsychiatry Testing
        - Consider CPT 90791 (not done in this file)
    406: Neurosurgery
    125: Social Work
    502: Mental Health Clinic Individual
    564: Mental Health Team Case Management 
    160: Pharmacy Medication Management
    509: Psychiatry
    510: Psychology
    315: Neurology

Estimated runtime = xx m.

*/

DROP TABLE IF EXISTS #StopCodeCriteria;
SELECT *
INTO #StopCodeCriteria
FROM (VALUES
    (106, 'Routine EEG'),
    (128, 'Inpatient Video EEG'),
    (538, 'Neuropsychological Testing'),
    (406, 'Neurosurgery'),
    (125, 'Social Work'),
    (502, 'Mental Health Clinic Individual'),
    (564, 'Mental Health Team Case Management '),
    (160, 'Pharmacy Medication Management'),
    (509, 'Psychiatry'),
    (510, 'Psychology'),
    (315, 'Neurology'),
    (345, 'ECoE')
) AS criteria (StopCode, EncounterLocation)

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnStopCodeComplete;
SELECT stop.StopCodeSID,
    stop.StopCode,
    crit.EncounterLocation
INTO SCS_EEGUtil.EEG.rnStopCodeComplete
FROM CDWWork.Dim.StopCode stop
    INNER JOIN #StopCodeCriteria crit
        ON stop.StopCode = crit.StopCode;

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnMultidisciplinaryCareVELCRO;
SELECT pat.PatientICN,
    pat.PatientSSN,
    CAST(vis.VisitDateTime AS DATE) AS EncounterDate,
    stop1.PrimaryStopCode,
    stop1.EncounterLocation AS PrimaryEncounterLocation,
    stop2.SecondaryStopCode,
    stop2.EncounterLocation AS SecondaryEncounterLocation
INTO SCS_EEGUtil.EEG.rnMultidisciplinaryCareVELCRO
FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
    INNER JOIN CDWWork.SPatient.SPatient pat
        ON coh.PatientSSN = pat.PatientSSN
    INNER JOIN CDWWork.Outpat.Visit vis
        ON pat.PatientSID = vis.PatientSID
    LEFT JOIN SCS_EEGUtil.EEG.rnStopCodeComplete stop1
        ON vis.PrimaryStopCodeSID = stop1.StopCodeSID
    LEFT JOIN SCS_EEGUtil.EEG.rnStopCodeComplete stop2
        ON vis.SecondaryStopCodeSID = stop2.StopCodeSID
WHERE vis.WorkloadLogicFlag = 'Y'
    AND (stop1.StopCodeSID IS NOT NULL OR stop2.StopCodeSID IS NOT NULL);

SELECT * FROM SCS_EEGUtil.EEG.rnMultidisciplinaryCareVELCRO;
