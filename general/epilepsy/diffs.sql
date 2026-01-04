SELECT epi.PatientICN
FROM SCS_EEGUtil.EEG.rnEpilepsy epi
    LEFT JOIN SCS_EEGUtil.EEG.rnEpilepsyComplete epic
        ON epi.PatientICN = epic.PatientICN
WHERE epic.PatientICN IS NULL;

SELECT epic.PatientICN
FROM SCS_EEGUtil.EEG.rnEpilepsyComplete epic
    LEFT JOIN SCS_EEGUtil.EEG.rnEpilepsy epi
        ON epic.PatientICN = epi.PatientICN
WHERE epi.PatientICN IS NULL;
