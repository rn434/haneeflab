/* 
combine all records from tables and only use icd-10 codes with A last modifier to ensure that first occurrences are captured, not just histories

-- Population: Patients with post-traumatic epilepsy AND patients with epilepsy that is not classified as post-traumatic epilepsy 
-- Epilepsy criteria: 
-- (1) Two or more outpatient visits on different dates with a seizure-related diagnosis (i.e., International Classification of Diseases, Tenth Edition, Clinical Modification [ICD-10-CM] codes G40.*, R40.4, R56.1, and R56.9); 
-- (2) One or more inpatient visits with an epilepsy-related diagnosis (ICD-10-CM codes G40.*); 
-- (3) ³ 30 days of an anti-seizure medication (ASM) prescription the index year and a seizure-related diagnosis with the index year or the previous two years 
--     
-- PTE criteria: Any single TBI ICD code which prior to first meeting the diagnosis of epilepsy 

*/

-- 0. Gather all diagnoses (estimated runtime = 7 m.)

DROP TABLE IF EXISTS
    #OutpatientDx
;
SELECT
    coh.PatientICN,
    merged.PatientSID,
    merged.DxDate,
    merged.ICD9SID,
    merged.ICD10SID,
    merged.ServiceConnectedFlag
INTO
    #OutpatientDx
FROM (
    SELECT
        PatientSID,
        CAST(VDiagnosisDateTime AS DATE) AS DxDate,
        ICD9SID,
        ICD10SID,
        CASE
            WHEN ServiceConnectedFlag = 'Y' THEN 1
            ELSE 0
        END AS ServiceConnectedFlag
    FROM
        ORD_Haneef_202402056D.Src.Outpat_VDiagnosis

    UNION ALL

    SELECT
        fit.PatientSID,
        CAST(fit.InitialTreatmentDateTime AS DATE) AS DxDate,
        fsp.ICD9SID,
        fsp.ICD10SID,
        CASE
            WHEN fsp.ServiceConnectedCondition = 'Y' THEN 1
            WHEN fsp.ServiceConnectedCondition = '1' THEN 1
            ELSE 0
        END AS ServiceConnectedFlag
    FROM
        ORD_Haneef_202402056D.Src.Fee_FeeInitialTreatment fit
        INNER JOIN
        ORD_Haneef_202402056D.Src.Fee_FeeServiceProvided fsp
            ON
            fit.FeeInitialTreatmentSID = fsp.FeeInitialTreatmentSID
) merged
    INNER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        merged.PatientSID = coh.PatientSID
;

DROP TABLE IF EXISTS
    #InpatientDx
;
SELECT
    coh.PatientICN,
    merged.PatientSID,
    merged.DxDate,
    merged.ICD9SID,
    merged.ICD10SID,
    merged.ServiceConnectedFlag
INTO
    #InpatientDx
FROM (
    SELECT
        inpat.PatientSID,
        CAST(inpat.AdmitDateTime AS DATE) AS DxDate,
        diag.ICD9SID,
        diag.ICD10SID,
        CASE
            WHEN inpat.ServiceConnectedFlag = 'Y' THEN 1
            ELSE 0
        END AS ServiceConnectedFlag
    FROM
        ORD_Haneef_202402056D.Src.Inpat_Inpatient inpat
        INNER JOIN
        ORD_Haneef_202402056D.Src.Inpat_InpatientDiagnosis diag
            ON
            inpat.InpatientSID = diag.InpatientSID

    UNION ALL

    SELECT
        fii.PatientSID,
        CAST(fii.TreatmentFromDateTime AS DATE) AS DxDate,
        diag.ICD9SID,
        diag.ICD10SID,
        0 AS ServiceConnectedFlag
    FROM
        ORD_Haneef_202402056D.Src.Fee_FeeInpatInvoice fii
        INNER JOIN
        ORD_Haneef_202402056D.Src.Fee_FeeInpatInvoiceICDDiagnosis diag
            ON
            fii.FeeInpatInvoiceSID = diag.FeeInpatInvoiceSID

    UNION ALL

    SELECT
        PatientSID,
        CAST(AdmitDateTime AS DATE) AS DxDate,
        ICD9SID,
        ICD10SID,
        0 AS ServiceConnectedFlag
    FROM
        ORD_Haneef_202402056D.Src.Inpat_InpatientFeeDiagnosis
) merged
    INNER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        merged.PatientSID = coh.PatientSID
;

DROP TABLE IF EXISTS
    #AllDx
;
SELECT
    sq.*
INTO
    #AllDx
FROM (
    SELECT
        PatientICN,
        PatientSID,
        DxDate,
        ICD9SID,
        ICD10SID,
        ServiceConnectedFlag
    FROM
        #OutpatientDx

    UNION ALL

    SELECT
        PatientICN,
        PatientSID,
        DxDate,
        ICD9SID,
        ICD10SID,
        ServiceConnectedFlag
    FROM
        #InpatientDx
) sq
;

-- 1. Match epilepsy criteria (estimated runtime = x)

-- 1a. Two or more outpatient visits on different dates with a seizure-related diagnosis (estimated runtime = <1 m.)

DROP TABLE IF EXISTS
    #OutpatientSeizureDx
;
SELECT
    merged.PatientICN,
    merged.PatientSID,
    merged.DxDate,
    merged.ServiceConnectedFlag
INTO
    #OutpatientSeizureDx
FROM (
    SELECT
        dx.PatientICN,
        dx.PatientSID,
        dx.DxDate,
        dx.ServiceConnectedFlag
    FROM
        #OutpatientDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnSeizureICD9 icd
            ON
            dx.ICD9SID = icd.ICD9SID
    
    UNION ALL

    SELECT
        dx.PatientICN,
        dx.PatientSID,
        dx.DxDate,
        dx.ServiceConnectedFlag
    FROM
        #OutpatientDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnSeizureICD10 icd
            ON
            dx.ICD10SID = icd.ICD10SID
) merged
;
    
DROP TABLE IF EXISTS
    #OutpatientCriteriaMatch
;
SELECT
    sq.PatientICN,
    sq.ServiceConnectedFlag,
    sq.DxDate
INTO
    #OutpatientCriteriaMatch
