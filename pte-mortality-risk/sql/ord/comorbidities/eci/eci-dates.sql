/*

This file looks through all available diagnostic information for each patient 
and determines the earliest date at which the experienced the comorbidities 
required in the calculation of the Elixhauser comorbidity index (ECI).

*/


IF OBJECT_ID('tempdb..#AllDx') IS NULL
    BEGIN
        EXEC CreateTempTable;
    END
;


DROP TABLE IF EXISTS 
    #ECIDx
;
SELECT
    coh.PatientICN,
    merged.PatientSID,
    merged.CHF,
    merged.Arrhy,
    merged.Valv,
    merged.PulmCirc,
    merged.Vasc,
    merged.HTN,
    merged.Para,
    merged.Neuro,
    merged.PulmChronic,
    merged.DiabUnc,
    merged.DiabC,
    merged.Hypothy,
    merged.RenFail,
    merged.Liver,
    merged.Peptic,
    merged.AIDS,
    merged.Lymphoma,
    merged.MetCancer,
    merged.Tumor,
    merged.Rheum,
    merged.Coag,
    merged.Obesity,
    merged.WLoss,
    merged.Fluid,
    merged.Blood,
    merged.Deficiency,
    merged.Alcohol,
    merged.Drug,
    merged.Psych,
    merged.Depress
INTO
    #ECIDx
