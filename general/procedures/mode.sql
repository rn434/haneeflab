/*

This file defines a stored that accepts a table with many rows for an ID that 
should be unique for each person. The output is the ceation of a temporary table 
named #{Column}Mode with only one row per ID with columns containing the mode of 
the column of interest for that ID. Null values are excluded in this 
computation.

TODO: handle a list of columns instead of one at a time
TODO: don't make a temp table?

*/

