/* 
combine all records from tables and only use icd-10 codes with A last modifier to ensure that first occurrences are captured, not just histories

simplified criteria
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

DROP TABLE IF EXISTS
    #EpilepsyDx
;
SELECT
    merged.PatientICN,
    merged.PatientSID,
    merged.DxDate,
    merged.ServiceConnectedFlag
INTO
    #EpilepsyDx
FROM (
    SELECT
        dx.PatientICN,
        dx.PatientSID,
        dx.DxDate,
        dx.ServiceConnectedFlag,
        icd.DxType
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
        dx.ServiceConnectedFlag,
        icd.DxType
    FROM
        #AllDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnSeizureICD10 icd
            ON
            dx.ICD10SID = icd.ICD10SID
) merged
WHERE
    merged.DxType = 'Epilepsy'
;

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnCohort2
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnCohort2 (
        PatientICN VARCHAR(10) PRIMARY KEY,
        DxDate DATE,
        ServiceConnectedFlag BIT
    )
;
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnCohort2 (
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
        PatientICN,
        DxDate,
        ServiceConnectedFlag,
        ROW_NUMBER() OVER (PARTITION BY PatientICN ORDER BY DxDate, ServiceConnectedFlag DESC) AS rn
    FROM 
        #EpilepsyDx
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
WHERE
    merged.OccurrenceType != 'History'
;

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnTBI2
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnTBI2 (
        PatientICN VARCHAR(10) PRIMARY KEY,
        TBIDate DATE,
        TBIClass2 VARCHAR(20),
        OccurrenceType VARCHAR(20)
    )
;
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnTBI2 (
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
    ORD_Haneef_202402056D.Dflt.rnCohort2 coh
        ON
        elix.PatientICN = coh.PatientICN
;

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnECI2
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnECI2 (
        PatientICN VARCHAR(10) PRIMARY KEY,
        ECI INT
    )
;
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnECI2 (
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
    ORD_Haneef_202402056D.Dflt.rnCohort2 coh
        ON
        es.PatientICN = coh.PatientICN
;

DROP TABLE IF EXISTS
    ORD_Haneef_202402056D.Dflt.rnESI2
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnESI2 (
        PatientICN VARCHAR(10) PRIMARY KEY,
        ESI INT
    )
;
INSERT INTO
    ORD_Haneef_202402056D.Dflt.rnESI2 (
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
    ORD_Haneef_202402056D.Dflt.rnCohortInfo2
;
CREATE TABLE 
    ORD_Haneef_202402056D.Dflt.rnCohortInfo2 (
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
    ORD_Haneef_202402056D.Dflt.rnCohortInfo2 (
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
    ORD_Haneef_202402056D.Dflt.rnCohort2 coh
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnDemographics dem
        ON
        coh.PatientICN = dem.PatientICN
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnECI2 eci
        ON
        coh.PatientICN = eci.PatientICN
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnESI2 esi
        ON
        coh.PatientICN = esi.PatientICN
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnLatest latest
        ON
        coh.PatientICN = latest.PatientICN
    LEFT JOIN
    ORD_Haneef_202402056D.Dflt.rnTBI2 tbi
        ON
        coh.PatientICN = tbi.PatientICN
;

