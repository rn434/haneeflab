/*

This file builds a cohort of patients treated with cenobamate from
2020 - 2024.

411 PatientICNs in ORD_Haneef
421 PatientICNs in CDWWork

Estimated runtime = 

*/

DROP TABLE IF EXISTS
    #Cenobamate
;
SELECT
    drug.LocalDrugSID,
    drug.VAProductName AS ProductName
INTO
    #Cenobamate
FROM
    CDWWork.Dim.LocalDrug drug
WHERE
    drug.VAProductName LIKE 'cenobamate'
    OR
    drug.VAProductName LIKE 'cenobamate %'
    OR
    drug.VAProductName LIKE '% cenobamate'
    OR
    drug.VAProductName LIKE '% cenobamate %'
;

DROP TABLE IF EXISTS
    #CenobamateFills
;
SELECT
    coh.PatientICN,
    MIN(fill.IssueDate) AS IssueDate
INTO
    #CenobamateFills
FROM
    ORD_Haneef_202402056D.Src.RxOut_RxOutpat fill
    INNER JOIN
    #Cenobamate cen
        ON
        fill.LocalDrugSID = cen.LocalDrugSID
    INNER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        fill.PatientSID = coh.PatientSID
WHERE
    -- fill.DaysSupply >= 30
    -- AND
    fill.IssueDate BETWEEN '2020-01-01' AND '2024-12-31'
GROUP BY
    coh.PatientICN
;

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnCenobamate2024
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnCenobamate2024 (
        PatientICN VARCHAR(10) PRIMARY KEY,    
        IssueDate DATE,
        BirthDate DATE,
        DeathDate DATE,
        Gender VARCHAR(1),
        Race VARCHAR(50),
        Ethnicity VARCHAR(50)
    )
;

INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnCenobamate2024 (
        PatientICN,    
        IssueDate,
        BirthDate,
        DeathDate,
        Gender,
        Race,
        Ethnicity
    )
SELECT
    cen.PatientICN,       
    cen.IssueDate, 
    dem.BirthDate,
    dem.DeathDate,
    dem.Gender,
    dem.Race,
    dem.Ethnicity
FROM 
    #CenobamateFills cen
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnDemographics dem
        ON
        cen.PatientICN = dem.PatientICN
;

