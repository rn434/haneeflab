/*

This file defines a function that computes the epilepsy-specific comorbidity 
index (ESCI) for each patient prior to a given date. The weights are chosen 
according to those provided in Germaine-Smith et al. (2011).

*/


USE ORD_Haneef_202402056D;
GO

CREATE PROCEDURE ComputeESCI
    @TableName NVARCHAR(128)
AS
BEGIN
    DROP TABLE IF EXISTS #ESCIWeights;
    SELECT
        1 AS PulmCirc,
        1 AS HTN,
        1 AS Arrhy,
        2 AS CHF,
        2 AS Vasc,
        2 AS Renal,
        2 AS Tumor,
        2 AS Plegia,
        2 AS Aspir,
        2 AS Demen,
        3 AS BrainTumor,
        3 AS AnoxicBrain,
        3 AS ModSevLiver,
        6 AS MetCancer
    INTO
        #ESCIWeights
    ;
        
    DROP TABLE IF EXISTS #BinaryESCI;
    SELECT
        esci.PatientICN,
        CASE WHEN esci.PulmCirc <= dt.IndexDate THEN 1 ELSE 0 END AS PulmCirc,
        CASE WHEN esci.HTN <= dt.IndexDate THEN 1 ELSE 0 END AS HTN,
        CASE WHEN esci.Arrhy <= dt.IndexDate THEN 1 ELSE 0 END AS Arrhy,
        CASE WHEN esci.CHF <= dt.IndexDate THEN 1 ELSE 0 END AS CHF,
        CASE WHEN esci.Vasc <= dt.IndexDate THEN 1 ELSE 0 END AS Vasc,
        CASE WHEN esci.Renal <= dt.IndexDate THEN 1 ELSE 0 END AS Renal,
        CASE WHEN esci.Tumor <= dt.IndexDate THEN 1 ELSE 0 END AS Tumor,
        CASE WHEN esci.Plegia <= dt.IndexDate THEN 1 ELSE 0 END AS Plegia,
        CASE WHEN esci.Aspir <= dt.IndexDate THEN 1 ELSE 0 END AS Aspir,
        CASE WHEN esci.Demen <= dt.IndexDate THEN 1 ELSE 0 END AS Demen,
        CASE WHEN esci.BrainTumor <= dt.IndexDate THEN 1 ELSE 0 END AS BrainTumor,
        CASE WHEN esci.AnoxicBrain <= dt.IndexDate THEN 1 ELSE 0 END AS AnoxicBrain,
        CASE WHEN esci.ModSevLiver <= dt.IndexDate THEN 1 ELSE 0 END AS ModSevLiver,
        CASE WHEN esci.MetCancer <= dt.IndexDate THEN 1 ELSE 0 END AS MetCancer
    INTO
        #BinaryESCI
    FROM
        ORD_Haneef_202402056D.Dflt.rnESCIDates esci
        INNER JOIN
        ##EpilepsyDxDate dt
            ON
            esci.PatientICN = dt.PatientICN
    ;

    SELECT
        esci.PatientICN,
        (
            esci.PulmCirc * w.PulmCirc +
            esci.HTN * w.HTN +
            esci.Arrhy * w.Arrhy +
            esci.CHF * w.CHF +
            esci.Vasc * w.Vasc +
            esci.Renal * w.Renal +
            esci.Tumor * w.Tumor +
            esci.Plegia * w.Plegia +
            esci.Aspir * w.Aspir +
            esci.Demen * w.Demen +
            esci.BrainTumor * w.BrainTumor +
            esci.AnoxicBrain * w.AnoxicBrain +
            esci.ModSevLiver * w.ModSevLiver +
            esci.MetCancer * w.MetCancer
        ) AS ESCI
    FROM
        #BinaryESCI esci
        CROSS JOIN
        #ESCIWeights w
    ;
END;


