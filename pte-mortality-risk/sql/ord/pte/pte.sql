/*

This file captures all PTE patients by looking for a diagnosis of any TBI ICD 
code in the 5 years preceding their epilepsy diagnosis.

*/

IF OBJECT_ID('tempdb..##AllDx') IS NOT NULL
    BEGIN
        PRINT 'HERE';
    END
;

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

-- DROP TABLE IF EXISTS #DaVINCIAllDx;
-- SELECT
--     *
-- INTO
--     #DaVINCIAllDx
-- FROM (
--     SELECT
--         PatientICN,
--         DxDate,
--         CASE WHEN FY < 2016 THEN ICDCode ELSE NULL END AS ICD9Code,
--         CASE WHEN FY >= 2016 THEN ICDCode ELSE NULL END AS ICD10Code
--     FROM (
--         SELECT
--             PatientICN,
--             FY,
--             ServiceDate AS DxDate,
--             Diagnosis_1,
--             Diagnosis_2,
--             Diagnosis_3,
--             Diagnosis_4,
--             Diagnosis_5,
--             Diagnosis_6,
--             Diagnosis_7,
--             Diagnosis_8
--         FROM
--             ORD_Haneef_202402056D.Src.DaVINCI_SIDR
--     ) source
--     UNPIVOT (
--         ICDCode FOR diagnosis_column IN (
--             Diagnosis_1,
--             Diagnosis_2,
--             Diagnosis_3,
--             Diagnosis_4,
--             Diagnosis_5,
--             Diagnosis_6,
--             Diagnosis_7,
--             Diagnosis_8
--         ) 
--     ) unpivoted
--     WHERE
--         ICDCode IS NOT NULL
    
--     UNION ALL

--     SELECT
--         PatientICN,
--         DxDate,
--         CASE WHEN FY < 2016 THEN ICDCode ELSE NULL END AS ICD9Code,
--         CASE WHEN FY >= 2016 THEN ICDCode ELSE NULL END AS ICD10Code
--     FROM (
--         SELECT
--             PatientICN,
--             FY,
--             ServiceDate AS DxDate,
--             Diag1,
--             Diag2,
--             Diag3,
--             Diag4,
--             Diag5,
--             Diag6,
--             Diag7,
--             Diag8,
--             Diag9,
--             Diag10
--         FROM
--             ORD_Haneef_202402056D.Src.DaVINCI_CAPER
--     ) source
--     UNPIVOT (
--         ICDCode FOR diagnosis_column IN (
--             Diag1,
--             Diag2,
--             Diag3,
--             Diag4,
--             Diag5,
--             Diag6,
--             Diag7,
--             Diag8,
--             Diag9,
--             Diag10
--         ) 
--     ) unpivoted
--     WHERE
--         ICDCode IS NOT NULL
-- ) AS combined
-- ;

DROP TABLE IF EXISTS #PreEpilepsyTBIDx;
WITH TBIDx AS (
    SELECT
        dx.PatientSID,
        dx.DxDate AS TBIDate,
        icd.TBIClassChristensen,
        icd.TBIClassKarlander,
        icd.OccurrenceType
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
        icd.TBIClassChristensen,
        icd.TBIClassKarlander,
        icd.OccurrenceType
    FROM
        ##AllDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnTBIICD10 icd
            ON
            dx.ICD10SID = icd.ICD10SID
)
SELECT
    coh.PatientICN,
    tbi.TBIClassChristensen,
    tbi.TBIClassKarlander
INTO
    #PreEpilepsyTBIDx
FROM
    TBIDx tbi
    INNER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        tbi.PatientSID = coh.PatientSID
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnEpilepsy epi
        ON
        coh.PatientICN = epi.PatientICN
WHERE
    -- tbi.TBIDate <= epi.DxDate
    (DATEDIFF(DAY, tbi.TBIDate, epi.DxDate) / 365.25) BETWEEN 0 AND 5
;