FROM (
    SELECT 
        PatientICN,
        DxDate,
        ServiceConnectedFlag,
        DENSE_RANK() OVER (PARTITION BY PatientICN ORDER BY DxDate) AS rank,
        ROW_NUMBER() OVER (PARTITION BY PatientICN, DxDate ORDER BY ServiceConnectedFlag DESC) AS rn
    FROM 
        #OutpatientSeizureDx
) sq
WHERE
    sq.rank = 2
    AND
    sq.rn = 1
;

-- 1b. One or more inpatient visits with an epilepsy-related diagnosis (estimated runtime = <1 m.)

DROP TABLE IF EXISTS
    #InpatientEpilepsyDx
;
SELECT
    merged.PatientICN,
    merged.PatientSID,
    merged.DxDate,
    merged.ServiceConnectedFlag
INTO
    #InpatientEpilepsyDx
FROM (
    SELECT
        dx.PatientICN,
        dx.PatientSID,
        dx.DxDate,
        dx.ServiceConnectedFlag,
        icd.DxType
    FROM
        #InpatientDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnSeizureICD9 icd
            ON
            dx.ICD9SID = icd.ICD9SID
    
    UNION ALL

    SELECT
        dx.PatientICN,
        dx.PatientSID,
        dx.DxDate,
        dx.ServiceConnectedFlag,
        icd.DxType
    FROM
        #InpatientDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnSeizureICD10 icd
            ON
            dx.ICD10SID = icd.ICD10SID
) merged
WHERE
    merged.DxType = 'Epilepsy'
;

DROP TABLE IF EXISTS
    #InpatientCriteriaMatch
;
SELECT
    sq.PatientICN,
    sq.DxDate,
    sq.ServiceConnectedFlag
INTO
    #InpatientCriteriaMatch
FROM (
    SELECT 
        PatientICN,
        DxDate,
        ServiceConnectedFlag,
        ROW_NUMBER() OVER (PARTITION BY PatientICN ORDER BY DxDate, ServiceConnectedFlag DESC) AS rn
    FROM 
        #InpatientEpilepsyDx
) sq
WHERE
    sq.rn = 1
;

-- 1c. 30 days of an anti-seizure medication (ASM) prescription the index year and a seizure-related diagnosis with the index year or the previous two years (estimated runtime = 5 m.)

DROP TABLE IF EXISTS
    #ASMFills
;
SELECT
    coh.PatientICN,
    fill.PatientSID,
    CAST(fill.FillDateTime AS DATE) AS FillDate,
    CASE
        WHEN rx.ServiceConnectedFlag = 'Y' THEN 1
        WHEN rx.ServiceConnectedFlag = '1' THEN 1
        ELSE 0
    END AS ServiceConnectedFlag
INTO
    #ASMFills
FROM
    ORD_Haneef_202402056D.Src.RxOut_RxOutpat rx
    INNER JOIN
    ORD_Haneef_202402056D.Src.RxOut_RxOutpatFill fill
        ON
        rx.RxOutpatSID = fill.RxOutpatSID
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnASM asm
        ON
        fill.LocalDrugSID = asm.LocalDrugSID
    INNER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        fill.PatientSID = coh.PatientSID
WHERE
    fill.DaysSupply >= 30
;

DROP TABLE IF EXISTS
    #AllSeizureDx
;
SELECT
    merged.PatientICN,
    merged.PatientSID,
    merged.DxDate,
    merged.ServiceConnectedFlag
INTO
    #AllSeizureDx
FROM (
    SELECT
        dx.PatientICN,
        dx.PatientSID,
        dx.DxDate,
        dx.ServiceConnectedFlag
    FROM
        #AllDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnSeizureICD9 icd
            ON
            dx.ICD9SID = icd.ICD9SID
    
    UNION ALL

    SELECT
        dx.PatientICN,
        dx.PatientSID,
        dx.DxDate,
        dx.ServiceConnectedFlag
    FROM
        #AllDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnSeizureICD10 icd
            ON
            dx.ICD10SID = icd.ICD10SID
) merged
;

DROP TABLE IF EXISTS
    #ASMCriteriaMatch
;
SELECT
    sq.PatientICN,
    sq.FillDate AS DxDate,
    sq.ServiceConnectedFlag
INTO
    #ASMCriteriaMatch
FROM (
    SELECT
        fill.PatientICN,
        fill.FillDate,
        fill.ServiceConnectedFlag,
        ROW_NUMBER() OVER (PARTITION BY fill.PatientICN ORDER BY fill.FillDate, fill.ServiceConnectedFlag DESC) AS rn
    FROM
        #ASMFills fill
        INNER JOIN
        #AllSeizureDx dx
            ON
            fill.PatientSID = dx.PatientSID
    WHERE
        (YEAR(fill.FillDate) - YEAR(dx.DxDate)) BETWEEN 0 AND 2 --not accounting for date
) sq
WHERE
    sq.rn = 1
;

-- 1d. Find DxDate for all patients (estimated runtime = x)

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnCohort
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnCohort (
        PatientICN VARCHAR(10) PRIMARY KEY,
        DxDate DATE,
        ServiceConnectedFlag BIT
    )
;
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnCohort (
        PatientICN,
        DxDate,
        ServiceConnectedFlag
    )
SELECT
    sq.PatientICN,
    sq.DxDate,
    sq.ServiceConnectedFlag
FROM (
    SELECT
        merged.PatientICN,
        merged.DxDate,
        merged.ServiceConnectedFlag,
        ROW_NUMBER() OVER (PARTITION BY merged.PatientICN ORDER BY merged.DxDate, merged.ServiceConnectedFlag DESC) AS rn
    FROM (
        SELECT
            PatientICN,
            DxDate,
            ServiceConnectedFlag
        FROM
            #OutpatientCriteriaMatch
            
        UNION ALL
            
        SELECT
            PatientICN,
            DxDate,
            ServiceConnectedFlag
        FROM
            #InpatientCriteriaMatch
            
        UNION ALL
            
        SELECT
            PatientICN,
            DxDate,
            ServiceConnectedFlag
        FROM
            #ASMCriteriaMatch
    ) merged
) sq
WHERE
    sq.rn = 1
