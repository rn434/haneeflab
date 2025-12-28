/*

This file defines a function that computes the Elixhauser comorbidity index 
(ECI) for each patient prior to a given date. The weights are chosen according 
to those provided in Moore et al. (2017).

*/


USE ORD_Haneef_202402056D;
GO

CREATE PROCEDURE Dflt.ComputeECI
    @TableName NVARCHAR(128)
AS
BEGIN
    -- DECLARE @SQL NVARCHAR(MAX);

    -- SET @SQL = '
    -- SELECT 
    --     PatientICN,
    --     IndexDate
    -- INTO
    --     #IndexDate
    -- FROM 
    --     ' + QUOTENAME(@TableName) + '
    -- ;';
    
    -- EXEC sp_executesql @SQL;
    
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
        CASE WHEN elix.CHF <= dt.IndexDate THEN 1 ELSE 0 END AS CHF,
        CASE WHEN elix.Arrhy <= dt.IndexDate THEN 1 ELSE 0 END AS Arrhy,
        CASE WHEN elix.Valv <= dt.IndexDate THEN 1 ELSE 0 END AS Valv,
        CASE WHEN elix.PulmCirc <= dt.IndexDate THEN 1 ELSE 0 END AS PulmCirc,
        CASE WHEN elix.Vasc <= dt.IndexDate THEN 1 ELSE 0 END AS Vasc,
        CASE WHEN elix.HTN <= dt.IndexDate THEN 1 ELSE 0 END AS HTN,
        CASE WHEN elix.Para <= dt.IndexDate THEN 1 ELSE 0 END AS Para,
        CASE WHEN elix.Neuro <= dt.IndexDate THEN 1 ELSE 0 END AS Neuro,
        CASE WHEN elix.PulmChronic <= dt.IndexDate THEN 1 ELSE 0 END AS PulmChronic,
        CASE WHEN elix.DiabUnc <= dt.IndexDate THEN 1 ELSE 0 END AS DiabUnc,
        CASE WHEN elix.DiabC <= dt.IndexDate THEN 1 ELSE 0 END AS DiabC,
        CASE WHEN elix.Hypothy <= dt.IndexDate THEN 1 ELSE 0 END AS Hypothy,
        CASE WHEN elix.RenFail <= dt.IndexDate THEN 1 ELSE 0 END AS RenFail,
        CASE WHEN elix.Liver <= dt.IndexDate THEN 1 ELSE 0 END AS Liver,
        CASE WHEN elix.Peptic <= dt.IndexDate THEN 1 ELSE 0 END AS Peptic,
        CASE WHEN elix.AIDS <= dt.IndexDate THEN 1 ELSE 0 END AS AIDS,
        CASE WHEN elix.Lymphoma <= dt.IndexDate THEN 1 ELSE 0 END AS Lymphoma,
        CASE WHEN elix.MetCancer <= dt.IndexDate THEN 1 ELSE 0 END AS MetCancer,
        CASE WHEN elix.Tumor <= dt.IndexDate THEN 1 ELSE 0 END AS Tumor,
        CASE WHEN elix.Rheum <= dt.IndexDate THEN 1 ELSE 0 END AS Rheum,
        CASE WHEN elix.Coag <= dt.IndexDate THEN 1 ELSE 0 END AS Coag,
        CASE WHEN elix.Obesity <= dt.IndexDate THEN 1 ELSE 0 END AS Obesity,
        CASE WHEN elix.WLoss <= dt.IndexDate THEN 1 ELSE 0 END AS WLoss,
        CASE WHEN elix.Fluid <= dt.IndexDate THEN 1 ELSE 0 END AS Fluid,
        CASE WHEN elix.Blood <= dt.IndexDate THEN 1 ELSE 0 END AS Blood,
        CASE WHEN elix.Deficiency <= dt.IndexDate THEN 1 ELSE 0 END AS Deficiency,
        CASE WHEN elix.Alcohol <= dt.IndexDate THEN 1 ELSE 0 END AS Alcohol,
        CASE WHEN elix.Drug <= dt.IndexDate THEN 1 ELSE 0 END AS Drug,
        CASE WHEN elix.Psych <= dt.IndexDate THEN 1 ELSE 0 END AS Psych,
        CASE WHEN elix.Depress <= dt.IndexDate THEN 1 ELSE 0 END AS Depress
    INTO
        #BinaryECI
    FROM
        ORD_Haneef_202402056D.Dflt.rnECIDates elix
        INNER JOIN
        ##EpilepsyDxDate dt
            ON
            elix.PatientICN = dt.PatientICN
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
    FROM
        #BinaryECI elix
        CROSS JOIN
        #ECIWeights w
    ;
END;



