/*

This file finds the oldes documented TBI for a patient using CDW and
DaVINCI data.

*/


/*

This file captures all PTE patients by looking for a diagnosis of any TBI ICD 
code in the 5 years preceding their epilepsy diagnosis.

*/

IF OBJECT_ID('tempdb..##AllDx') IS NOT NULL
    BEGIN
        PRINT 'HERE';
    END
;

DROP TABLE IF EXISTS ##AllDx;
SELECT
    merged.PatientSID,
    merged.DxDate,
    merged.ICD9SID,
    merged.ICD10SID
INTO
    ##AllDx
FROM (
    SELECT
        PatientSID,
        CAST(VDiagnosisDateTime AS DATE) AS DxDate,
        ICD9SID,
        ICD10SID
    FROM
        ORD_Haneef_202402056D.Src.Outpat_VDiagnosis

    UNION ALL

    SELECT
        fit.PatientSID,
        CAST(fit.InitialTreatmentDateTime AS DATE) AS DxDate,
        fsp.ICD9SID,
        fsp.ICD10SID
    FROM
        ORD_Haneef_202402056D.Src.Fee_FeeInitialTreatment fit
        INNER JOIN
        ORD_Haneef_202402056D.Src.Fee_FeeServiceProvided fsp
            ON
            fit.FeeInitialTreatmentSID = fsp.FeeInitialTreatmentSID

    UNION ALL

    SELECT
        inpat.PatientSID,
        CAST(inpat.AdmitDateTime AS DATE) AS DxDate,
        dx.ICD9SID,
        dx.ICD10SID
    FROM
        ORD_Haneef_202402056D.Src.Inpat_Inpatient inpat
        INNER JOIN
        ORD_Haneef_202402056D.Src.Inpat_InpatientDiagnosis dx
            ON
            inpat.InpatientSID = dx.InpatientSID

    UNION ALL

    SELECT
        fii.PatientSID,
        CAST(fii.TreatmentFromDateTime AS DATE) AS DxDate,
        dx.ICD9SID,
        dx.ICD10SID
    FROM
        ORD_Haneef_202402056D.Src.Fee_FeeInpatInvoice fii
        INNER JOIN
        ORD_Haneef_202402056D.Src.Fee_FeeInpatInvoiceICDDiagnosis dx
            ON
            fii.FeeInpatInvoiceSID = dx.FeeInpatInvoiceSID

    UNION ALL

    SELECT
        PatientSID,
        CAST(AdmitDateTime AS DATE) AS DxDate,
        ICD9SID,
        ICD10SID
    FROM
        ORD_Haneef_202402056D.Src.Inpat_InpatientFeeDiagnosis
) merged
;

-- DROP TABLE IF EXISTS ##AllDx;
-- CREATE TABLE ##AllDx (
--     PatientSID INT,
--     DxDate DATE,
--     ICD9SID INT,
--     ICD10SID INT
-- );
-- INSERT INTO ##AllDx
-- EXEC ORD_Haneef_202402056D.Dflt.AggregateDx;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnOldestTBI;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnOldestTBI (
    PatientICN VARCHAR(10) PRIMARY KEY,
    OldestTBIDate DATE
);
WITH TBIDx AS (
    SELECT
        dx.PatientSID,
        dx.DxDate AS TBIDate,
        icd.TBIClassChristensen,
        icd.TBIClassKarlander,
        icd.OccurrenceType
    FROM
        ##AllDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnTBIICD9 icd
            ON
            dx.ICD9SID = icd.ICD9SID
    
    UNION ALL

    SELECT
        dx.PatientSID,
        dx.DxDate AS TBIDate,
        icd.TBIClassChristensen,
        icd.TBIClassKarlander,
        icd.OccurrenceType
    FROM
        ##AllDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnTBIICD10 icd
            ON
            dx.ICD10SID = icd.ICD10SID
)
INSERT INTO ORD_Haneef_202402056D.Dflt.rnOldestTBI (
    PatientICN,
    OldestTBIDate
)
SELECT
    coh.PatientICN,
    MIN(tbi.TBIDate) AS OldestTBIDate
FROM
    TBIDx tbi
    INNER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        tbi.PatientSID = coh.PatientSID
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnEpilepsy epi
        ON
        coh.PatientICN = epi.PatientICN
GROUP BY
    coh.PatientICN
;
