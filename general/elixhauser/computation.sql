/*

This file defines a function that computes the Elixhauser comorbidity index 
(ECI) for each patient prior to a given date. The weights are chosen according 
to those provided in Moore et al. (2017).

*/

DROP TABLE IF EXISTS #ECIWeights;
SELECT
    9 AS CHF,
    0 AS Arrhy,
    0 AS Valv,
    6 AS PulmCirc,
    3 AS Vasc,
    -1 AS HTN,
    5 AS Para,
    5 AS Neuro,
    3 AS PulmChronic,
    0 AS DiabUnc,
    -3 AS DiabC,
    0 AS Hypothy,
    6 AS RenFail,
    4 AS Liver,
    0 AS Peptic,
    0 AS AIDS,
    6 AS Lymphoma,
    14 AS MetCancer,
    7 AS Tumor,
    0 AS Rheum,
    11 AS Coag,
    -5 AS Obesity,
    9 AS WLoss,
    11 AS Fluid,
    -3 AS Blood,
    -2 AS Deficiency,
    -1 AS Alcohol,
    -7 AS Drug,
    -5 AS Psych,
    -5 AS Depress
INTO
    #ECIWeights
;
    
DROP TABLE IF EXISTS #BinaryECI;
SELECT
    elix.PatientICN,
    CASE WHEN elix.CHF < epi.DxDate THEN 1 ELSE 0 END AS CHF,
    CASE WHEN elix.Arrhy < epi.DxDate THEN 1 ELSE 0 END AS Arrhy,
    CASE WHEN elix.Valv < epi.DxDate THEN 1 ELSE 0 END AS Valv,
    CASE WHEN elix.PulmCirc < epi.DxDate THEN 1 ELSE 0 END AS PulmCirc,
    CASE WHEN elix.Vasc < epi.DxDate THEN 1 ELSE 0 END AS Vasc,
    CASE WHEN elix.HTN < epi.DxDate THEN 1 ELSE 0 END AS HTN,
    CASE WHEN elix.Para < epi.DxDate THEN 1 ELSE 0 END AS Para,
    CASE WHEN elix.Neuro < epi.DxDate THEN 1 ELSE 0 END AS Neuro,
    CASE WHEN elix.PulmChronic < epi.DxDate THEN 1 ELSE 0 END AS PulmChronic,
    CASE WHEN elix.DiabUnc < epi.DxDate THEN 1 ELSE 0 END AS DiabUnc,
    CASE WHEN elix.DiabC < epi.DxDate THEN 1 ELSE 0 END AS DiabC,
    CASE WHEN elix.Hypothy < epi.DxDate THEN 1 ELSE 0 END AS Hypothy,
    CASE WHEN elix.RenFail < epi.DxDate THEN 1 ELSE 0 END AS RenFail,
    CASE WHEN elix.Liver < epi.DxDate THEN 1 ELSE 0 END AS Liver,
    CASE WHEN elix.Peptic < epi.DxDate THEN 1 ELSE 0 END AS Peptic,
    CASE WHEN elix.AIDS < epi.DxDate THEN 1 ELSE 0 END AS AIDS,
    CASE WHEN elix.Lymphoma < epi.DxDate THEN 1 ELSE 0 END AS Lymphoma,
    CASE WHEN elix.MetCancer < epi.DxDate THEN 1 ELSE 0 END AS MetCancer,
    CASE WHEN elix.Tumor < epi.DxDate THEN 1 ELSE 0 END AS Tumor,
    CASE WHEN elix.Rheum < epi.DxDate THEN 1 ELSE 0 END AS Rheum,
    CASE WHEN elix.Coag < epi.DxDate THEN 1 ELSE 0 END AS Coag,
    CASE WHEN elix.Obesity < epi.DxDate THEN 1 ELSE 0 END AS Obesity,
    CASE WHEN elix.WLoss < epi.DxDate THEN 1 ELSE 0 END AS WLoss,
    CASE WHEN elix.Fluid < epi.DxDate THEN 1 ELSE 0 END AS Fluid,
    CASE WHEN elix.Blood < epi.DxDate THEN 1 ELSE 0 END AS Blood,
    CASE WHEN elix.Deficiency < epi.DxDate THEN 1 ELSE 0 END AS Deficiency,
    CASE WHEN elix.Alcohol < epi.DxDate THEN 1 ELSE 0 END AS Alcohol,
    CASE WHEN elix.Drug < epi.DxDate THEN 1 ELSE 0 END AS Drug,
    CASE WHEN elix.Psych < epi.DxDate THEN 1 ELSE 0 END AS Psych,
    CASE WHEN elix.Depress < epi.DxDate THEN 1 ELSE 0 END AS Depress
INTO
    #BinaryECI
FROM
    SCS_EEGUtil.EEG.rnElixhauserDates elix
    INNER JOIN SCS_EEGUtil.EEG.rnEpilepsy epi
        ON elix.PatientICN = epi.PatientICN
;

SELECT
    elix.PatientICN,
    (
        elix.CHF * w.CHF +
        elix.Arrhy * w.Arrhy +
        elix.Valv * w.Valv +
        elix.PulmCirc * w.PulmCirc +
        elix.Vasc * w.Vasc +
        elix.HTN * w.HTN +
        elix.Para * w.Para +
        elix.Neuro * w.Neuro +
        elix.PulmChronic * w.PulmChronic +
        elix.DiabUnc * w.DiabUnc +
        elix.DiabC * w.DiabC +
        elix.Hypothy * w.Hypothy +
        elix.RenFail * w.RenFail +
        elix.Liver * w.Liver +
        elix.Peptic * w.Peptic +
        elix.AIDS * w.AIDS +
        elix.Lymphoma * w.Lymphoma +
        elix.MetCancer * w.MetCancer +
        elix.Tumor * w.Tumor +
        elix.Rheum * w.Rheum +
        elix.Coag * w.Coag +
        elix.Obesity * w.Obesity +
        elix.WLoss * w.WLoss +
        elix.Fluid * w.Fluid +
        elix.Blood * w.Blood +
        elix.Deficiency * w.Deficiency +
        elix.Alcohol * w.Alcohol +
        elix.Drug * w.Drug +
        elix.Psych * w.Psych +
        elix.Depress * w.Depress
    ) AS ECI
INTO
    SCS_EEGUtil.EEG.rnElixhauser
FROM
    #BinaryECI elix
    CROSS JOIN #ECIWeights w
;



