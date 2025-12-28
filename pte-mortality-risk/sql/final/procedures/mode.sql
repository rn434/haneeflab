/*

This file defines a stored that accepts a table with many rows for an ID that 
should be unique for each person. The output is the ceation of a temporary table 
named #{Column}Mode with only one row per ID with columns containing the mode of 
the column of interest for that ID. Null values are excluded in this 
computation.

TODO: handle a list of columns instead of one at a time
TODO: don't make a temp table?

*/

USE ORD_Haneef_202402056D;
GO
-- DROP PROCEDURE Dflt.ComputeMode;
CREATE PROCEDURE Dflt.ComputeMode
    @TableName NVARCHAR(128),
    @PersonIDColumn NVARCHAR(128),
    @ValueColumn NVARCHAR(128)
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = '
    WITH CountCTE AS (
        SELECT 
            ' + QUOTENAME(@PersonIDColumn) + ' AS PersonID,
            ' + QUOTENAME(@ValueColumn) + ' AS ColumnValue,
            COUNT(*) AS Frequency
        FROM 
            ' + QUOTENAME(@TableName) + '
        WHERE
            ' + QUOTENAME(@ValueColumn) + ' IS NOT NULL
        GROUP BY 
            ' + QUOTENAME(@PersonIDColumn) + ', ' + QUOTENAME(@ValueColumn) + '
    ),
    ModeCTE AS (
        SELECT 
            PersonID,
            ColumnValue,
            ROW_NUMBER() OVER (PARTITION BY PersonID ORDER BY Frequency DESC, CHECKSUM(CONVERT(varchar, PersonID) + CONVERT(varchar, ColumnValue))) AS RowNum
        FROM 
            CountCTE
    )
    SELECT 
        PersonID,
        ColumnValue AS ' + QUOTENAME(@ValueColumn) + '
    FROM 
        ModeCTE
    WHERE 
        RowNum = 1;
    ';

    EXEC sp_executesql @SQL;
END;
