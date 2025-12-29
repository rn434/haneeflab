/*

This file combiens diagnosis and demographics data for the epilepsy in older 
adults project. The workup statistics are also determined.

Estimated runtime = 8 m.

*/

-- MRI Head (estimated runtime = 1 m.)

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnMRICriteria;
SELECT cpt.CPTSID,
    cpt.CPTCode
INTO SCS_EEGUtil.EEG.rnMRICriteria
FROM CDWWork.Dim.CPT cpt
WHERE LEN(cpt.CPTCode) <= 10
    AND CPTCode in ('70551', '70552', '70553');

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnMRI;
SELECT pat.PatientICN,
    CAST(vproc.EventDateTime AS DATE) AS MRIDate
INTO SCS_EEGUtil.EEG.rnMRI
FROM CDWWork.Outpat.WorkloadVProcedure vproc
    INNER JOIN SCS_EEGUtil.EEG.rnMRICriteria mri
        ON vproc.CPTSID = mri.CPTSID
    INNER JOIN CDWWork.Patient.Patient pat
        ON vproc.PatientSID = pat.PatientSID
    INNER JOIN SCS_EEGUtil.EEG.rnEpilepsy coh
        ON pat.PatientICN = coh.PatientICN;

-- EEG Data (estimated runtime = 3 m.)
-- Does this require secondary stop code checks?

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnEEG;
SELECT pat.PatientICN,
    CASE WHEN COALESCE(stopcode1.StopCode, stopcode2.StopCode) = 106 THEN 'Routine'
        ELSE 'Continuous' END AS EEGType,
    CAST(vis.VisitDateTime AS DATE) AS EEGDate
INTO SCS_EEGUtil.EEG.rnEEG
FROM CDWWork.Outpat.Visit vis
    LEFT JOIN SCS_EEGUtil.EEG.rnStopCode stopcode1
        ON vis.PrimaryStopCodeSID = stopcode1.StopCodeSID
    LEFT JOIN SCS_EEGUtil.EEG.rnStopCode stopcode2
        ON vis.SecondaryStopCodeSID = stopcode2.StopCodeSID
    INNER JOIN CDWWork.Patient.Patient pat
        ON vis.PatientSID = pat.PatientSID
    INNER JOIN SCS_EEGUtil.EEG.rnEpilepsy epi
        ON pat.PatientICN = epi.PatientICN
WHERE stopcode1.StopCodeSID IS NOT NULL OR stopcode2.StopCodeSID IS NOT NULL;

-- CT Head (estimated runtime = 1 m.)

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnCTCriteria;
SELECT cpt.CPTSID,
    cpt.CPTCode
INTO SCS_EEGUtil.EEG.rnCTCriteria
FROM CDWWork.Dim.CPT cpt
WHERE CPTCode in ('70450', '70460', '70470');

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnCT;
SELECT pat.PatientICN,
    CAST(vproc.EventDateTime AS DATE) AS CTDate
INTO SCS_EEGUtil.EEG.rnCT
FROM CDWWork.Outpat.WorkloadVProcedure vproc
    INNER JOIN SCS_EEGUtil.EEG.rnCTCriteria ct
        ON vproc.CPTSID = ct.CPTSID
    INNER JOIN CDWWork.Patient.Patient pat
        ON vproc.PatientSID = pat.PatientSID
    INNER JOIN SCS_EEGUtil.EEG.rnEpilepsy epi
        ON pat.PatientICN = epi.PatientICN;

-- Holter Monitor (estimated runtime = 2 m.)

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnHolterMonitorCriteria;
SELECT cpt.CPTSID,
    cpt.CPTCode
INTO SCS_EEGUtil.EEG.rnHolterMonitorCriteria
FROM CDWWork.Dim.CPT cpt
WHERE CPTCode in (
    '93224',
    '93225',
    '93226',
    '93227',
    '93241',
    '93242',
    '93243',
    '93244',
    '93245',
    '93246',
    '93247',
    '93248',
    '93271',
    '93272',
    '93268',
    '93285',
    '93286',
    '93287',
    '93288',
    '93289',
    '93290',
    '93291');

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnHolterMonitor;
SELECT pat.PatientICN,
    CAST(vproc.EventDateTime AS DATE) AS HolterMonitorDate
INTO SCS_EEGUtil.EEG.rnHolterMonitor
FROM CDWWork.Outpat.WorkloadVProcedure vproc
    INNER JOIN SCS_EEGUtil.EEG.rnHolterMonitorCriteria holter
        ON vproc.CPTSID = holter.CPTSID
    INNER JOIN CDWWork.Patient.Patient pat
        ON vproc.PatientSID = pat.PatientSID
    INNER JOIN SCS_EEGUtil.EEG.rnEpilepsy epi
        ON pat.PatientICN = epi.PatientICN;

-- Tilt Table (estimated runtime = 1 m.)

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnTiltTableCriteria;
SELECT cpt.CPTSID,
    cpt.CPTCode
INTO SCS_EEGUtil.EEG.rnTiltTableCriteria
FROM CDWWork.Dim.CPT cpt
WHERE CPTCode in ('93660', '93661');

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnTiltTable;
SELECT pat.PatientICN,
    CAST(vproc.EventDateTime AS DATE) AS TiltTableDate
INTO SCS_EEGUtil.EEG.rnTiltTable
FROM CDWWork.Outpat.WorkloadVProcedure vproc
    INNER JOIN SCS_EEGUtil.EEG.rnTiltTableCriteria tilt
        ON vproc.CPTSID = tilt.CPTSID
    INNER JOIN CDWWork.Patient.Patient pat
        ON vproc.PatientSID = pat.PatientSID
    INNER JOIN SCS_EEGUtil.EEG.rnEpilepsy epi
        ON pat.PatientICN = epi.PatientICN;

