/*

This file builds a table of anti-seizure drugs (ASDs) based on the list 
provided by the VSSC in development of the Neurology Cube:

    BRIVARACETAM
    CANNABIDIOL
    CARBAMAZEPINE
    CENOBAMATE
    CLOBAZAM
    DIAZEPAM (only nasal or rectal form)
    DIVALPROEX
    ESLICARBAZEPINE
    ETHOSUXIMIDE
    ETHOTOIN
    EZOGABINE
    FELBAMATE
    FOSPHENYTOIN
    GABAPENTIN
    LACOSAMIDE
    LAMOTRIGINE
    LEVETIRACETAM
    METHSUXIMIDE
    MIDAZOLAM (only nasal form)
    OXCARBAZEPINE
    PERAMPANEL
    PHENOBARBITAL
    PHENYTOIN
    PREGABALIN
    PRIMIDONE
    RUFINAMIDE
    TIAGABINE
    TOPIRAMATE
    VALPROATE SODIUM
    VALPROIC ACID
    VIGABATRIN
    ZONISAMIDE

*/


DROP TABLE IF EXISTS #ASDName;
SELECT
    *
INTO
    #ASDName
FROM (VALUES
    ('brivaracetam'),
    ('cannabidiol'),
    ('carbamazepine'),
    ('cenobamate'),
    ('clobazam'),
    ('diazepam%nasal'),
    ('diazepam%rectal'),
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
    ('midazolam%nasal'),
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
) AS names (Name)
;


DROP TABLE IF EXISTS ORD_Haneef_202402056D.Dflt.rnASD;
CREATE TABLE ORD_Haneef_202402056D.Dflt.rnASD (
    LocalDrugSID INT PRIMARY KEY,
    ProductName VARCHAR(255)
)
;
INSERT INTO ORD_Haneef_202402056D.Dflt.rnASD (
    LocalDrugSID,
    ProductName
)
SELECT
    drug.LocalDrugSID,
    drug.VAProductName AS ProductName
FROM
    CDWWork.Dim.LocalDrug drug
    INNER JOIN
    #ASDName asd
        ON
        drug.VAProductName LIKE asd.Name
        OR
        drug.VAProductName LIKE asd.Name + ' %'
        OR
        drug.VAProductName LIKE '% ' + asd.Name
        OR
        drug.VAProductName LIKE '% ' + asd.Name + ' %'
;