FROM (
    SELECT
        dx.PatientSID,
        CASE
            WHEN icd.CHF = 1 THEN dx.DxDate
            ELSE NULL
        END AS CHF,
        CASE
            WHEN icd.Arrhy = 1 THEN dx.DxDate
            ELSE NULL
        END AS Arrhy,
        CASE
            WHEN icd.Valv = 1 THEN dx.DxDate
            ELSE NULL
        END AS Valv,
        CASE
            WHEN icd.PulmCirc = 1 THEN dx.DxDate
            ELSE NULL
        END AS PulmCirc,
        CASE
            WHEN icd.Vasc = 1 THEN dx.DxDate
            ELSE NULL
        END AS Vasc,
        CASE
            WHEN icd.HTN = 1 THEN dx.DxDate
            ELSE NULL
        END AS HTN,
        CASE
            WHEN icd.Para = 1 THEN dx.DxDate
            ELSE NULL
        END AS Para,
        CASE
            WHEN icd.Neuro = 1 THEN dx.DxDate
            ELSE NULL
        END AS Neuro,
        CASE
            WHEN icd.PulmChronic = 1 THEN dx.DxDate
            ELSE NULL
        END AS PulmChronic,
        CASE
            WHEN icd.DiabUnc = 1 THEN dx.DxDate
            ELSE NULL
        END AS DiabUnc,
        CASE
            WHEN icd.DiabC = 1 THEN dx.DxDate
            ELSE NULL
        END AS DiabC,
        CASE
            WHEN icd.Hypothy = 1 THEN dx.DxDate
            ELSE NULL
        END AS Hypothy,
        CASE
            WHEN icd.RenFail = 1 THEN dx.DxDate
            ELSE NULL
        END AS RenFail,
        CASE
            WHEN icd.Liver = 1 THEN dx.DxDate
            ELSE NULL
        END AS Liver,
        CASE
            WHEN icd.Peptic = 1 THEN dx.DxDate
            ELSE NULL
        END AS Peptic,
        CASE
            WHEN icd.AIDS = 1 THEN dx.DxDate
            ELSE NULL
        END AS AIDS,
        CASE
            WHEN icd.Lymphoma = 1 THEN dx.DxDate
            ELSE NULL
        END AS Lymphoma,
        CASE
            WHEN icd.MetCancer = 1 THEN dx.DxDate
            ELSE NULL
        END AS MetCancer,
        CASE
            WHEN icd.Tumor = 1 THEN dx.DxDate
            ELSE NULL
        END AS Tumor,
        CASE
            WHEN icd.Rheum = 1 THEN dx.DxDate
            ELSE NULL
        END AS Rheum,
        CASE
            WHEN icd.Coag = 1 THEN dx.DxDate
            ELSE NULL
        END AS Coag,
        CASE
            WHEN icd.Obesity = 1 THEN dx.DxDate
            ELSE NULL
        END AS Obesity,
        CASE
            WHEN icd.WLoss = 1 THEN dx.DxDate
            ELSE NULL
        END AS WLoss,
        CASE
            WHEN icd.Fluid = 1 THEN dx.DxDate
            ELSE NULL
        END AS Fluid,
        CASE
            WHEN icd.Blood = 1 THEN dx.DxDate
            ELSE NULL
        END AS Blood,
        CASE
            WHEN icd.Deficiency = 1 THEN dx.DxDate
            ELSE NULL
        END AS Deficiency,
        CASE
            WHEN icd.Alcohol = 1 THEN dx.DxDate
            ELSE NULL
        END AS Alcohol,
        CASE
            WHEN icd.Drug = 1 THEN dx.DxDate
            ELSE NULL
        END AS Drug,
        CASE
            WHEN icd.Psych = 1 THEN dx.DxDate
            ELSE NULL
        END AS Psych,
        CASE
            WHEN icd.Depress = 1 THEN dx.DxDate
            ELSE NULL
        END AS Depress
    FROM 
        #AllDx dx
        INNER JOIN 
        ORD_Haneef_202402056D.Dflt.rnECIICD9 icd
            ON dx.ICD9SID = icd.ICD9SID
    
    UNION ALL

    SELECT
        dx.PatientSID,
        CASE
            WHEN icd.CHF = 1 THEN dx.DxDate
            ELSE NULL
        END AS CHF,
        CASE
            WHEN icd.Arrhy = 1 THEN dx.DxDate
            ELSE NULL
        END AS Arrhy,
        CASE
            WHEN icd.Valv = 1 THEN dx.DxDate
            ELSE NULL
        END AS Valv,
        CASE
            WHEN icd.PulmCirc = 1 THEN dx.DxDate
            ELSE NULL
        END AS PulmCirc,
        CASE
            WHEN icd.Vasc = 1 THEN dx.DxDate
            ELSE NULL
        END AS Vasc,
        CASE
            WHEN icd.HTN = 1 THEN dx.DxDate
            ELSE NULL
        END AS HTN,
        CASE
            WHEN icd.Para = 1 THEN dx.DxDate
            ELSE NULL
        END AS Para,
        CASE
            WHEN icd.Neuro = 1 THEN dx.DxDate
            ELSE NULL
        END AS Neuro,
        CASE
            WHEN icd.PulmChronic = 1 THEN dx.DxDate
            ELSE NULL
        END AS PulmChronic,
        CASE
            WHEN icd.DiabUnc = 1 THEN dx.DxDate
            ELSE NULL
        END AS DiabUnc,
        CASE
            WHEN icd.DiabC = 1 THEN dx.DxDate
            ELSE NULL
        END AS DiabC,
        CASE
            WHEN icd.Hypothy = 1 THEN dx.DxDate
            ELSE NULL
        END AS Hypothy,
        CASE
            WHEN icd.RenFail = 1 THEN dx.DxDate
            ELSE NULL
        END AS RenFail,
        CASE
            WHEN icd.Liver = 1 THEN dx.DxDate
            ELSE NULL
        END AS Liver,
        CASE
            WHEN icd.Peptic = 1 THEN dx.DxDate
            ELSE NULL
        END AS Peptic,
        CASE
            WHEN icd.AIDS = 1 THEN dx.DxDate
            ELSE NULL
        END AS AIDS,
        CASE
            WHEN icd.Lymphoma = 1 THEN dx.DxDate
            ELSE NULL
        END AS Lymphoma,
        CASE
            WHEN icd.MetCancer = 1 THEN dx.DxDate
            ELSE NULL
        END AS MetCancer,
        CASE
            WHEN icd.Tumor = 1 THEN dx.DxDate
            ELSE NULL
        END AS Tumor,
        CASE
            WHEN icd.Rheum = 1 THEN dx.DxDate
            ELSE NULL
        END AS Rheum,
        CASE
            WHEN icd.Coag = 1 THEN dx.DxDate
            ELSE NULL
        END AS Coag,
        CASE
            WHEN icd.Obesity = 1 THEN dx.DxDate
            ELSE NULL
        END AS Obesity,
        CASE
            WHEN icd.WLoss = 1 THEN dx.DxDate
            ELSE NULL
        END AS WLoss,
        CASE
            WHEN icd.Fluid = 1 THEN dx.DxDate
            ELSE NULL
        END AS Fluid,
        CASE
            WHEN icd.Blood = 1 THEN dx.DxDate
            ELSE NULL
        END AS Blood,
        CASE
            WHEN icd.Deficiency = 1 THEN dx.DxDate
            ELSE NULL
        END AS Deficiency,
        CASE
            WHEN icd.Alcohol = 1 THEN dx.DxDate
            ELSE NULL
        END AS Alcohol,
        CASE
            WHEN icd.Drug = 1 THEN dx.DxDate
            ELSE NULL
        END AS Drug,
        CASE
            WHEN icd.Psych = 1 THEN dx.DxDate
            ELSE NULL
        END AS Psych,
        CASE
            WHEN icd.Depress = 1 THEN dx.DxDate
            ELSE NULL
        END AS Depress
    FROM 
        #AllDx dx
        INNER JOIN 
        ORD_Haneef_202402056D.Dflt.rnECIICD10 icd
            ON dx.ICD10SID = icd.ICD10SID
) merged
    FULL OUTER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        merged.PatientSID = coh.PatientSID