;


-- 2. Find date of TBI (estimated runtime = <1 m.)

DROP TABLE IF EXISTS
    #TBIDx
;
SELECT
    merged.PatientICN,
    merged.PatientSID,
    merged.DxDate,
    merged.TBIClass2,
    merged.OccurrenceType
INTO
    #TBIDx
FROM (
    SELECT
        dx.PatientICN,
        dx.PatientSID,
        dx.DxDate,
        icd.TBIClass2,
        icd.OccurrenceType
    FROM
        #AllDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnTBIICD9 icd
            ON
            dx.ICD9SID = icd.ICD9SID
    
    UNION ALL

    SELECT
        dx.PatientICN,
        dx.PatientSID,
        dx.DxDate,
        icd.TBIClass2,
        icd.OccurrenceType
    FROM
        #AllDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnTBIICD10 icd
            ON
            dx.ICD10SID = icd.ICD10SID
) merged
;

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnTBI
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnTBI (
        PatientICN VARCHAR(10) PRIMARY KEY,
        TBIDate DATE,
        TBIClass2 VARCHAR(20),
        OccurrenceType VARCHAR(20)
    )
;
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnTBI (
        PatientICN,
        TBIDate,
        TBIClass2,
        OccurrenceType
    )
SELECT
    sq.PatientICN,
    sq.DxDate AS TBIDate,
    sq.TBIClass2,
    sq.OccurrenceType
FROM (
    SELECT 
        PatientICN,
        DxDate,
        TBIClass2,
        OccurrenceType,
        ROW_NUMBER() OVER (PARTITION BY PatientICN ORDER BY DxDate) AS rn
    FROM 
        #TBIDx
) sq
WHERE
    sq.rn = 1
;

-- 3. Demographics (estimated runtime = <1 m.)

DROP TABLE IF EXISTS 
    #Demographics
;
SELECT
    coh.PatientICN,
    CAST(spat.BirthDateTime AS DATE) AS BirthDate,
    CAST(spat.DeathDateTime AS DATE) AS DeathDate,
    spat.Gender, -- this is sex
    race.Race,
    eth.Ethnicity
INTO 
    #Demographics
FROM 
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
    FULL OUTER JOIN 
        ORD_Haneef_202402056D.Src.SPatient_SPatient spat
        ON 
        coh.PatientSID = spat.PatientSID
    FULL OUTER JOIN 
        ORD_Haneef_202402056D.Src.PatSub_PatientRace race
        ON 
        coh.PatientSID = race.PatientSID
    FULL OUTER JOIN 
        ORD_Haneef_202402056D.Src.PatSub_PatientEthnicity eth
        ON 
        coh.PatientSID = eth.PatientSID
;

DROP TABLE IF EXISTS
    #BirthDateCounts
;
SELECT
    dem.PatientICN,
    dem.BirthDate,
    COUNT(*) AS BirthDateCount
INTO
    #BirthDateCounts
FROM
    #Demographics dem
WHERE 
    dem.BirthDate IS NOT NULL
GROUP BY
    dem.PatientICN,
    dem.BirthDate
;

DROP TABLE IF EXISTS
    #BirthDateMode
;
SELECT
    sq.PatientICN,
    sq.BirthDate
INTO
    #BirthDateMode
FROM (
    SELECT
        cnt.PatientICN,
        cnt.BirthDate,
        ROW_NUMBER() OVER (PARTITION BY cnt.PatientICN ORDER BY cnt.BirthDateCount DESC) rn
    FROM
        #BirthDateCounts cnt
) sq
WHERE
    sq.rn = 1
;

DROP TABLE IF EXISTS
    #DeathDateCounts
;
SELECT
    dem.PatientICN,
    dem.DeathDate,
    COUNT(*) AS DeathDateCount
INTO
    #DeathDateCounts
FROM
    #Demographics dem
WHERE 
    dem.DeathDate IS NOT NULL
GROUP BY
    dem.PatientICN,
    dem.DeathDate
;

DROP TABLE IF EXISTS
    #DeathDateMode
;
SELECT
    sq.PatientICN,
    sq.DeathDate
INTO
    #DeathDateMode
FROM (
    SELECT
        cnt.PatientICN,
        cnt.DeathDate,
        ROW_NUMBER() OVER (PARTITION BY cnt.PatientICN ORDER BY cnt.DeathDateCount DESC) rn
    FROM
        #DeathDateCounts cnt
) sq
WHERE
    sq.rn = 1
;

DROP TABLE IF EXISTS
    #GenderCounts
;
SELECT
    dem.PatientICN,
    dem.Gender,
    COUNT(*) AS GenderCount
INTO
    #GenderCounts
FROM
    #Demographics dem
WHERE 
    dem.Gender IS NOT NULL
GROUP BY
    dem.PatientICN,
    dem.Gender
;

DROP TABLE IF EXISTS
    #GenderMode
;
SELECT
    sq.PatientICN,
    sq.Gender
INTO
    #GenderMode
FROM (
    SELECT
        cnt.PatientICN,
        cnt.Gender,
        ROW_NUMBER() OVER (PARTITION BY cnt.PatientICN ORDER BY cnt.GenderCount DESC) rn
    FROM
        #GenderCounts cnt
) sq
WHERE
    sq.rn = 1
;

DROP TABLE IF EXISTS
    #RaceCounts
;
SELECT
    dem.PatientICN,
    dem.Race,
    COUNT(*) AS RaceCount
INTO
    #RaceCounts
FROM
    #Demographics dem
WHERE 
    dem.Race IS NOT NULL
GROUP BY
    dem.PatientICN,
    dem.Race
;

DROP TABLE IF EXISTS
    #RaceMode
;
SELECT
    sq.PatientICN,
    sq.Race
INTO
    #RaceMode
FROM (
    SELECT
        cnt.PatientICN,
        cnt.Race,
        ROW_NUMBER() OVER (PARTITION BY cnt.PatientICN ORDER BY cnt.RaceCount DESC) rn
    FROM
        #RaceCounts cnt
) sq
WHERE
    sq.rn = 1
;

DROP TABLE IF EXISTS
    #EthnicityCounts
