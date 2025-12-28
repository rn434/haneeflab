/*

This file pulls additional codes for the patients in the DRE validation study
regarding intractable epilepsy, focal epilepsy, generalized epilepsy, and FDS.

Estimated runtime = 10 m.
*/

---------------- Intractable Epilepsy ---------------------------

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnIntractableVELCRO;
WITH CombinedDx AS (
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.VDiagnosisDateTime AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Outpat.VDiagnosis' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Outpat.VDiagnosis dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
        WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL
    UNION ALL
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.DischargeDateTime AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Inpat.InpatientDiagnosis' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Inpat.InpatientDiagnosis dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
        WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL
    UNION ALL
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.CorrectInvoiceReceivedDate AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Fee.FeeServiceProvided' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Fee.FeeServiceProvided dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
    WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL
    UNION ALL
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.InvoiceReceivedDateTime AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Fee.FeeInpatInvoiceICDDiagnosis' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Fee.FeeInpatInvoiceICDDiagnosis dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnIntractableICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
    WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL)
SELECT PatientICN,
    PatientSSN,
    DxDate AS VisitDate,
    ICDCode,
    SourceTable
INTO SCS_EEGUtil.EEG.rnIntractableVELCRO
FROM CombinedDx;


----------------------- PNES -----------------------

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnPNESVELCRO;
WITH CombinedDx AS (
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.VDiagnosisDateTime AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Outpat.VDiagnosis' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Outpat.VDiagnosis dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnPNESICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnPNESICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
        WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL
    UNION ALL
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.DischargeDateTime AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Inpat.InpatientDiagnosis' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Inpat.InpatientDiagnosis dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnPNESICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnPNESICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
        WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL
    UNION ALL
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.CorrectInvoiceReceivedDate AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Fee.FeeServiceProvided' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Fee.FeeServiceProvided dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnPNESICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnPNESICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
    WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL
    UNION ALL
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.InvoiceReceivedDateTime AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Fee.FeeInpatInvoiceICDDiagnosis' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Fee.FeeInpatInvoiceICDDiagnosis dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnPNESICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnPNESICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
    WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL)
SELECT PatientICN,
    PatientSSN,
    DxDate,
    ICDCode,
    SourceTable
INTO SCS_EEGUtil.EEG.rnPNESVELCRO
FROM CombinedDx;


------------------------ Focal Epilepsy -------------------------

DROP TABLE IF EXISTS #ICD9FocalCriteria;
SELECT *
INTO #ICD9FocalCriteria
FROM (VALUES ('345.[457]%')) AS criteria (ICD9Prefix);

DROP TABLE IF EXISTS #ICD10FocalCriteria;
SELECT *
INTO #ICD10FocalCriteria
FROM (VALUES ('G40.[012]%')) AS criteria (ICD10Prefix);

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnFocalICD9;
SELECT icd.ICD9SID,
    icd.ICD9Code
INTO SCS_EEGUtil.EEG.rnFocalICD9
FROM CDWWork.Dim.ICD9 icd
    INNER JOIN #ICD9FocalCriteria crit
        ON icd.ICD9Code LIKE crit.ICD9Prefix
WHERE LEN(icd.ICD9Code) <= 10;

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnFocalICD10;
SELECT icd.ICD10SID,
    icd.ICD10Code
INTO SCS_EEGUtil.EEG.rnFocalICD10
FROM CDWWork.Dim.ICD10 icd
    INNER JOIN #ICD10FocalCriteria crit
        ON icd.ICD10Code LIKE crit.ICD10Prefix
WHERE LEN(icd.ICD10Code) <= 10;

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnFocalVELCRO;
WITH CombinedDx AS (
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.VDiagnosisDateTime AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Outpat.VDiagnosis' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Outpat.VDiagnosis dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnFocalICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnFocalICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
        WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL
    UNION ALL
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.DischargeDateTime AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Inpat.InpatientDiagnosis' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Inpat.InpatientDiagnosis dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnFocalICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnFocalICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
        WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL
    UNION ALL
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.CorrectInvoiceReceivedDate AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Fee.FeeServiceProvided' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Fee.FeeServiceProvided dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnFocalICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnFocalICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
    WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL
    UNION ALL
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.InvoiceReceivedDateTime AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Fee.FeeInpatInvoiceICDDiagnosis' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Fee.FeeInpatInvoiceICDDiagnosis dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnFocalICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnFocalICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
    WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL)
