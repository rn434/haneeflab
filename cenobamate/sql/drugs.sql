/*

This file gathers a listing of all drugs each patient in the cenobamate
cohort has taken in the past. A table named NonCenobamateDrugs will be
created containing the following columns:

    * PatientICN
    * Drug
        + This will be the VA Product Name
    * InitialDate
        + This is the first date they filled a specific drug and strength

*/

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnNonCenobamateDrugs
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnNonCenobamateDrugs (
        PatientICN VARCHAR(10),    
        Drug VARCHAR(25),
        InitialDate DATE
    )
;

INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnNonCenobamateDrugs (
        PatientICN,    
        Drug,
        InitialDate
    )
SELECT
    coh.PatientICN,
    -- drug.VAProductName AS Drug,
    fill.DrugNameWithoutDose AS Drug,
    MIN(fill.IssueDate) AS InitialDate
FROM
    ORD_Haneef_202402056D.Dflt.rnCenobamate2024 cen
    INNER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        cen.PatientICN = coh.PatientICN
    INNER JOIN
    ORD_Haneef_202402056D.Src.RxOut_RxOutpatFill fill
        ON
        coh.PatientSID = fill.PatientSID
    -- INNER JOIN
    -- CDWWork.Dim.LocalDrug drug
    --     ON
    --     fill.LocalDrugSID = drug.LocalDrugSID
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnASD asd
        ON
        fill.LocalDrugSID = asd.LocalDrugSID
GROUP BY
    coh.PatientICN,
    fill.DrugNameWithoutDose
    -- drug.VAProductName
;