;
SELECT
    dem.PatientICN,
    dem.Ethnicity,
    COUNT(*) AS EthnicityCount
INTO
    #EthnicityCounts
FROM
    #Demographics dem
WHERE 
    dem.Ethnicity IS NOT NULL
GROUP BY
    dem.PatientICN,
    dem.Ethnicity
;

DROP TABLE IF EXISTS
    #EthnicityMode
;
SELECT
    sq.PatientICN,
    sq.Ethnicity
INTO
    #EthnicityMode
FROM (
    SELECT
        cnt.PatientICN,
        cnt.Ethnicity,
        ROW_NUMBER() OVER (PARTITION BY cnt.PatientICN ORDER BY cnt.EthnicityCount DESC) rn
    FROM
        #EthnicityCounts cnt
) sq
WHERE
    sq.rn = 1
;

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnDemographics
;
CREATE TABLE
    ORD_Haneef_202402056D.Dflt.rnDemographics (
        PatientICN VARCHAR(10) PRIMARY KEY,
        BirthDate DATE,
        DeathDate DATE,
        Gender VARCHAR(1),
        Race VARCHAR(50),
        Ethnicity VARCHAR(50)
    )
;
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnDemographics (
        PatientICN,
        BirthDate,
        DeathDate,
        Gender,
        Race,
        Ethnicity
    )
SELECT
    birth.PatientICN,
    birth.BirthDate,
    death.DeathDate,
    gender.Gender,
    race.Race,
    ethnicity.Ethnicity
FROM
    #BirthDateMode birth
    FULL OUTER JOIN
    #DeathDateMode death
        ON
        birth.PatientICN = death.PatientICN
    FULL OUTER JOIN
    #GenderMode gender
        ON
        birth.PatientICN = gender.PatientICN
    FULL OUTER JOIN
    #RaceMode race
        ON
        birth.PatientICN = race.PatientICN
    FULL OUTER JOIN
    #EthnicityMode ethnicity
        ON
        birth.PatientICN = ethnicity.PatientICN
;

-- 4. Elixhauser comorbidities (estimated runtime = 5 m.)

DROP TABLE IF EXISTS 
    #ElixhauserDx
;
SELECT
    coh.PatientICN,
    merged.PatientSID,
    merged.CHF,
    merged.Arrhy,
    merged.Valv,
    merged.PulmCirc,
    merged.Vasc,
    merged.HTN,
    merged.Para,
    merged.Neuro,
    merged.PulmChronic,
    merged.DiabUnc,
    merged.DiabC,
    merged.Hypothy,
    merged.RenFail,
    merged.Liver,
    merged.Peptic,
    merged.AIDS,
    merged.Lymphoma,
    merged.MetCancer,
    merged.Tumor,
    merged.Rheum,
    merged.Coag,
    merged.Obesity,
    merged.WLoss,
    merged.Fluid,
    merged.Blood,
    merged.Deficiency,
    merged.Alcohol,
    merged.Drug,
    merged.Psych,
    merged.Depress
INTO
    #ElixhauserDx
