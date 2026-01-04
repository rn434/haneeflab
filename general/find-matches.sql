/*

This file finds age- and sex-mathced controls for epilepsy patients.
Patients are matched to have the same birth year and sex.

Controls are ensured to be actively followed up at the time of epilepsy diagnosis.
    - Controls must still be alive or have died after epilepsy diagnosis date
    - Controls must have had an encounter in the 12 months prior to epilepsy diagnosis

*/

WITH Cases AS (
    SELECT epi.PatientICN AS CaseICN, 
        dem.Sex, 
        epi.DxDate, 
        YEAR(dem.BirthDate) AS BirthYear
    FROM SCS_EEGUtil.EEG.rnEpilepsyComplete epi
        INNER JOIN SCS_EEGUtil.EEG.rnDemographicsAll dem
            ON epi.PatientICN = dem.PatientICN)
, Controls AS (
    SELECT dem.PatientICN AS ControlICN, 
        dem.Sex, 
        YEAR(dem.BirthDate) AS BirthYear, 
        dem.DeathDate
    FROM SCS_EEGUtil.EEG.rnDemographicsAll dem
        LEFT JOIN SCS_EEGUtil.EEG.rnEpilepsyComplete epi
            ON dem.PatientICN = epi.PatientICN
    WHERE epi.PatientICN IS NULL)
, EligibleMatches AS (
    SELECT cse.CaseICN, 
        ctrl.ControlICN
    FROM Cases cse
        INNER JOIN Controls ctrl
            ON cse.Sex = ctrl.Sex
                AND cse.BirthYear = ctrl.BirthYear
                AND (ctrl.DeathDate IS NULL OR ctrl.DeathDate >= cse.DxDate)
                AND EXISTS (
                    SELECT 1
                    FROM CDWWork.Outpat.Visit vis
                        INNER JOIN CDWWork.Patient.Patient pat
                            ON vis.PatientSID = pat.PatientSID
                    WHERE pat.PatientICN = ctrl.ControlICN
                        AND vis.VisitDateTime BETWEEN 
                            DATEADD(year, -1, cse.DxDate) AND cse.DxDate))
, RankedMatches AS (
    SELECT *, 
        ROW_NUMBER() OVER(PARTITION BY CaseICN 
            ORDER BY HASHBYTES('SHA2_256', CONCAT(CaseICN, '|', ControlICN)) AS rn_case
    FROM EligibleMatches)
, RankedOverall AS (
    SELECT CaseICN, 
        ControlICN,
        ROW_NUMBER() OVER(PARTITION BY ControlICN ORDER BY rn_case) AS rn_control
    FROM RankedMatches
    WHERE rn_case = 1)

SELECT CaseICN, ControlICN
FROM RankedOverall
WHERE rn_control = 1;
