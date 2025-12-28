/*

This file finds the latest date at which a patient was followed up.

*/


-- IF OBJECT_ID('tempdb..#AllDx') IS NULL
--     BEGIN
--         EXEC ...;
--     END
-- ;


DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnLatest;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnLatest (
    PatientICN VARCHAR(10) PRIMARY KEY,
    FollowUpDate DATE
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnLatest (
    PatientICN,
    FollowUpDate
)
SELECT
    PatientICN,
    MAX(DxDate) AS FollowUpDate
FROM 
    #AllDx
GROUP BY
    PatientICN
;