FROM (
    SELECT
        dx.PatientSID,
        CASE
            WHEN icd.CHF = 1 THEN dx.DxDate
            ELSE NULL
        END AS CHF,
        CASE
            WHEN icd.Arrhy = 1 THEN dx.DxDate
            ELSE NULL
        END AS Arrhy,
        CASE
            WHEN icd.Valv = 1 THEN dx.DxDate
            ELSE NULL
        END AS Valv,
        CASE
            WHEN icd.PulmCirc = 1 THEN dx.DxDate
            ELSE NULL
        END AS PulmCirc,
        CASE
            WHEN icd.Vasc = 1 THEN dx.DxDate
            ELSE NULL
        END AS Vasc,
        CASE
            WHEN icd.HTN = 1 THEN dx.DxDate
            ELSE NULL
        END AS HTN,
        CASE
            WHEN icd.Para = 1 THEN dx.DxDate
            ELSE NULL
        END AS Para,
        CASE
            WHEN icd.Neuro = 1 THEN dx.DxDate
            ELSE NULL
        END AS Neuro,
        CASE
            WHEN icd.PulmChronic = 1 THEN dx.DxDate
            ELSE NULL
        END AS PulmChronic,
        CASE
            WHEN icd.DiabUnc = 1 THEN dx.DxDate
            ELSE NULL
        END AS DiabUnc,
        CASE
            WHEN icd.DiabC = 1 THEN dx.DxDate
            ELSE NULL
        END AS DiabC,
        CASE
            WHEN icd.Hypothy = 1 THEN dx.DxDate
            ELSE NULL
        END AS Hypothy,
        CASE
            WHEN icd.RenFail = 1 THEN dx.DxDate
            ELSE NULL
        END AS RenFail,
        CASE
            WHEN icd.Liver = 1 THEN dx.DxDate
            ELSE NULL
        END AS Liver,
        CASE
            WHEN icd.Peptic = 1 THEN dx.DxDate
            ELSE NULL
        END AS Peptic,
        CASE
            WHEN icd.AIDS = 1 THEN dx.DxDate
            ELSE NULL
        END AS AIDS,
        CASE
            WHEN icd.Lymphoma = 1 THEN dx.DxDate
            ELSE NULL
        END AS Lymphoma,
        CASE
            WHEN icd.MetCancer = 1 THEN dx.DxDate
            ELSE NULL
        END AS MetCancer,
        CASE
            WHEN icd.Tumor = 1 THEN dx.DxDate
            ELSE NULL
        END AS Tumor,
        CASE
            WHEN icd.Rheum = 1 THEN dx.DxDate
            ELSE NULL
        END AS Rheum,
        CASE
            WHEN icd.Coag = 1 THEN dx.DxDate
            ELSE NULL
        END AS Coag,
        CASE
            WHEN icd.Obesity = 1 THEN dx.DxDate
            ELSE NULL
        END AS Obesity,
        CASE
            WHEN icd.WLoss = 1 THEN dx.DxDate
            ELSE NULL
        END AS WLoss,
        CASE
            WHEN icd.Fluid = 1 THEN dx.DxDate
            ELSE NULL
        END AS Fluid,
        CASE
            WHEN icd.Blood = 1 THEN dx.DxDate
            ELSE NULL
        END AS Blood,
        CASE
            WHEN icd.Deficiency = 1 THEN dx.DxDate
            ELSE NULL
        END AS Deficiency,
        CASE
            WHEN icd.Alcohol = 1 THEN dx.DxDate
            ELSE NULL
        END AS Alcohol,
        CASE
            WHEN icd.Drug = 1 THEN dx.DxDate
            ELSE NULL
        END AS Drug,
        CASE
            WHEN icd.Psych = 1 THEN dx.DxDate
            ELSE NULL
        END AS Psych,
        CASE
            WHEN icd.Depress = 1 THEN dx.DxDate
            ELSE NULL
        END AS Depress
    FROM 
        #AllDx dx
        INNER JOIN 
        ORD_Haneef_202402056D.Dflt.rnElixhauserICD9 icd
            ON dx.ICD9SID = icd.ICD9SID
    
    UNION ALL

    SELECT
        dx.PatientSID,
        CASE
            WHEN icd.CHF = 1 THEN dx.DxDate
            ELSE NULL
        END AS CHF,
        CASE
            WHEN icd.Arrhy = 1 THEN dx.DxDate
            ELSE NULL
        END AS Arrhy,
        CASE
            WHEN icd.Valv = 1 THEN dx.DxDate
            ELSE NULL
        END AS Valv,
        CASE
            WHEN icd.PulmCirc = 1 THEN dx.DxDate
            ELSE NULL
        END AS PulmCirc,
        CASE
            WHEN icd.Vasc = 1 THEN dx.DxDate
            ELSE NULL
        END AS Vasc,
        CASE
            WHEN icd.HTN = 1 THEN dx.DxDate
            ELSE NULL
        END AS HTN,
        CASE
            WHEN icd.Para = 1 THEN dx.DxDate
            ELSE NULL
        END AS Para,
        CASE
            WHEN icd.Neuro = 1 THEN dx.DxDate
            ELSE NULL
        END AS Neuro,
        CASE
            WHEN icd.PulmChronic = 1 THEN dx.DxDate
            ELSE NULL
        END AS PulmChronic,
        CASE
            WHEN icd.DiabUnc = 1 THEN dx.DxDate
            ELSE NULL
        END AS DiabUnc,
        CASE
            WHEN icd.DiabC = 1 THEN dx.DxDate
            ELSE NULL
        END AS DiabC,
        CASE
            WHEN icd.Hypothy = 1 THEN dx.DxDate
            ELSE NULL
        END AS Hypothy,
        CASE
            WHEN icd.RenFail = 1 THEN dx.DxDate
            ELSE NULL
        END AS RenFail,
        CASE
            WHEN icd.Liver = 1 THEN dx.DxDate
            ELSE NULL
        END AS Liver,
        CASE
            WHEN icd.Peptic = 1 THEN dx.DxDate
            ELSE NULL
        END AS Peptic,
        CASE
            WHEN icd.AIDS = 1 THEN dx.DxDate
            ELSE NULL
        END AS AIDS,
        CASE
            WHEN icd.Lymphoma = 1 THEN dx.DxDate
            ELSE NULL
        END AS Lymphoma,
        CASE
            WHEN icd.MetCancer = 1 THEN dx.DxDate
            ELSE NULL
        END AS MetCancer,
        CASE
            WHEN icd.Tumor = 1 THEN dx.DxDate
            ELSE NULL
        END AS Tumor,
        CASE
            WHEN icd.Rheum = 1 THEN dx.DxDate
            ELSE NULL
        END AS Rheum,
        CASE
            WHEN icd.Coag = 1 THEN dx.DxDate
            ELSE NULL
        END AS Coag,
        CASE
            WHEN icd.Obesity = 1 THEN dx.DxDate
            ELSE NULL
        END AS Obesity,
        CASE
            WHEN icd.WLoss = 1 THEN dx.DxDate
            ELSE NULL
        END AS WLoss,
        CASE
            WHEN icd.Fluid = 1 THEN dx.DxDate
            ELSE NULL
        END AS Fluid,
        CASE
            WHEN icd.Blood = 1 THEN dx.DxDate
            ELSE NULL
        END AS Blood,
        CASE
            WHEN icd.Deficiency = 1 THEN dx.DxDate
            ELSE NULL
        END AS Deficiency,
        CASE
            WHEN icd.Alcohol = 1 THEN dx.DxDate
            ELSE NULL
        END AS Alcohol,
        CASE
            WHEN icd.Drug = 1 THEN dx.DxDate
            ELSE NULL
        END AS Drug,
        CASE
            WHEN icd.Psych = 1 THEN dx.DxDate
            ELSE NULL
        END AS Psych,
        CASE
            WHEN icd.Depress = 1 THEN dx.DxDate
            ELSE NULL
        END AS Depress
    FROM 
        #AllDx dx
        INNER JOIN 
        ORD_Haneef_202402056D.Dflt.rnElixhauserICD10 icd
            ON dx.ICD10SID = icd.ICD10SID
) merged
    FULL OUTER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        merged.PatientSID = coh.PatientSID
;

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnElixhauserDates
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnElixhauserDates (
        PatientICN VARCHAR(10) PRIMARY KEY,
        CHF DATE,
        Arrhy DATE,
        Valv DATE,
        PulmCirc DATE,
        Vasc DATE,
        HTN DATE,
        Para DATE,
        Neuro DATE,
        PulmChronic DATE,
        DiabUnc DATE,
        DiabC DATE,
        Hypothy DATE,
        RenFail DATE,
        Liver DATE,
        Peptic DATE,
        AIDS DATE,
        Lymphoma DATE,
        MetCancer DATE,
        Tumor DATE,
        Rheum DATE,
        Coag DATE,
        Obesity DATE,
        WLoss DATE,
        Fluid DATE,
        Blood DATE,
        Deficiency DATE,
        Alcohol DATE,
        Drug DATE,
        Psych DATE,
        Depress DATE
    )