-- DROP TABLE IF EXISTS #PreEpilepsyDaVINCITBIDx;
-- WITH TBIDx AS (
--     SELECT
--         dx.PatientICN,
--         dx.DxDate AS TBIDate,
--         icd.TBIClassChristensen,
--         icd.TBIClassKarlander,
--         icd.OccurrenceType
--     FROM
--         #DaVINCIAllDx dx
--         INNER JOIN (
--             SELECT
--                 ICD9Code,
--                 MAX(TBIClassChristensen) AS TBIClassChristensen,
--                 MAX(TBIClassKarlander) AS TBIClassKarlander,
--                 MAX(OccurrenceType) AS OccurrenceType
--             FROM 
--                 ORD_Haneef_202402056D.Dflt.rnTBIICD9
--             GROUP BY
--                 ICD9Code
--         ) icd
--             ON
--             dx.ICD9Code = REPLACE(icd.ICD9Code, '.', '')
    
--     UNION ALL

--     SELECT
--         dx.PatientICN,
--         dx.DxDate AS TBIDate,
--         icd.TBIClassChristensen,
--         icd.TBIClassKarlander,
--         icd.OccurrenceType
--     FROM
--         #DaVINCIAllDx dx
--         INNER JOIN (
--             SELECT
--                 ICD10Code,
--                 MAX(TBIClassChristensen) AS TBIClassChristensen,
--                 MAX(TBIClassKarlander) AS TBIClassKarlander,
--                 MAX(OccurrenceType) AS OccurrenceType
--             FROM 
--                 ORD_Haneef_202402056D.Dflt.rnTBIICD10
--             GROUP BY
--                 ICD10Code
--         ) icd            
--         ON
--             dx.ICD10Code = REPLACE(icd.ICD10Code, '.', '')
-- )
-- SELECT
--     tbi.PatientICN,
--     tbi.TBIClassChristensen,
--     tbi.TBIClassKarlander
-- INTO
--     #PreEpilepsyDaVINCITBIDx
-- FROM
--     TBIDx tbi
--     INNER JOIN
--     ORD_Haneef_202402056D.Dflt.rnEpilepsy epi
--         ON
--         tbi.PatientICN = epi.PatientICN
-- WHERE
--     -- tbi.TBIDate <= epi.DxDate
--     (DATEDIFF(DAY, tbi.TBIDate, epi.DxDate) / 365.25) BETWEEN 0 AND 5
-- ;


DROP TABLE IF EXISTS #AllPreEpilepsyTBIDx;
SELECT * INTO #AllPreEpilepsyTBIDx FROM #PreEpilepsyTBIDx
-- SELECT
--     *
-- INTO
--     #AllPreEpilepsyTBIDx
-- FROM (
--     SELECT
--         PatientICN,
--         TBIClassChristensen,
--         TBIClassKarlander
--     FROM
--         #PreEpilepsyTBIDx

--     UNION ALL

--     SELECT
--         PatientICN,
--         TBIClassChristensen,
--         TBIClassKarlander
--     FROM
--         #PreEpilepsyDaVINCITBIDx
-- ) combined
-- ;

DROP TABLE IF EXISTS #AnyKarlander;
SELECT DISTINCT
    PatientICN,
    1 AS AnyKarlander
INTO
    #AnyKarlander
FROM
    #AllPreEpilepsyTBIDx
;

DROP TABLE IF EXISTS #AnyChristensen;
SELECT DISTINCT
    PatientICN,
    1 AS AnyChristensen
INTO
    #AnyChristensen
FROM
    #AllPreEpilepsyTBIDx
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTBIKarlanderAllCategories;
SELECT
    PatientICN,
    MAX(CASE WHEN TBIClassKarlander = 'Concussive' THEN 1 ELSE 0 END) AS KarlanderConcussive,
    MAX(CASE WHEN TBIClassKarlander = 'Fracture' THEN 1 ELSE 0 END) AS KarlanderFracture,
    MAX(CASE WHEN TBIClassKarlander = 'Focal Cerebral' THEN 1 ELSE 0 END) AS KarlanderFocalCerebral,
    MAX(CASE WHEN TBIClassKarlander = 'Diffuse Cerebral' THEN 1 ELSE 0 END) AS KarlanderDiffuseCerebral,
    MAX(CASE WHEN TBIClassKarlander = 'Extracerebral' THEN 1 ELSE 0 END) AS KarlanderExtracerebral,
    MAX(CASE WHEN TBIClassKarlander IS NULL THEN 1 ELSE 0 END) AS KarlanderUnknown
INTO
    ORD_Haneef_202402056D.Dflt.rnTBIKarlanderAllCategories
