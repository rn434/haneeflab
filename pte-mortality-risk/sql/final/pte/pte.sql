/*

This file captures all PTE patients by looking for a diagnosis of any TBI ICD 
code in the 5 years preceding their epilepsy diagnosis.

*/


DROP TABLE IF EXISTS ##AllDx;
SELECT
    merged.PatientSID,
    merged.DxDate,
    merged.ICD9SID,
    merged.ICD10SID
INTO
    ##AllDx
FROM (
    SELECT
        PatientSID,
        CAST(VDiagnosisDateTime AS DATE) AS DxDate,
        ICD9SID,
        ICD10SID
    FROM
        ORD_Haneef_202402056D.Src.Outpat_VDiagnosis

    UNION ALL

    SELECT
        fit.PatientSID,
        CAST(fit.InitialTreatmentDateTime AS DATE) AS DxDate,
        fsp.ICD9SID,
        fsp.ICD10SID
    FROM
        ORD_Haneef_202402056D.Src.Fee_FeeInitialTreatment fit
        INNER JOIN
        ORD_Haneef_202402056D.Src.Fee_FeeServiceProvided fsp
            ON
            fit.FeeInitialTreatmentSID = fsp.FeeInitialTreatmentSID

    UNION ALL

    SELECT
        inpat.PatientSID,
        CAST(inpat.AdmitDateTime AS DATE) AS DxDate,
        dx.ICD9SID,
        dx.ICD10SID
    FROM
        ORD_Haneef_202402056D.Src.Inpat_Inpatient inpat
        INNER JOIN
        ORD_Haneef_202402056D.Src.Inpat_InpatientDiagnosis dx
            ON
            inpat.InpatientSID = dx.InpatientSID

    UNION ALL

    SELECT
        fii.PatientSID,
        CAST(fii.TreatmentFromDateTime AS DATE) AS DxDate,
        dx.ICD9SID,
        dx.ICD10SID
    FROM
        ORD_Haneef_202402056D.Src.Fee_FeeInpatInvoice fii
        INNER JOIN
        ORD_Haneef_202402056D.Src.Fee_FeeInpatInvoiceICDDiagnosis dx
            ON
            fii.FeeInpatInvoiceSID = dx.FeeInpatInvoiceSID

    UNION ALL

    SELECT
        PatientSID,
        CAST(AdmitDateTime AS DATE) AS DxDate,
        ICD9SID,
        ICD10SID
    FROM
        ORD_Haneef_202402056D.Src.Inpat_InpatientFeeDiagnosis
) merged
;


DROP TABLE IF EXISTS #PreEpilepsyTBIDx;
WITH TBIDx AS (
    SELECT
        dx.PatientSID,
        dx.DxDate AS TBIDate,
        icd.TBIClassKarlander,
        icd.KarlanderAny,
        icd.TBIClassArmed,
        icd.ArmedAny
    FROM
        ##AllDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnTBIICD9 icd
            ON
            dx.ICD9SID = icd.ICD9SID
    
    UNION ALL

    SELECT
        dx.PatientSID,
        dx.DxDate AS TBIDate,
        icd.TBIClassKarlander,
        icd.KarlanderAny,
        icd.TBIClassArmed,
        icd.ArmedAny
    FROM
        ##AllDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnTBIICD10 icd
            ON
            dx.ICD10SID = icd.ICD10SID
)
SELECT
    coh.PatientICN,
    tbi.TBIClassKarlander,
    tbi.KarlanderAny,
    tbi.TBIClassArmed,
    tbi.ArmedAny
INTO
    #PreEpilepsyTBIDx
FROM
    TBIDx tbi
    INNER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        tbi.PatientSID = coh.PatientSID
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnEpilepsyFinal epi
        ON
        coh.PatientICN = epi.PatientICN
WHERE
    -- tbi.TBIDate <= epi.DxDate
    (DATEDIFF(DAY, tbi.TBIDate, epi.DxDate) / 365.25) BETWEEN 0 AND 5
;


DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTBIKarlanderCategories;
SELECT
    PatientICN,
    MAX(CASE WHEN TBIClassKarlander = 'Concussion' THEN 1 ELSE 0 END) AS KarlanderConcussion,
    MAX(CASE WHEN TBIClassKarlander = 'Fracture' THEN 1 ELSE 0 END) AS KarlanderFracture,
    MAX(CASE WHEN TBIClassKarlander = 'Focal Cerebral' THEN 1 ELSE 0 END) AS KarlanderFocalCerebral,
    MAX(CASE WHEN TBIClassKarlander = 'Diffuse Cerebral' THEN 1 ELSE 0 END) AS KarlanderDiffuseCerebral,
    MAX(CASE WHEN TBIClassKarlander = 'Extracerebral' THEN 1 ELSE 0 END) AS KarlanderExtracerebral,
    MAX(CASE WHEN TBIClassKarlander IS NULL AND KarlanderAny = 1 THEN 1 ELSE 0 END) AS KarlanderUnknown
INTO
    ORD_Haneef_202402056D.Dflt.rnTBIKarlanderCategories
FROM
    #PreEpilepsyTBIDx
GROUP BY
    PatientICN
;

UPDATE ORD_Haneef_202402056D.Dflt.rnTBIKarlanderCategories
SET KarlanderUnknown = CASE WHEN (
        KarlanderConcussion = 1
        OR
        KarlanderFracture = 1
        OR
        KarlanderFocalCerebral = 1
        OR
        KarlanderDiffuseCerebral = 1
        OR
        KarlanderExtracerebral = 1
    ) THEN 0
    ELSE KarlanderUnknown
END;

DROP TABLE IF EXISTS #KarlanderAny;
CREATE TABLE #KarlanderAny (
    PatientICN VARCHAR(10) PRIMARY KEY,
    TBIClassKarlanderAny BIT
);
INSERT INTO #KarlanderAny
SELECT DISTINCT
    PatientICN,
    KarlanderAny AS TBIClassKarlanderAny
FROM
    #PreEpilepsyTBIDx
WHERE
    KarlanderAny = 1
;

DROP TABLE IF EXISTS #KarlanderMode
CREATE TABLE #KarlanderMode (
    PatientICN VARCHAR(10) PRIMARY KEY,
    TBIClassKarlander VARCHAR(25)
);
INSERT INTO #KarlanderMode
EXEC ORD_Haneef_202402056D.Dflt.ComputeMode '#PreEpilepsyTBIDx', 'PatientICN', 'TBIClassKarlander';

DROP TABLE IF EXISTS #KarlanderWorst;
CREATE TABLE #KarlanderWorst (
    PatientICN VARCHAR(10) PRIMARY KEY,
    TBIClassKarlander VARCHAR(25)
);
INSERT INTO #KarlanderWorst
SELECT
    PatientICN,
    CASE
        WHEN KarlanderFocalCerebral = 1 THEN 'Focal Cerebral'
        WHEN KarlanderDiffuseCerebral = 1 THEN 'Diffuse Cerebral'
        WHEN KarlanderExtraCerebral = 1 THEN 'Extracerebral'
        WHEN KarlanderFracture = 1 THEN 'Fracture'
        WHEN KarlanderConcussion = 1 THEN 'Concussion'
        WHEN KarlanderUnknown = 1 THEN NULL
    END
FROM
    ORD_Haneef_202402056D.Dflt.rnTBIKarlanderCategories
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTBIArmedCategories;
SELECT
    PatientICN,
    MAX(CASE WHEN TBIClassArmed = 'Mild' THEN 1 ELSE 0 END) AS ArmedMild,
    MAX(CASE WHEN TBIClassArmed = 'Moderate' THEN 1 ELSE 0 END) AS ArmedModerate,
    MAX(CASE WHEN TBIClassArmed = 'Severe' THEN 1 ELSE 0 END) AS ArmedSevere,
    MAX(CASE WHEN TBIClassArmed = 'Penetrating' THEN 1 ELSE 0 END) AS ArmedPenetrating,
    MAX(CASE WHEN TBIClassArmed IS NULL AND ArmedAny = 1 THEN 1 ELSE 0 END) AS ArmedUnknown
INTO
    ORD_Haneef_202402056D.Dflt.rnTBIArmedCategories
FROM
    #PreEpilepsyTBIDx
GROUP BY
    PatientICN
;

