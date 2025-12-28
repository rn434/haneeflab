/*

This file calculates important metrics regarding the cohort.

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
    CDWWork.RxOut.RxOutpat fill
    INNER JOIN
    #Cenobamate cen
        ON
        fill.LocalDrugSID = cen.LocalDrugSID
    INNER JOIN
    CDWWork.Patient.Patient coh
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
    ORD_Haneef_202402056D.Dflt.rnCenobamateMissing
;
SELECT DISTINCT
    cen.PatientICN,
    spat.PatientName
INTO
    ORD_Haneef_202402056D.Dflt.rnCenobamateMissing
FROM
    #CenobamateFills cen
    INNER JOIN
    CDWWork.SPatient.SPatient spat
        ON
        cen.PatientICN = spat.PatientICN
    LEFT JOIN
    ORD_Haneef_202402056D.Dflt.rnCenobamate2024 coh
        ON
        cen.PatientICN = coh.PatientICN

WHERE
    coh.PatientICN IS NULL
;

SELECT 
    * 
FROM 
    ORD_Haneef_202402056D.Dflt.rnCenobamateMissing cen
INNER JOIN
    CDWWork.SPatient.SPatient spat
    ON cen.PatientICN = spat.PatientICN
;