FROM
    #AllPreEpilepsyTBIDx
GROUP BY
    PatientICN
;

UPDATE ORD_Haneef_202402056D.Dflt.rnTBIKarlanderAllCategories
SET KarlanderUnknown = CASE WHEN (
        KarlanderConcussive = 1
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

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTBIChristensenAllCategories;
SELECT
    PatientICN,
    MAX(CASE WHEN TBIClassChristensen = 'Concussive' THEN 1 ELSE 0 END) AS ChristensenConcussive,
    MAX(CASE WHEN TBIClassChristensen = 'Fracture' THEN 1 ELSE 0 END) AS ChristensenFracture,
    MAX(CASE WHEN TBIClassChristensen = 'Structural' THEN 1 ELSE 0 END) AS ChristensenStructural,
    MAX(CASE WHEN TBIClassChristensen IS NULL THEN 1 ELSE 0 END) AS ChristensenUnknown
INTO
    ORD_Haneef_202402056D.Dflt.rnTBIChristensenAllCategories
FROM 
    #AllPreEpilepsyTBIDx
GROUP BY
    PatientICN
;

UPDATE ORD_Haneef_202402056D.Dflt.rnTBIChristensenAllCategories
SET ChristensenUnknown = CASE WHEN
    ChristensenConcussive = 1
    OR
    ChristensenFracture = 1
    OR
    ChristensenStructural = 1
    THEN 0
    ELSE ChristensenUnknown
END;

-- DROP TABLE IF EXISTS
--     ORD_Haneef_202402056D.Dflt.rnClassificationCounts
-- ;
-- SELECT
--     *
-- INTO
--     ORD_Haneef_202402056D.Dflt.rnClassificationCounts
-- FROM 
--     (SELECT
--         PatientICN,
--         TBIClassKarlander,
--         COUNT(*) AS KarlCount
--     FROM
--         #AllPreEpilepsyTBIDx
--     GROUP BY
--         PatientICN,
--         TBIClassKarlander) AS SourceTable
--     PIVOT
--         (MAX(KarlCount)
--         FOR TBIClassKarlander IN (
--             [Concussive],
--             [Fracture],
--             [Diffuse Cerebral],
--             [Focal Cerebral],
--             [Extracerebral]
--         )) AS PivotTable
-- ;

DROP TABLE IF EXISTS #ChristensenMode
CREATE TABLE #ChristensenMode (
    PatientICN VARCHAR(10) PRIMARY KEY,
    TBIClassChristensen VARCHAR(25)
);
INSERT INTO #ChristensenMode
EXEC ORD_Haneef_202402056D.Dflt.ComputeMode '#AllPreEpilepsyTBIDx', 'PatientICN', 'TBIClassChristensen';

DROP TABLE IF EXISTS #KarlanderMode
CREATE TABLE #KarlanderMode (
    PatientICN VARCHAR(10) PRIMARY KEY,
    TBIClassKarlander VARCHAR(25)
);
INSERT INTO #KarlanderMode
EXEC ORD_Haneef_202402056D.Dflt.ComputeMode '#AllPreEpilepsyTBIDx', 'PatientICN', 'TBIClassKarlander';

DROP TABLE IF EXISTS #ChristensenWorst;
CREATE TABLE #ChristensenWorst (
    PatientICN VARCHAR(10) PRIMARY KEY,
    TBIClassChristensen VARCHAR(25)
);
INSERT INTO #ChristensenWorst
SELECT
    PatientICN,
    CASE
        WHEN ChristensenStructural = 1 THEN 'Structural'
        WHEN ChristensenFracture = 1 THEN 'Fracture'
        WHEN ChristensenConcussive = 1 THEN 'Concussive'
        WHEN ChristensenUnknown = 1 THEN NULL
    END
FROM
    ORD_Haneef_202402056D.Dflt.rnTBIChristensenAllCategories
;

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
        WHEN KarlanderConcussive = 1 THEN 'Concussive'
        WHEN KarlanderUnknown = 1 THEN NULL
    END
FROM
    ORD_Haneef_202402056D.Dflt.rnTBIKarlanderAllCategories
;

-- DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnPTE;
-- CREATE TABLE ORD_Haneef_202402056D.Dflt.rnPTE (
--     PatientICN VARCHAR(10) PRIMARY KEY,
--     TBIClassChristensen VARCHAR(20),
--     TBIClassKarlander VARCHAR(20),
-- );

-- WITH UniqueTBIPatient AS (
--     SELECT DISTINCT
--         PatientICN
--     FROM
--         #PreEpilepsyTBIDx
-- )
-- INSERT INTO
--     ORD_Haneef_202402056D.Dflt.rnPTE (
--         PatientICN,
--         TBIClassChristensen,
--         TBIClassKarlander
--     )
-- SELECT
--     tbi.PatientICN,
--     chris.TBIClassChristensen,
--     karl.TBIClassKarlander
-- FROM
--     UniqueTBIPatient tbi
--     LEFT JOIN
--     #ChristensenMode chris
--         ON
--         tbi.PatientICN = chris.PatientICN
--     LEFT JOIN
--     #KarlanderMode karl
--         ON
--         tbi.PatientICN = karl.PatientICN
-- ;

------------- DoD Severity Classification ---------------------

-- DROP TABLE IF EXISTS #PreEpilepsyTBIDx;
-- DROP TABLE IF EXISTS #PreEpilepsyDaVINCITBIDx;
-- DROP TABLE IF EXISTS #AllPreEpilepsyTBIDx;

-- DROP TABLE IF EXISTS #SeverityRankings;
-- SELECT
--     *
-- INTO
--     #SeverityRankings
-- FROM (VALUES
--     ('Penetrating', 1),
--     ('Severe', 2),
--     ('Moderate', 3),
--     ('Mild', 4),
--     ('Unclassifiable', 5)
-- ) AS  ranking (Severity, Rank)
-- ;


DROP TABLE IF EXISTS #PreEpilepsyTBIDxArmed;
WITH TBIDx AS (
    SELECT
        dx.PatientSID,
        dx.DxDate AS TBIDate,
        icd.TBISeverity
    FROM
        ##AllDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnTBIICD9DoD icd
            ON
            dx.ICD9SID = icd.ICD9SID
    
    UNION ALL

    SELECT
        dx.PatientSID,
        dx.DxDate AS TBIDate,
        icd.TBISeverity
    FROM
        ##AllDx dx
        INNER JOIN
        ORD_Haneef_202402056D.Dflt.rnTBIICD10DoD icd
            ON
            dx.ICD10SID = icd.ICD10SID
)
SELECT
    coh.PatientICN,
    tbi.TBISeverity
INTO
    #PreEpilepsyTBIDxArmed
FROM
    TBIDx tbi
    INNER JOIN
    ORD_Haneef_202402056D.Src.CohortCrosswalk coh
        ON
        tbi.PatientSID = coh.PatientSID
    INNER JOIN
    ORD_Haneef_202402056D.Dflt.rnEpilepsy epi
        ON
        coh.PatientICN = epi.PatientICN
WHERE
    -- tbi.TBIDate < epi.DxDate
    (DATEDIFF(DAY, tbi.TBIDate, epi.DxDate) / 365.25) BETWEEN 0 AND 5
;

-- DROP TABLE IF EXISTS #PreEpilepsyDaVINCITBIDx;
-- WITH TBIDx AS (
--     SELECT
--         dx.PatientICN,
--         dx.DxDate AS TBIDate,
--         icd.TBISeverity
--     FROM
--         #DaVINCIAllDx dx
--         INNER JOIN (
--             SELECT
--                 ICD9Code,
--                 MAX(TBISeverity) AS TBISeverity
--             FROM 
--                 ORD_Haneef_202402056D.Dflt.rnTBIICD9DoD
--             GROUP BY
--                 ICD9Code
--         ) icd
--             ON
--             dx.ICD9Code = REPLACE(icd.ICD9Code, '.', '')
    
--     UNION ALL

--     SELECT
--         dx.PatientICN,
--         dx.DxDate AS TBIDate,
--         icd.TBISeverity
--     FROM
--         #DaVINCIAllDx dx
--         INNER JOIN (
--             SELECT
--                 ICD10Code,
--                 MAX(TBISeverity) AS TBISeverity
--             FROM 
--                 ORD_Haneef_202402056D.Dflt.rnTBIICD10DoD
--             GROUP BY
--                 ICD10Code
--         ) icd            
--         ON
--             dx.ICD10Code = REPLACE(icd.ICD10Code, '.', '')
-- )
-- SELECT
--     tbi.PatientICN,
--     tbi.TBISeverity
-- INTO
--     #PreEpilepsyDaVINCITBIDx
-- FROM
--     TBIDx tbi
--     INNER JOIN
--     ORD_Haneef_202402056D.Dflt.rnEpilepsy epi
--         ON
--         tbi.PatientICN = epi.PatientICN
-- WHERE
--     -- tbi.TBIDate <= epi.DxDate
--     (DATEDIFF(DAY, tbi.TBIDate, epi.DxDate) / 365.25) BETWEEN 0 AND 5
-- ;