;
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnElixhauserDates (
        PatientICN,
        CHF,
        Arrhy,
        Valv,
        PulmCirc,
        Vasc,
        HTN,
        Para,
        Neuro,
        PulmChronic,
        DiabUnc,
        DiabC,
        Hypothy,
        RenFail,
        Liver,
        Peptic,
        AIDS,
        Lymphoma,
        MetCancer,
        Tumor,
        Rheum,
        Coag,
        Obesity,
        WLoss,
        Fluid,
        Blood,
        Deficiency,
        Alcohol,
        Drug,
        Psych,
        Depress
    )
SELECT
    dx.PatientICN,
    MIN(dx.CHF) AS CHF,
    MIN(dx.Arrhy) AS Arrhy,
    MIN(dx.Valv) AS Valv,
    MIN(dx.PulmCirc) AS PulmCirc,
    MIN(dx.Vasc) AS Vasc,
    MIN(dx.HTN) AS HTN,
    MIN(dx.Para) AS Para,
    MIN(dx.Neuro) AS Neuro,
    MIN(dx.PulmChronic) AS PulmChronic,
    MIN(dx.DiabUnc) AS DiabUnc,
    MIN(dx.DiabC) AS DiabC,
    MIN(dx.Hypothy) AS Hypothy,
    MIN(dx.RenFail) AS RenFail,
    MIN(dx.Liver) AS Liver,
    MIN(dx.Peptic) AS Peptic,
    MIN(dx.AIDS) AS AIDS,
    MIN(dx.Lymphoma) AS Lymphoma,
    MIN(dx.MetCancer) AS MetCancer,
    MIN(dx.Tumor) AS Tumor,
    MIN(dx.Rheum) AS Rheum,
    MIN(dx.Coag) AS Coag,
    MIN(dx.Obesity) AS Obesity,
    MIN(dx.WLoss) AS WLoss,
    MIN(dx.Fluid) AS Fluid,
    MIN(dx.Blood) AS Blood,
    MIN(dx.Deficiency) AS Deficiency,
    MIN(dx.Alcohol) AS Alcohol,
    MIN(dx.Drug) AS Drug,
    MIN(dx.Psych) AS Psych,
    MIN(dx.Depress) AS Depress
FROM
    #ElixhauserDx dx
GROUP BY
    dx.PatientICN
;

-- 5. Epilepsy-specific comorbidities (estimated runtime = 2 m.)

DROP TABLE IF EXISTS 
    #EsDx
;
SELECT
    coh.PatientICN,
    merged.PatientSID,
    merged.PulmCirc,
    merged.HTN,
    merged.Arrhy,
    merged.CHF,
    merged.Vasc,
    merged.Renal,
    merged.Tumor,
    merged.Plegia,
    merged.Aspir,
    merged.Demen,
    merged.BrainTumor,
    merged.AnoxicBrain,
    merged.ModSevLiver,
    merged.MetCancer
INTO
    #EsDx
FROM (
    SELECT
        dx.PatientSID,
        CASE
            WHEN icd.PulmCirc = 1 THEN dx.DxDate
            ELSE NULL
        END AS PulmCirc,
        CASE
            WHEN icd.HTN = 1 THEN dx.DxDate
            ELSE NULL
        END AS HTN,
        CASE
            WHEN icd.Arrhy = 1 THEN dx.DxDate
            ELSE NULL
        END AS Arrhy,
        CASE
            WHEN icd.CHF = 1 THEN dx.DxDate
            ELSE NULL
        END AS CHF,
        CASE
            WHEN icd.Vasc = 1 THEN dx.DxDate
            ELSE NULL
        END AS Vasc,
        CASE
            WHEN icd.Renal = 1 THEN dx.DxDate
            ELSE NULL
        END AS Renal,
        CASE
            WHEN icd.Tumor = 1 THEN dx.DxDate
            ELSE NULL
        END AS Tumor,
        CASE
            WHEN icd.Plegia = 1 THEN dx.DxDate
            ELSE NULL
        END AS Plegia,
        CASE
            WHEN icd.Aspir = 1 THEN dx.DxDate
            ELSE NULL
        END AS Aspir,
        CASE
            WHEN icd.Demen = 1 THEN dx.DxDate
            ELSE NULL
        END AS Demen,
        CASE
            WHEN icd.BrainTumor = 1 THEN dx.DxDate
            ELSE NULL
        END AS BrainTumor,
        CASE
            WHEN icd.AnoxicBrain = 1 THEN dx.DxDate
            ELSE NULL
        END AS AnoxicBrain,
        CASE
            WHEN icd.ModSevLiver = 1 THEN dx.DxDate
            ELSE NULL
        END AS ModSevLiver,
        CASE
            WHEN icd.MetCancer = 1 THEN dx.DxDate
            ELSE NULL
        END AS MetCancer
    FROM 
        #AllDx dx
        INNER JOIN 
        ORD_Haneef_202402056D.Dflt.rnEsICD9 icd
            ON dx.ICD9SID = icd.ICD9SID
    
    UNION ALL

    SELECT
        dx.PatientSID,
        CASE
            WHEN icd.PulmCirc = 1 THEN dx.DxDate
            ELSE NULL
        END AS PulmCirc,
        CASE
            WHEN icd.HTN = 1 THEN dx.DxDate
            ELSE NULL
        END AS HTN,
        CASE
            WHEN icd.Arrhy = 1 THEN dx.DxDate
            ELSE NULL
        END AS Arrhy,
        CASE
            WHEN icd.CHF = 1 THEN dx.DxDate
            ELSE NULL
        END AS CHF,
        CASE
            WHEN icd.Vasc = 1 THEN dx.DxDate
            ELSE NULL
        END AS Vasc,
        CASE
            WHEN icd.Renal = 1 THEN dx.DxDate
            ELSE NULL
        END AS Renal,
        CASE
            WHEN icd.Tumor = 1 THEN dx.DxDate
            ELSE NULL
        END AS Tumor,
        CASE
            WHEN icd.Plegia = 1 THEN dx.DxDate
            ELSE NULL
        END AS Plegia,
        CASE
            WHEN icd.Aspir = 1 THEN dx.DxDate
            ELSE NULL
        END AS Aspir,
        CASE
            WHEN icd.Demen = 1 THEN dx.DxDate
            ELSE NULL
        END AS Demen,
        CASE
            WHEN icd.BrainTumor = 1 THEN dx.DxDate
            ELSE NULL
        END AS BrainTumor,
        CASE
            WHEN icd.AnoxicBrain = 1 THEN dx.DxDate
            ELSE NULL
        END AS AnoxicBrain,
        CASE
            WHEN icd.ModSevLiver = 1 THEN dx.DxDate
            ELSE NULL
        END AS ModSevLiver,
        CASE
            WHEN icd.MetCancer = 1 THEN dx.DxDate
            ELSE NULL
        END AS MetCancer
    FROM 
        #AllDx dx
        INNER JOIN 
        ORD_Haneef_202402056D.Dflt.rnEsICD10 icd
            ON dx.ICD10SID = icd.ICD10SID
) merged
    FULL OUTER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        merged.PatientSID = coh.PatientSID
