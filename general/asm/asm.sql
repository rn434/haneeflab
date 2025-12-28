/* 

This file gathers all ASM data needed in epilepsy identification.

Estimated runtime = 5 m.

*/

-- Find all ASMs (estimated runtime = 4 m.)

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnASMNames;
SELECT *
INTO SCS_EEGUtil.EEG.rnASMNames
FROM (VALUES
    ('brivaracetam'),
    ('cannabidiol'),
    ('carbamazepine'),
    ('cenobamate'),
    ('clobazam'),
    ('diazepam'),
    ('divalproex'),
    ('eslicarbazepine'),
    ('ethosuximide'),
    ('ethotoin'),
    ('ezogabine'),
    ('felbamate'),
    ('fosphenytoin'),
    ('gabapentin'),
    ('lacosamide'),
    ('lamotrigine'),
    ('levetiracetam'),
    ('methsuximide'),
    ('midazolam'),
    ('oxcarbazepine'),
    ('perampanel'),
    ('phenobarbital'),
    ('phenytoin'),
    ('pregabalin'),
    ('primidone'),
    ('rufinamide'),
    ('tiagabine'),
    ('topiramate'),
    ('valproate'),
    ('valproic%acid'),
    ('vigabatrin'),
    ('zonisamide')
) AS names (ASMName)
;

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnASMLowDoseThresholds;
SELECT *
INTO SCS_EEGUtil.EEG.rnASMLowDoseThresholds
FROM (VALUES
    ('gabapentin', 1200),
    ('carbamazepine', 400),
    ('oxcarbazepine', 600),
    ('lamotrigine', 200),
    ('topiramate', 200),
    ('zonisamide', 200),
    ('primidone', 250),
    ('valproate', 500),
    ('valproic acid', 500)
) AS ASMs (ASMName, DailyLowDoseThreshold)
;

DROP TABLE IF EXISTS SCS_EEGUtil.EEG.rnASM;
SELECT drug.NationalDrugSID,
    drug.DrugNameWithDose,
    nodose.DrugNameWithoutDose,
    drug.StrengthNumeric,
    COALESCE(lowdose.DailyLowDoseThreshold, 0) AS DailyLowDoseThreshold,
    form.DosageForm
INTO SCS_EEGUtil.EEG.rnASM
FROM CDWWork.Dim.NationalDrug drug
    INNER JOIN CDWWork.Dim.DrugNameWithoutDose nodose
        ON drug.DrugNameWithoutDoseSID = nodose.DrugNameWithoutDoseSID
    INNER JOIN SCS_EEGUtil.EEG.rnASMNames asm
        ON (drug.DrugNameWithDose LIKE asm.ASMName 
            OR drug.DrugNameWithDose LIKE asm.ASMName + '[,/ ]%'
            OR drug.DrugNameWithDose LIKE '[,/ ]%' + asm.ASMName
            OR drug.DrugNameWithDose LIKE '[,/ ]%' + asm.ASMName + '%[,/ ]')
    INNER JOIN CDWWork.Dim.DosageForm form
        ON drug.DosageFormSID = form.DosageFormSID
    LEFT JOIN SCS_EEGUtil.EEG.rnASMLowDoseThresholds lowdose
        ON nodose.DrugNameWithoutDose = lowdose.ASMName 
WHERE (nodose.DrugNameWithoutDose 
    NOT IN ('gabapentin enacarbil', 'gabapentin/lidocaine/menthol'))
    AND (nodose.DrugNameWithoutDose <> 'diazepam' 
        OR form.DosageForm LIKE '%nasal%'
        OR form.DosageForm LIKE '%rtl%') -- none say 'rectal' at the moment
    AND (nodose.DrugNameWithoutDose <> 'midazolam' 
        OR form.DosageForm LIKE '%nasal%')
;

-- Checking validity of ASMs (estimated runtime < 1 m.)

SELECT COUNT(*) FROM SCS_EEGUtil.EEG.rnASM;
SELECT COUNT(DISTINCT NationalDrugSID) FROM SCS_EEGUtil.EEG.rnASM;
SELECT COUNT(DISTINCT DrugNameWithDose) FROM SCS_EEGUtil.EEG.rnASM;
SELECT COUNT(DISTINCT DrugNameWithoutDose) FROM SCS_EEGUtil.EEG.rnASM;
SELECT DISTINCT DrugNameWithoutDose FROM SCS_EEGUtil.EEG.rnASM ORDER BY DrugNameWithoutDose;

SELECT DISTINCT
    DrugNameWithDose,
    DrugNameWithoutDose,
    StrengthNumeric,
    DosageForm
FROM SCS_EEGUtil.EEG.rnASM
ORDER BY DrugNameWithDose
;