DROP TABLE IF EXISTS #AllPreEpilepsyTBIDxArmed;
SELECT * INTO #AllPreEpilepsyTBIDxArmed FROM #PreEpilepsyTBIDxArmed
-- SELECT
--     *
-- INTO
--     #AllPreEpilepsyTBIDx
-- FROM (
--     SELECT
--         PatientICN,
--         TBISeverity
--     FROM
--         #PreEpilepsyTBIDx

--     UNION ALL

--     SELECT
--         PatientICN,
--         TBISeverity
--     FROM
--         #PreEpilepsyDaVINCITBIDx
-- ) combined
-- ;

DROP TABLE IF EXISTS #AnyArmed;
SELECT DISTINCT
    PatientICN,
    1 AS AnyArmed
INTO
    #AnyArmed
FROM
    #AllPreEpilepsyTBIDxArmed
;

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnTBISeverityAllCategories;
SELECT
    PatientICN,
    MAX(CASE WHEN TBISeverity = 'Mild' THEN 1 ELSE 0 END) AS ArmedMild,
    MAX(CASE WHEN TBISeverity = 'Moderate' THEN 1 ELSE 0 END) AS ArmedModerate,
    MAX(CASE WHEN TBISeverity = 'Severe' THEN 1 ELSE 0 END) AS ArmedSevere,
    MAX(CASE WHEN TBISeverity = 'Penetrating' THEN 1 ELSE 0 END) AS ArmedPenetrating,
    MAX(CASE WHEN TBISeverity IS NULL THEN 1 ELSE 0 END) AS ArmedUnclassifiable
INTO
    ORD_Haneef_202402056D.Dflt.rnTBISeverityAllCategories
FROM 
    #AllPreEpilepsyTBIDxArmed
GROUP BY
    PatientICN
;

UPDATE ORD_Haneef_202402056D.Dflt.rnTBISeverityAllCategories
SET ArmedUnclassifiable = CASE WHEN
    ArmedMild = 1
    OR
    ArmedModerate = 1
    OR
    ArmedSevere = 1
    OR
    ArmedPenetrating = 1
    THEN 0
    ELSE ArmedUnclassifiable
END;

DROP TABLE IF EXISTS #ArmedMode
CREATE TABLE #ArmedMode (
    PatientICN VARCHAR(10) PRIMARY KEY,
    TBISeverity VARCHAR(25)
);
INSERT INTO #ArmedMode
EXEC ORD_Haneef_202402056D.Dflt.ComputeMode '#AllPreEpilepsyTBIDxArmed', 'PatientICN', 'TBISeverity';

DROP TABLE IF EXISTS #ArmedWorst;
CREATE TABLE #ArmedWorst (
    PatientICN VARCHAR(10) PRIMARY KEY,
    TBISeverity VARCHAR(25)
);
INSERT INTO #ArmedWorst
SELECT
    PatientICN,
    CASE
        WHEN ArmedPenetrating = 1 THEN 'Penetrating'
        WHEN ArmedSevere = 1 THEN 'Severe'
        WHEN ArmedModerate = 1 THEN 'Moderate'
        WHEN ArmedMild = 1 THEN 'Mild'
        WHEN ArmedUnclassifiable = 1 THEN NULL
    END
FROM
    ORD_Haneef_202402056D.Dflt.rnTBISeverityAllCategories
;


-- DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnPTE2;
-- CREATE TABLE ORD_Haneef_202402056D.Dflt.rnPTE2 (
--     PatientICN VARCHAR(10) PRIMARY KEY,
--     TBISeverity VARCHAR(20)
-- );