UPDATE ORD_Haneef_202402056D.Dflt.rnTBIArmedCategories
SET ArmedUnknown = CASE WHEN (
        ArmedMild = 1
        OR
        ArmedModerate = 1
        OR
        ArmedSevere = 1
        OR
        ArmedPenetrating = 1
    ) THEN 0
    ELSE ArmedUnknown
END;

DROP TABLE IF EXISTS #ArmedAny;
CREATE TABLE #ArmedAny (
    PatientICN VARCHAR(10) PRIMARY KEY,
    TBIClassArmedAny BIT
);
INSERT INTO #ArmedAny
SELECT DISTINCT
    PatientICN,
    ArmedAny AS TBIClassArmedAny
FROM
    #PreEpilepsyTBIDx
WHERE
    ArmedAny = 1
;

DROP TABLE IF EXISTS #ArmedMode
CREATE TABLE #ArmedMode (
    PatientICN VARCHAR(10) PRIMARY KEY,
    TBIClassArmed VARCHAR(25)
);
INSERT INTO #ArmedMode
EXEC ORD_Haneef_202402056D.Dflt.ComputeMode '#PreEpilepsyTBIDx', 'PatientICN', 'TBIClassArmed';

DROP TABLE IF EXISTS #ArmedWorst;
CREATE TABLE #ArmedWorst (
    PatientICN VARCHAR(10) PRIMARY KEY,
    TBIClassArmed VARCHAR(25)
);
INSERT INTO #ArmedWorst
SELECT
    PatientICN,
    CASE
        WHEN ArmedPenetrating = 1 THEN 'Penetrating'
        WHEN ArmedSevere = 1 THEN 'Severe'
        WHEN ArmedModerate = 1 THEN 'Moderate'
        WHEN ArmedMild = 1 THEN 'Mild'
        WHEN ArmedUnknown = 1 THEN NULL
    END
FROM
    ORD_Haneef_202402056D.Dflt.rnTBIArmedCategories
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnPTEFinal;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnPTEFinal (
    PatientICN VARCHAR(10) PRIMARY KEY,
    TBIClassKarlanderAny VARCHAR(20),
    TBIClassKarlanderMode VARCHAR(20),
    TBIClassKarlanderWorst VARCHAR(20),
    TBIClassArmedAny VARCHAR(20),
    TBIClassArmedMode VARCHAR(20),
    TBIClassArmedWorst VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnPTEFinal (
    PatientICN,
    TBIClassKarlanderAny,
    TBIClassKarlanderMode,
    TBIClassKarlanderWorst,
    TBIClassArmedAny,
    TBIClassArmedMode,
    TBIClassArmedWorst
)
SELECT
    coh.PatientICN,
    karlany.TBIClassKarlanderAny AS TBIClassKarlanderAny,
    karlmode.TBIClassKarlander AS TBIClassKarlanderMode,
    karlworst.TBIClassKarlander AS TBIClassKarlanderWorst,
    armedany.TBIClassArmedAny AS TBIClassArmedAny,
    armedmode.TBIClassArmed AS TBIClassArmedMode,
    armedworst.TBIClassArmed AS TBIClassArmedWorst
FROM
    (SELECT DISTINCT PatientICN FROM ORD_Haneef_202402056D.Src.CohortCrosswalk) coh
    FULL JOIN
    #KarlanderAny karlany
        ON
        coh.PatientICN = karlany.PatientICN
    FULL JOIN
    #KarlanderMode karlmode
        ON
        coh.PatientICN = karlmode.PatientICN
    FULL JOIN
    #KarlanderWorst karlworst
        ON
        coh.PatientICN = karlworst.PatientICN
    FULL JOIN
    #ArmedAny armedany
        ON
        coh.PatientICN = armedany.PatientICN
    FULL JOIN
    #ArmedMode armedmode
        ON
        coh.PatientICN = armedmode.PatientICN
    FULL JOIN
    #ArmedWorst armedworst
        ON
        coh.PatientICN = armedworst.PatientICN
;

DELETE FROM ORD_Haneef_202402056D.Dflt.rnPTEFinal
WHERE
    TBIClassKarlanderAny IS NULL
    AND
    TBIClassArmedAny IS NULL
;

select TBIClassKarlanderMode, COUNT(*)
from ORD_Haneef_202402056D.Dflt.rnPTEFinal
GROUP BY TBIClassKarlanderMode