;

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnECIDates
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnECIDates (
        PatientICN VARCHAR(10) PRIMARY KEY,
        CHF DATE,
        Arrhy DATE,
        Valv DATE,
        PulmCirc DATE,
        Vasc DATE,
        HTN DATE,
        Para DATE,
        Neuro DATE,
        PulmChronic DATE,
        DiabUnc DATE,
        DiabC DATE,
        Hypothy DATE,
        RenFail DATE,
        Liver DATE,
        Peptic DATE,
        AIDS DATE,
        Lymphoma DATE,
        MetCancer DATE,
        Tumor DATE,
        Rheum DATE,
        Coag DATE,
        Obesity DATE,
        WLoss DATE,
        Fluid DATE,
        Blood DATE,
        Deficiency DATE,
        Alcohol DATE,
        Drug DATE,
        Psych DATE,
        Depress DATE
    )
;
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnECIDates (
        PatientICN,
        CHF,
        Arrhy,
        Valv,
        PulmCirc,
        Vasc,
        HTN,
        Para,
        Neuro,
        PulmChronic,
        DiabUnc,
        DiabC,
        Hypothy,
        RenFail,
        Liver,
        Peptic,
        AIDS,
        Lymphoma,
        MetCancer,
        Tumor,
        Rheum,
        Coag,
        Obesity,
        WLoss,
        Fluid,
        Blood,
        Deficiency,
        Alcohol,
        Drug,
        Psych,
        Depress
    )
SELECT
    dx.PatientICN,
    MIN(dx.CHF) AS CHF,
    MIN(dx.Arrhy) AS Arrhy,
    MIN(dx.Valv) AS Valv,
    MIN(dx.PulmCirc) AS PulmCirc,
    MIN(dx.Vasc) AS Vasc,
    MIN(dx.HTN) AS HTN,
    MIN(dx.Para) AS Para,
    MIN(dx.Neuro) AS Neuro,
    MIN(dx.PulmChronic) AS PulmChronic,
    MIN(dx.DiabUnc) AS DiabUnc,
    MIN(dx.DiabC) AS DiabC,
    MIN(dx.Hypothy) AS Hypothy,
    MIN(dx.RenFail) AS RenFail,
    MIN(dx.Liver) AS Liver,
    MIN(dx.Peptic) AS Peptic,
    MIN(dx.AIDS) AS AIDS,
    MIN(dx.Lymphoma) AS Lymphoma,
    MIN(dx.MetCancer) AS MetCancer,
    MIN(dx.Tumor) AS Tumor,
    MIN(dx.Rheum) AS Rheum,
    MIN(dx.Coag) AS Coag,
    MIN(dx.Obesity) AS Obesity,
    MIN(dx.WLoss) AS WLoss,
    MIN(dx.Fluid) AS Fluid,
    MIN(dx.Blood) AS Blood,
    MIN(dx.Deficiency) AS Deficiency,
    MIN(dx.Alcohol) AS Alcohol,
    MIN(dx.Drug) AS Drug,
    MIN(dx.Psych) AS Psych,
    MIN(dx.Depress) AS Depress
FROM
    #ECIDx dx
GROUP BY
    dx.PatientICN
;