-- WITH NumberedTBI AS (
--     SELECT
--         tbi.PatientICN,
--         tbi.TBISeverity,
--         ROW_NUMBER() OVER (PARTITION BY tbi.PatientICN ORDER BY sev.Rank) AS rn
--     FROM
--         #PreEpilepsyTBIDx tbi
--         INNER JOIN
--         #SeverityRankings sev
--             ON
--             tbi.TBISeverity = sev.Severity
-- )
-- INSERT INTO
--     ORD_Haneef_202402056D.Dflt.rnPTE2 (
--         PatientICN,
--         TBISeverity
--     )
-- SELECT
--     PatientICN,
--     TBISeverity
-- FROM
--     NumberedTBI
-- WHERE
--     rn = 1
-- ;

-- select pte.*
-- FROM
--     ORD_Haneef_202402056D.Dflt.rnPTE pte
--     left join
--     ORD_Haneef_202402056D.Dflt.rnCohortInfo coh
--         on (pte.PatientICN = coh.PatientICN)
--         and (coh.PTE = 1)
-- where
--     coh.PatientICN IS NULL

-- select count(*)
-- FROM
--     ORD_Haneef_202402056D.Dflt.rnPTEFive
-- where TBIClassKarlanderAny = 1

DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnPTEFive;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnPTEFive (
    PatientICN VARCHAR(10) PRIMARY KEY,
    TBIClassKarlanderAny VARCHAR(20),
    TBIClassKarlanderMode VARCHAR(20),
    TBIClassKarlanderWorst VARCHAR(20),
    TBIClassChristensenAny VARCHAR(20),
    TBIClassChristensenMode VARCHAR(20),
    TBIClassChristensenWorst VARCHAR(20),
    TBIClassArmedAny VARCHAR(20),
    TBIClassArmedMode VARCHAR(20),
    TBIClassArmedWorst VARCHAR(20)
);
INSERT INTO ORD_Haneef_202402056D.Dflt.rnPTEFive (
    PatientICN,
    TBIClassKarlanderAny,
    TBIClassKarlanderMode,
    TBIClassKarlanderWorst,
    TBIClassChristensenAny,
    TBIClassChristensenMode,
    TBIClassChristensenWorst,
    TBIClassArmedAny,
    TBIClassArmedMode,
    TBIClassArmedWorst
)
SELECT
    coh.PatientICN,
    karlany.AnyKarlander AS TBIClassKarlanderAny,
    karlmode.TBIClassKarlander AS TBIClassKarlanderMode,
    karlworst.TBIClassKarlander AS TBIClassKarlanderWorst,
    christany.AnyChristensen AS TBIClassChristensenAny,
    christmode.TBIClassChristensen As TBIClassChristensenMode,
    christworst.TBIClassChristensen As TBIClassChristensenWorst,
    armedany.AnyArmed AS TBIClassArmedAny,
    armedmode.TBISeverity As TBIClassArmedMode,
    armedworst.TBISeverity As TBIClassArmedWorst
FROM
    (SELECT DISTINCT PatientICN FROM ORD_Haneef_202402056D.Src.CohortCrosswalk) coh
    FULL JOIN
    #AnyKarlander karlany
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
    #AnyChristensen christany
        ON
        coh.PatientICN = christany.PatientICN
    FULL JOIN
    #ChristensenMode christmode
        ON
        coh.PatientICN = christmode.PatientICN
    FULL JOIN
    #ChristensenWorst christworst
        ON
        coh.PatientICN = christworst.PatientICN
    FULL JOIN
    #AnyArmed armedany
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

DELETE FROM ORD_Haneef_202402056D.Dflt.rnPTEFive
WHERE
    TBIClassKarlanderAny IS NULL
    AND
    TBIClassChristensenAny IS NULL
    AND
    TBIClassArmedAny IS NULL
;


-- select alltime.* from ORD_Haneef_202402056D.Dflt.rnPTEAll alltime left join ORD_Haneef_202402056D.Dflt.rnPTEFive five on alltime.PatientICN = five.PatientICN WHERE five.PatientICN IS NULL
select TBIClassKarlanderWorst, count(*) from ORD_Haneef_202402056D.Dflt.rnPTEAll group by TBIClassKarlanderWorst
