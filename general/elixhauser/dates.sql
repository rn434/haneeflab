/*

This file looks through all available diagnostic information for each patient 
and determines the earliest date at which they experienced the comorbidities 
required in the calculation of the Elixhauser comorbidity index (ECI).

Estimated runtime = 8 m.

*/

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnElixhauserDates;
WITH Cohort AS (
    SELECT epi.PatientICN,
        pat.PatientSID
    FROM SCS_EEGUtil.EEG.rnEpilepsy epi
        INNER JOIN CDWWork.Patient.Patient pat
            ON epi.PatientICN = pat.PatientICN)
SELECT coh.PatientICN,
    MIN(CASE WHEN COALESCE(icd9.CHF, 0) = 1 
        OR COALESCE(icd10.CHF, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE)
    END) AS CHF,
    MIN(CASE WHEN COALESCE(icd9.Arrhy, 0) = 1 
        OR COALESCE(icd10.Arrhy, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Arrhy,
    MIN(CASE WHEN COALESCE(icd9.Valv, 0) = 1 
        OR COALESCE(icd10.Valv, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Valv,
    MIN(CASE WHEN COALESCE(icd9.PulmCirc, 0) = 1 
        OR COALESCE(icd10.PulmCirc, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS PulmCirc,
    MIN(CASE WHEN COALESCE(icd9.Vasc, 0) = 1 
        OR COALESCE(icd10.Vasc, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Vasc,
    MIN(CASE WHEN COALESCE(icd9.HTN, 0) = 1 
        OR COALESCE(icd10.HTN, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS HTN,
    MIN(CASE WHEN COALESCE(icd9.Para, 0) = 1 
        OR COALESCE(icd10.Para, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Para,
    MIN(CASE WHEN COALESCE(icd9.Neuro, 0) = 1 
        OR COALESCE(icd10.Neuro, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Neuro,
    MIN(CASE WHEN COALESCE(icd9.PulmChronic, 0) = 1 
        OR COALESCE(icd10.PulmChronic, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS PulmChronic,
    MIN(CASE WHEN COALESCE(icd9.DiabUnc, 0) = 1 
        OR COALESCE(icd10.DiabUnc, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS DiabUnc,
    MIN(CASE WHEN COALESCE(icd9.DiabC, 0) = 1 
        OR COALESCE(icd10.DiabC, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS DiabC,
    MIN(CASE WHEN COALESCE(icd9.Hypothy, 0) = 1 
        OR COALESCE(icd10.Hypothy, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Hypothy,
    MIN(CASE WHEN COALESCE(icd9.RenFail, 0) = 1 
        OR COALESCE(icd10.RenFail, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS RenFail,
    MIN(CASE WHEN COALESCE(icd9.Liver, 0) = 1 
        OR COALESCE(icd10.Liver, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Liver,
    MIN(CASE WHEN COALESCE(icd9.Peptic, 0) = 1 
        OR COALESCE(icd10.Peptic, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Peptic,
    MIN(CASE WHEN COALESCE(icd9.AIDS, 0) = 1 
        OR COALESCE(icd10.AIDS, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS AIDS,
    MIN(CASE WHEN COALESCE(icd9.Lymphoma, 0) = 1 
        OR COALESCE(icd10.Lymphoma, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Lymphoma,
    MIN(CASE WHEN COALESCE(icd9.MetCancer, 0) = 1 
        OR COALESCE(icd10.MetCancer, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS MetCancer,
    MIN(CASE WHEN COALESCE(icd9.Tumor, 0) = 1 
        OR COALESCE(icd10.Tumor, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Tumor,
    MIN(CASE WHEN COALESCE(icd9.Rheum, 0) = 1 
        OR COALESCE(icd10.Rheum, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Rheum,
    MIN(CASE WHEN COALESCE(icd9.Coag, 0) = 1 
        OR COALESCE(icd10.Coag, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Coag,
    MIN(CASE WHEN COALESCE(icd9.Obesity, 0) = 1 
        OR COALESCE(icd10.Obesity, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Obesity,
    MIN(CASE WHEN COALESCE(icd9.WLoss, 0) = 1 
        OR COALESCE(icd10.WLoss, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS WLoss,
    MIN(CASE WHEN COALESCE(icd9.Fluid, 0) = 1 
        OR COALESCE(icd10.Fluid, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Fluid,
    MIN(CASE WHEN COALESCE(icd9.Blood, 0) = 1 
        OR COALESCE(icd10.Blood, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Blood,
    MIN(CASE WHEN COALESCE(icd9.Deficiency, 0) = 1 
        OR COALESCE(icd10.Deficiency, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Deficiency,
    MIN(CASE WHEN COALESCE(icd9.Alcohol, 0) = 1 
        OR COALESCE(icd10.Alcohol, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Alcohol,
    MIN(CASE WHEN COALESCE(icd9.Drug, 0) = 1 
        OR COALESCE(icd10.Drug, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Drug,
    MIN(CASE WHEN COALESCE(icd9.Psych, 0) = 1 
        OR COALESCE(icd10.Psych, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Psych,
    MIN(CASE WHEN COALESCE(icd9.Depress, 0) = 1 
        OR COALESCE(icd10.Depress, 0) = 1 
        THEN CAST(dx.VDiagnosisDateTime AS DATE) 
    END) AS Depress
INTO SCS_EEGUtil.EEG.rnElixhauserDates
FROM Cohort coh
    INNER JOIN CDWWork.Outpat.VDiagnosis dx
        ON dx.PatientSID = coh.PatientSID
    LEFT JOIN SCS_EEGUtil.EEG.rnElixhauserICD9 icd9
        ON dx.ICD9SID = icd9.ICD9SID
    LEFT JOIN SCS_EEGUtil.EEG.rnElixhauserICD10 icd10
        ON dx.ICD10SID = icd10.ICD10SID
GROUP BY PatientICN;