;

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnEsDates
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnEsDates (
        PatientICN VARCHAR(10) PRIMARY KEY,
        PulmCirc DATE,
        HTN DATE,
        Arrhy DATE,
        CHF DATE,
        Vasc DATE,
        Renal DATE,
        Tumor DATE,
        Plegia DATE,
        Aspir DATE,
        Demen DATE,
        BrainTumor DATE,
        AnoxicBrain DATE,
        ModSevLiver DATE,
        MetCancer DATE
    )
;
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnEsDates (
        PatientICN,
        PulmCirc,
        HTN,
        Arrhy,
        CHF,
        Vasc,
        Renal,
        Tumor,
        Plegia,
        Aspir,
        Demen,
        BrainTumor,
        AnoxicBrain,
        ModSevLiver,
        MetCancer
    )
SELECT
    dx.PatientICN,
    MIN(dx.PulmCirc) AS PulmCirc,
    MIN(dx.HTN) AS HTN,
    MIN(dx.Arrhy) AS Arrhy,
    MIN(dx.CHF) AS CHF,
    MIN(dx.Vasc) AS Vasc,
    MIN(dx.Renal) AS Renal,
    MIN(dx.Tumor) AS Tumor,
    MIN(dx.Plegia) AS Plegia,
    MIN(dx.Aspir) AS Aspir,
    MIN(dx.Demen) AS Demen,
    MIN(dx.BrainTumor) AS BrainTumor,
    MIN(dx.AnoxicBrain) AS AnoxicBrain,
    MIN(dx.ModSevLiver) AS ModSevLiver,
    MIN(dx.MetCancer) AS MetCancer
FROM
    #EsDx dx
GROUP BY
    dx.PatientICN
;

-- 6. Latest follow up (estimated runtime = 1 m.)

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnLatest
;
CREATE TABLE
    ORD_Haneef_202402056D.Dflt.rnLatest (
        PatientICN VARCHAR(10) PRIMARY KEY,
        LatestFollowUpDate DATE
    )
;
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnLatest (
        PatientICN,
        LatestFollowUpDate
    )
SELECT
    PatientICN,
    MAX(DxDate) AS LatestFollowUpDate
FROM 
    #AllDx
GROUP BY
    PatientICN
;

-- 7. Calculate ECI and ESI before epilepsy diagnosis (estimated runtime = <1 m.)

-- 7a. ECI per Moore et al.

DROP TABLE IF EXISTS
    #ECIWeights
;
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
    
DROP TABLE IF EXISTS
    #BinaryElixhauser
;
SELECT
    coh.PatientICN,
    CASE WHEN elix.CHF <= coh.DxDate THEN 1 ELSE 0 END AS CHF,
    CASE WHEN elix.Arrhy <= coh.DxDate THEN 1 ELSE 0 END AS Arrhy,
    CASE WHEN elix.Valv <= coh.DxDate THEN 1 ELSE 0 END AS Valv,
    CASE WHEN elix.PulmCirc <= coh.DxDate THEN 1 ELSE 0 END AS PulmCirc,
    CASE WHEN elix.Vasc <= coh.DxDate THEN 1 ELSE 0 END AS Vasc,
    CASE WHEN elix.HTN <= coh.DxDate THEN 1 ELSE 0 END AS HTN,
    CASE WHEN elix.Para <= coh.DxDate THEN 1 ELSE 0 END AS Para,
    CASE WHEN elix.Neuro <= coh.DxDate THEN 1 ELSE 0 END AS Neuro,
    CASE WHEN elix.PulmChronic <= coh.DxDate THEN 1 ELSE 0 END AS PulmChronic,
    CASE WHEN elix.DiabUnc <= coh.DxDate THEN 1 ELSE 0 END AS DiabUnc,
    CASE WHEN elix.DiabC <= coh.DxDate THEN 1 ELSE 0 END AS DiabC,
    CASE WHEN elix.Hypothy <= coh.DxDate THEN 1 ELSE 0 END AS Hypothy,
    CASE WHEN elix.RenFail <= coh.DxDate THEN 1 ELSE 0 END AS RenFail,
    CASE WHEN elix.Liver <= coh.DxDate THEN 1 ELSE 0 END AS Liver,
    CASE WHEN elix.Peptic <= coh.DxDate THEN 1 ELSE 0 END AS Peptic,
    CASE WHEN elix.AIDS <= coh.DxDate THEN 1 ELSE 0 END AS AIDS,
    CASE WHEN elix.Lymphoma <= coh.DxDate THEN 1 ELSE 0 END AS Lymphoma,
    CASE WHEN elix.MetCancer <= coh.DxDate THEN 1 ELSE 0 END AS MetCancer,
    CASE WHEN elix.Tumor <= coh.DxDate THEN 1 ELSE 0 END AS Tumor,
    CASE WHEN elix.Rheum <= coh.DxDate THEN 1 ELSE 0 END AS Rheum,
    CASE WHEN elix.Coag <= coh.DxDate THEN 1 ELSE 0 END AS Coag,
    CASE WHEN elix.Obesity <= coh.DxDate THEN 1 ELSE 0 END AS Obesity,
    CASE WHEN elix.WLoss <= coh.DxDate THEN 1 ELSE 0 END AS WLoss,
    CASE WHEN elix.Fluid <= coh.DxDate THEN 1 ELSE 0 END AS Fluid,
    CASE WHEN elix.Blood <= coh.DxDate THEN 1 ELSE 0 END AS Blood,
    CASE WHEN elix.Deficiency <= coh.DxDate THEN 1 ELSE 0 END AS Deficiency,
    CASE WHEN elix.Alcohol <= coh.DxDate THEN 1 ELSE 0 END AS Alcohol,
    CASE WHEN elix.Drug <= coh.DxDate THEN 1 ELSE 0 END AS Drug,
    CASE WHEN elix.Psych <= coh.DxDate THEN 1 ELSE 0 END AS Psych,
    CASE WHEN elix.Depress <= coh.DxDate THEN 1 ELSE 0 END AS Depress
