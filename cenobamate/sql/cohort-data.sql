/*

This file gathers all the data regarding the cenobamate cohort into
one table for easy querying from R

*/

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnCenobamateCohortData
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnCenobamateCohortData (
        PatientICN VARCHAR(10),    
        CenobamateDate DATE,
        OtherDrug VARCHAR(25),
        OtherDrugDate DATE,
        BirthDate DATE,
        DeathDate DATE,
        Gender VARCHAR(1),
        Race VARCHAR(50),
        Ethnicity VARCHAR(50)
    )
;

INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnCenobamateCohortData (
        PatientICN,    
        CenobamateDate,
        OtherDrug,
        OtherDrugDate,
        BirthDate,
        DeathDate,
        Gender,
        Race,
        Ethnicity
    )
SELECT 
    cen.PatientICN,
    cen.IssueDate AS CenobamateDate,
    non.Drug AS OtherDrug,
    non.InitialDate AS OtherDrugDate,
    cen.BirthDate,
    cen.DeathDate,
    cen.Gender,
    cen.Race,
    cen.Ethnicity
FROM 
    ORD_Haneef_202402056D.Dflt.rnCenobamate2024 cen 
    INNER JOIN 
    ORD_Haneef_202402056D.Dflt.rnNonCenobamateDrugs non 
        ON 
        cen.PatientICN = non.PatientICN
;