SELECT PatientICN,
    PatientSSN,
    DxDate,
    ICDCode,
    SourceTable
INTO SCS_EEGUtil.EEG.rnFocalVELCRO
FROM CombinedDx;


------------------------- Generalized Epilepsy -----------------------

DROP TABLE IF EXISTS #ICD9GeneralizedCriteria; 
SELECT *
INTO #ICD9GeneralizedCriteria
FROM (VALUES ('345.[01]x')) AS criteria (ICD9Prefix);

DROP TABLE IF EXISTS #ICD10GeneralizedCriteria;
SELECT *
INTO #ICD10GeneralizedCriteria
FROM (VALUES ('G40.[34AB]%')) AS criteria (ICD10Prefix);

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnGeneralizedICD9;
SELECT icd.ICD9SID,
    icd.ICD9Code
INTO SCS_EEGUtil.EEG.rnGeneralizedICD9
FROM CDWWork.Dim.ICD9 icd
    INNER JOIN #ICD9GeneralizedCriteria crit
        ON icd.ICD9Code LIKE crit.ICD9Prefix
WHERE LEN(icd.ICD9Code) <= 10;

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnGeneralizedICD10;
SELECT icd.ICD10SID,
    icd.ICD10Code
INTO SCS_EEGUtil.EEG.rnGeneralizedICD10
FROM CDWWork.Dim.ICD10 icd
    INNER JOIN #ICD10GeneralizedCriteria crit
        ON icd.ICD10Code LIKE crit.ICD10Prefix
WHERE LEN(icd.ICD10Code) <= 10;

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnGeneralizedVELCRO;
WITH CombinedDx AS (
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.VDiagnosisDateTime AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Outpat.VDiagnosis' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Outpat.VDiagnosis dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnGeneralizedICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnGeneralizedICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
        WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL
    UNION ALL
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.DischargeDateTime AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Inpat.InpatientDiagnosis' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Inpat.InpatientDiagnosis dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnGeneralizedICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnGeneralizedICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
        WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL
    UNION ALL
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.CorrectInvoiceReceivedDate AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Fee.FeeServiceProvided' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Fee.FeeServiceProvided dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnGeneralizedICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnGeneralizedICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
    WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL
    UNION ALL
    SELECT pat.PatientICN,
        pat.PatientSSN,
        CAST(dx.InvoiceReceivedDateTime AS DATE) AS DxDate,
        COALESCE(icd9.ICD9Code, icd10.ICD10Code) AS ICDCode,
        'Fee.FeeInpatInvoiceICDDiagnosis' AS SourceTable
    FROM SCS_EEGUtil.EEG.sk_DRE2024v3 coh
        INNER JOIN CDWWork.SPatient.SPatient pat
            ON coh.PatientSSN = pat.PatientSSN
        INNER JOIN CDWWork.Fee.FeeInpatInvoiceICDDiagnosis dx
            ON pat.PatientSID = dx.PatientSID
        LEFT JOIN SCS_EEGUtil.EEG.rnGeneralizedICD9 icd9
            ON dx.ICD9SID = icd9.ICD9SID
        LEFT JOIN SCS_EEGUtil.EEG.rnGeneralizedICD10 icd10
            ON dx.ICD10SID = icd10.ICD10SID
    WHERE icd9.ICD9SID IS NOT NULL OR icd10.ICD10SID IS NOT NULL)
SELECT PatientICN,
    PatientSSN,
    DxDate,
    ICDCode,
    SourceTable
INTO SCS_EEGUtil.EEG.rnGeneralizedVELCRO
FROM CombinedDx;


--------------------- Exporting -----------------------

SELECT * FROM SCS_EEGUtil.EEG.rnPNESVELCRO;
SELECT * FROM SCS_EEGUtil.EEG.rnFocalVELCRO;
SELECT * FROM SCS_EEGUtil.EEG.rnGeneralizedVELCRO;