INTO
    #BinaryElixhauser
FROM
    ORD_Haneef_202402056D.Dflt.rnElixhauserDates elix
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnCohort coh
        ON
        elix.PatientICN = coh.PatientICN
;

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnECI
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnECI (
        PatientICN VARCHAR(10) PRIMARY KEY,
        ECI INT
    )
;
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnECI (
        PatientICN,
        ECI
    )
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
    #BinaryElixhauser elix
    CROSS JOIN
    #ECIWeights w
;

-- 7b. ESI per Germaine-Smith et al.
        
DROP TABLE IF EXISTS
    #ESIWeights
;
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
    #ESIWeights
;
    
DROP TABLE IF EXISTS
    #BinaryEs
;
SELECT
    coh.PatientICN,
    CASE WHEN es.PulmCirc <= coh.DxDate THEN 1 ELSE 0 END AS PulmCirc,
    CASE WHEN es.HTN <= coh.DxDate THEN 1 ELSE 0 END AS HTN,
    CASE WHEN es.Arrhy <= coh.DxDate THEN 1 ELSE 0 END AS Arrhy,
    CASE WHEN es.CHF <= coh.DxDate THEN 1 ELSE 0 END AS CHF,
    CASE WHEN es.Vasc <= coh.DxDate THEN 1 ELSE 0 END AS Vasc,
    CASE WHEN es.Renal <= coh.DxDate THEN 1 ELSE 0 END AS Renal,
    CASE WHEN es.Tumor <= coh.DxDate THEN 1 ELSE 0 END AS Tumor,
    CASE WHEN es.Plegia <= coh.DxDate THEN 1 ELSE 0 END AS Plegia,
    CASE WHEN es.Aspir <= coh.DxDate THEN 1 ELSE 0 END AS Aspir,
    CASE WHEN es.Demen <= coh.DxDate THEN 1 ELSE 0 END AS Demen,
    CASE WHEN es.BrainTumor <= coh.DxDate THEN 1 ELSE 0 END AS BrainTumor,
    CASE WHEN es.AnoxicBrain <= coh.DxDate THEN 1 ELSE 0 END AS AnoxicBrain,
    CASE WHEN es.ModSevLiver <= coh.DxDate THEN 1 ELSE 0 END AS ModSevLiver,
    CASE WHEN es.MetCancer <= coh.DxDate THEN 1 ELSE 0 END AS MetCancer
INTO
    #BinaryEs
FROM
    ORD_Haneef_202402056D.Dflt.rnEsDates es
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnCohort coh
        ON
        es.PatientICN = coh.PatientICN
;

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnESI
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnESI (
        PatientICN VARCHAR(10) PRIMARY KEY,
        ESI INT
    )
;
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnESI (
        PatientICN,
        ESI
    )
SELECT
    es.PatientICN,
    (
        es.PulmCirc * w.PulmCirc +
        es.HTN * w.HTN +
        es.Arrhy * w.Arrhy +
        es.CHF * w.CHF +
        es.Vasc * w.Vasc +
        es.Renal * w.Renal +
        es.Tumor * w.Tumor +
        es.Plegia * w.Plegia +
        es.Aspir * w.Aspir +
        es.Demen * w.Demen +
        es.BrainTumor * w.BrainTumor +
        es.AnoxicBrain * w.AnoxicBrain +
        es.ModSevLiver * w.ModSevLiver +
        es.MetCancer * w.MetCancer
    ) AS ESI
FROM
    #BinaryEs es
    CROSS JOIN
    #ESIWeights w
;

-- 8. Gather all cohort information (estimated runtime = )

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnCohortInfo
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnCohortInfo (
        PatientICN VARCHAR(10) PRIMARY KEY,

        DxDate DATE,
        ServiceConnectedFlag BIT,

        BirthDate DATE,
        DeathDate DATE,
        Gender VARCHAR(1),
        Race VARCHAR(50),
        Ethnicity VARCHAR(50),

        ECI INT,
        ESI INT,

        LatestFollowUpDate DATE,

        TBIDate DATE,
        TBIClass VARCHAR(20),
        TBIOccurrenceType VARCHAR (20)
    )
;
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnCohortInfo (
        PatientICN,

        DxDate,
        ServiceConnectedFlag,

        BirthDate,
        DeathDate,
        Gender,
        Race,
        Ethnicity,

        ECI,
        ESI,
        
        LatestFollowUpDate,

        TBIDate,
        TBIClass,
        TBIOccurrenceType

    )
SELECT
    coh.PatientICN,

    coh.DxDate,
    coh.ServiceConnectedFlag,

    dem.BirthDate,
    dem.DeathDate,
    dem.Gender,
    dem.Race,
    dem.Ethnicity,

    eci.ECI,
    esi.ESI,

    latest.LatestFollowUpDate,
    
    tbi.TBIDate,
    tbi.TBIClass2 AS TBIClass,
    tbi.OccurrenceType AS TBIOccurrenceType
FROM
    ORD_Haneef_202402056D.Dflt.rnCohort coh
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnDemographics dem
        ON
        coh.PatientICN = dem.PatientICN
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnECI eci
        ON
        coh.PatientICN = eci.PatientICN
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnESI esi
        ON
        coh.PatientICN = esi.PatientICN
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnLatest latest
        ON
        coh.PatientICN = latest.PatientICN
    LEFT JOIN
    ORD_Haneef_202402056D.Dflt.rnTBI tbi
        ON
        coh.PatientICN = tbi.PatientICN
;

