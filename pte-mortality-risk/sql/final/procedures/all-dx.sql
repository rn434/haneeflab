/*

This file creates a stored procedure that aggregates diagnosis data from the 
following sources:

    * Outpatient VDiagnosis
    * Fee Initial Treatment + Fee Service Provided
    * Inpatient Diagnosis
    * Fee Inpatient Invoice
    * Inpatient Fee Diagnosis

*/

USE ORD_Haneef_202402056D;
GO

CREATE PROCEDURE Dflt.AggregateDx
AS
BEGIN
    SELECT
        merged.PatientSID,
        merged.DxDate,
        merged.ICD9SID,
        merged.ICD10SID
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
END;
