/*

This file looks through all available diagnostic information for each patient 
and determines the earliest date at which the experienced the comorbidities 
required in the calculation of the epilepsy-specific comorbidity index (ESCI).

*/


IF OBJECT_ID('tempdb..#AllDx') IS NULL
    BEGIN
        EXEC CreateTempTable;
    END
;


DROP TABLE IF EXISTS 
    #ESCIDx
;
SELECT
    coh.PatientICN,
    merged.PatientSID,
    merged.PulmCirc,
    merged.HTN,
    merged.Arrhy,
    merged.CHF,
    merged.Vasc,
    merged.Renal,
    merged.Tumor,
    merged.Plegia,
    merged.Aspir,
    merged.Demen,
    merged.BrainTumor,
    merged.AnoxicBrain,
    merged.ModSevLiver,
    merged.MetCancer
INTO
    #ESCIDx
FROM (
    SELECT
        dx.PatientSID,
        CASE
            WHEN icd.PulmCirc = 1 THEN dx.DxDate
            ELSE NULL
        END AS PulmCirc,
        CASE
            WHEN icd.HTN = 1 THEN dx.DxDate
            ELSE NULL
        END AS HTN,
        CASE
            WHEN icd.Arrhy = 1 THEN dx.DxDate
            ELSE NULL
        END AS Arrhy,
        CASE
            WHEN icd.CHF = 1 THEN dx.DxDate
            ELSE NULL
        END AS CHF,
        CASE
            WHEN icd.Vasc = 1 THEN dx.DxDate
            ELSE NULL
        END AS Vasc,
        CASE
            WHEN icd.Renal = 1 THEN dx.DxDate
            ELSE NULL
        END AS Renal,
        CASE
            WHEN icd.Tumor = 1 THEN dx.DxDate
            ELSE NULL
        END AS Tumor,
        CASE
            WHEN icd.Plegia = 1 THEN dx.DxDate
            ELSE NULL
        END AS Plegia,
        CASE
            WHEN icd.Aspir = 1 THEN dx.DxDate
            ELSE NULL
        END AS Aspir,
        CASE
            WHEN icd.Demen = 1 THEN dx.DxDate
            ELSE NULL
        END AS Demen,
        CASE
            WHEN icd.BrainTumor = 1 THEN dx.DxDate
            ELSE NULL
        END AS BrainTumor,
        CASE
            WHEN icd.AnoxicBrain = 1 THEN dx.DxDate
            ELSE NULL
        END AS AnoxicBrain,
        CASE
            WHEN icd.ModSevLiver = 1 THEN dx.DxDate
            ELSE NULL
        END AS ModSevLiver,
        CASE
            WHEN icd.MetCancer = 1 THEN dx.DxDate
            ELSE NULL
        END AS MetCancer
    FROM 
        #AllDx dx
        INNER JOIN 
        ORD_Haneef_202402056D.Dflt.rnESCIICD9 icd
            ON dx.ICD9SID = icd.ICD9SID
    
    UNION ALL

    SELECT
        dx.PatientSID,
        CASE
            WHEN icd.PulmCirc = 1 THEN dx.DxDate
            ELSE NULL
        END AS PulmCirc,
        CASE
            WHEN icd.HTN = 1 THEN dx.DxDate
            ELSE NULL
        END AS HTN,
        CASE
            WHEN icd.Arrhy = 1 THEN dx.DxDate
            ELSE NULL
        END AS Arrhy,
        CASE
            WHEN icd.CHF = 1 THEN dx.DxDate
            ELSE NULL
        END AS CHF,
        CASE
            WHEN icd.Vasc = 1 THEN dx.DxDate
            ELSE NULL
        END AS Vasc,
        CASE
            WHEN icd.Renal = 1 THEN dx.DxDate
            ELSE NULL
        END AS Renal,
        CASE
            WHEN icd.Tumor = 1 THEN dx.DxDate
            ELSE NULL
        END AS Tumor,
        CASE
            WHEN icd.Plegia = 1 THEN dx.DxDate
            ELSE NULL
        END AS Plegia,
        CASE
            WHEN icd.Aspir = 1 THEN dx.DxDate
            ELSE NULL
        END AS Aspir,
        CASE
            WHEN icd.Demen = 1 THEN dx.DxDate
            ELSE NULL
        END AS Demen,
        CASE
            WHEN icd.BrainTumor = 1 THEN dx.DxDate
            ELSE NULL
        END AS BrainTumor,
        CASE
            WHEN icd.AnoxicBrain = 1 THEN dx.DxDate
            ELSE NULL
        END AS AnoxicBrain,
        CASE
            WHEN icd.ModSevLiver = 1 THEN dx.DxDate
            ELSE NULL
        END AS ModSevLiver,
        CASE
            WHEN icd.MetCancer = 1 THEN dx.DxDate
            ELSE NULL
        END AS MetCancer
    FROM 
        #AllDx dx
        INNER JOIN 
        ORD_Haneef_202402056D.Dflt.rnESCIICD10 icd
            ON dx.ICD10SID = icd.ICD10SID
) merged
    FULL OUTER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        merged.PatientSID = coh.PatientSID
;

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnESCIDates
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnESCIDates (
        PatientICN VARCHAR(10) PRIMARY KEY,
        PulmCirc DATE,
        HTN DATE,
        Arrhy DATE,
        CHF DATE,
        Vasc DATE,
        Renal DATE,
        Tumor DATE,
        Plegia DATE,
        Aspir DATE,
        Demen DATE,
        BrainTumor DATE,
        AnoxicBrain DATE,
        ModSevLiver DATE,
        MetCancer DATE
    )
;
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnESCIDates (
        PatientICN,
        PulmCirc,
        HTN,
        Arrhy,
        CHF,
        Vasc,
        Renal,
        Tumor,
        Plegia,
        Aspir,
        Demen,
        BrainTumor,
        AnoxicBrain,
        ModSevLiver,
        MetCancer
    )
SELECT
    dx.PatientICN,
    MIN(dx.PulmCirc) AS PulmCirc,
    MIN(dx.HTN) AS HTN,
    MIN(dx.Arrhy) AS Arrhy,
    MIN(dx.CHF) AS CHF,
    MIN(dx.Vasc) AS Vasc,
    MIN(dx.Renal) AS Renal,
    MIN(dx.Tumor) AS Tumor,
    MIN(dx.Plegia) AS Plegia,
    MIN(dx.Aspir) AS Aspir,
    MIN(dx.Demen) AS Demen,
    MIN(dx.BrainTumor) AS BrainTumor,
    MIN(dx.AnoxicBrain) AS AnoxicBrain,
    MIN(dx.ModSevLiver) AS ModSevLiver,
    MIN(dx.MetCancer) AS MetCancer
FROM
    #ESCIDx dx
GROUP BY
    dx.PatientICN
;

