/*

This file creates a subset of CDWWork.Dim.StopCode for use in excluding
diagnostic EEG (106) and LTM (128) clinics.

*/


DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnStopCode;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnStopCode (
    StopCodeSID INT PRIMARY KEY,
    StopCode INT
)
;
INSERT INTO ORD_Haneef_202402056D.Dflt.rnStopCode (
    StopCodeSID,
    StopCode
)
SELECT
    StopCodeSID,
    StopCode
FROM
    CDWWork.Dim.StopCode
WHERE
    StopCode IN (106, 128)
;


