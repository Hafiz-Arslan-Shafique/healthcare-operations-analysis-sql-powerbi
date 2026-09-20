-- ============================================================
-- Healthcare Operations & Revenue Analytics
-- SQL Server Analysis Workflow
-- ============================================================

-- ============================================================
-- 1. CREATE DATABASE
-- ============================================================

CREATE DATABASE HealthcareDB;
GO

USE HealthcareDB;
GO

-- Verify database name
SELECT name
FROM sys.databases
WHERE name = 'HealthcareDB';


-- ============================================================
-- 2. CREATE RAW TABLE
-- ============================================================
-- Create the table before import to avoid type issues.

CREATE TABLE Raw_Healthcare (
    Name NVARCHAR(100),
    Age INT,
    Gender NVARCHAR(20),
    [Blood Type] NVARCHAR(10),
    [Medical Condition] NVARCHAR(50),
    [Date of Admission] NVARCHAR(50),
    Doctor NVARCHAR(100),
    Hospital NVARCHAR(100),
    [Insurance Provider] NVARCHAR(50),
    [Billing Amount] FLOAT,
    [Room Number] INT,
    [Admission Type] NVARCHAR(50),
    [Discharge Date] NVARCHAR(50),
    Medication NVARCHAR(100),
    [Test Results] NVARCHAR(50)
);


-- ============================================================
-- 3. ADD PRIMARY KEY
-- ============================================================
-- Replace YourTableName with the actual imported table name.

ALTER TABLE YourTableName
ADD ID INT IDENTITY(1,1) PRIMARY KEY;


-- ============================================================
-- 4. BASIC DATA VERIFICATION
-- ============================================================

SELECT TOP 5 *
FROM Healthcare_Operations;

SELECT COUNT(*)
FROM Healthcare_Operations;


-- ============================================================
-- 5. CREATE CLEAN TABLE
-- ============================================================

SELECT
    UPPER(TRIM(Name)) AS Clean_Name,
    Age,
    Gender,
    Blood_Type,
    Medical_Condition,
    Date_of_Admission,
    Discharge_Date,
    DATEDIFF(DAY, Date_of_Admission, Discharge_Date) AS Length_of_Stay,
    Hospital,
    Insurance_Provider,
    Billing_Amount,
    Admission_Type,
    Doctor,
    Medication,
    Test_Results,
    Room_Number
INTO Clean_Healthcare
FROM Healthcare_Operations
WHERE Date_of_Admission IS NOT NULL
  AND Discharge_Date IS NOT NULL
  AND DATEDIFF(DAY, Date_of_Admission, Discharge_Date) >= 0;
GO


-- ============================================================
-- 6. VERIFY CLEAN TABLE
-- ============================================================

SELECT TOP 5 *
FROM Clean_Healthcare;

SELECT COUNT(*)
FROM Clean_Healthcare;


-- ============================================================
-- 7. CHECK DUPLICATES
-- ============================================================

SELECT
    Clean_Name,
    Date_of_Admission,
    COUNT(*) AS Duplicates
FROM Clean_Healthcare
GROUP BY Clean_Name, Date_of_Admission
HAVING COUNT(*) > 1;


-- ============================================================
-- 8. CREATE FINAL DEDUPLICATED TABLE
-- ============================================================

WITH Deduped AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY Clean_Name, Date_of_Admission
            ORDER BY Discharge_Date
        ) AS rn
    FROM Clean_Healthcare
)
SELECT
    Clean_Name,
    Age,
    Gender,
    Blood_Type,
    Medical_Condition,
    Date_of_Admission,
    Discharge_Date,
    Length_of_Stay,
    Hospital,
    Insurance_Provider,
    Billing_Amount,
    Admission_Type,
    Doctor
INTO Final_Healthcare
FROM Deduped
WHERE rn = 1;


-- Verify final row count
-- Expected by supplied workflow: approximately 54,815
SELECT COUNT(*)
FROM Final_Healthcare;


-- ============================================================
-- 9. CHECK INCONSISTENT CATEGORIES
-- ============================================================

SELECT DISTINCT Gender
FROM Clean_Healthcare;

SELECT DISTINCT Admission_Type
FROM Clean_Healthcare;

SELECT DISTINCT Medical_Condition
FROM Clean_Healthcare;

SELECT DISTINCT Blood_Type
FROM Clean_Healthcare;


-- Final category checks
SELECT DISTINCT Gender
FROM Final_Healthcare
ORDER BY Gender;

SELECT DISTINCT Blood_Type
FROM Final_Healthcare
ORDER BY Blood_Type;

SELECT DISTINCT Admission_Type
FROM Final_Healthcare
ORDER BY Admission_Type;

SELECT DISTINCT Medical_Condition
FROM Final_Healthcare
ORDER BY Medical_Condition;

SELECT DISTINCT Insurance_Provider
FROM Final_Healthcare
ORDER BY Insurance_Provider;

SELECT DISTINCT Hospital
FROM Final_Healthcare
ORDER BY Hospital;


-- ============================================================
-- 10. CHECK NULLS
-- ============================================================

SELECT
    SUM(CASE WHEN Clean_Name IS NULL THEN 1 ELSE 0 END) AS Null_Name,
    SUM(CASE WHEN Age IS NULL THEN 1 ELSE 0 END) AS Null_Age,
    SUM(CASE WHEN Billing_Amount IS NULL THEN 1 ELSE 0 END) AS Null_Billing,
    SUM(CASE WHEN Hospital IS NULL THEN 1 ELSE 0 END) AS Null_Hospital,
    SUM(CASE WHEN Length_of_Stay IS NULL THEN 1 ELSE 0 END) AS Null_LOS
FROM Final_Healthcare;


-- ============================================================
-- 11. OUTLIER / RANGE CHECKS
-- ============================================================

SELECT
    MIN(Age) AS Min_Age,
    MAX(Age) AS Max_Age,
    AVG(CAST(Age AS FLOAT)) AS Avg_Age,
    MIN(Billing_Amount) AS Min_Bill,
    MAX(Billing_Amount) AS Max_Bill,
    AVG(CAST(Billing_Amount AS FLOAT)) AS Avg_Bill,
    MIN(Length_of_Stay) AS Min_LOS,
    MAX(Length_of_Stay) AS Max_LOS,
    AVG(CAST(Length_of_Stay AS FLOAT)) AS Avg_LOS
FROM Final_Healthcare;


-- ============================================================
-- 12. NEGATIVE BILLING CHECK AND FIX
-- ============================================================

-- Find negative bills
SELECT COUNT(*) AS Negative_Bills
FROM Final_Healthcare
WHERE Billing_Amount < 0;

-- Update negative billing value to positive value
UPDATE Final_Healthcare
SET Billing_Amount = ABS(Billing_Amount)
WHERE Billing_Amount < 0;

-- Verify former negative billing values
SELECT COUNT(*) AS Negative_Bills_After_Fix
FROM Final_Healthcare
WHERE Billing_Amount < 0;


-- Re-verify billing outliers
SELECT
    MIN(Billing_Amount) AS Min_Bill_Fixed,
    MAX(Billing_Amount) AS Max_Bill,
    AVG(CAST(Billing_Amount AS FLOAT)) AS Avg_Bill_Fixed
FROM Final_Healthcare;


-- ============================================================
-- 13. DASHBOARD ANALYSIS
-- ============================================================

-- Revenue & LOS by Medical Condition
SELECT
    Medical_Condition,
    COUNT(*) AS Patient_Count,
    SUM(Billing_Amount) AS Total_Revenue,
    AVG(CAST(Billing_Amount AS FLOAT)) AS Avg_Revenue,
    AVG(CAST(Length_of_Stay AS FLOAT)) AS Avg_LOS
FROM Final_Healthcare
GROUP BY Medical_Condition
ORDER BY Total_Revenue DESC;


-- Revenue by Insurance Provider
SELECT
    Insurance_Provider,
    COUNT(*) AS Patient_Count,
    SUM(Billing_Amount) AS Total_Revenue,
    AVG(CAST(Billing_Amount AS FLOAT)) AS Avg_Bill
FROM Final_Healthcare
GROUP BY Insurance_Provider
ORDER BY Total_Revenue DESC;


-- Revenue by Admission Type
SELECT
    Admission_Type,
    COUNT(*) AS Patient_Count,
    SUM(Billing_Amount) AS Total_Revenue,
    AVG(CAST(Length_of_Stay AS FLOAT)) AS Avg_LOS
FROM Final_Healthcare
GROUP BY Admission_Type
ORDER BY Total_Revenue DESC;


-- Top 10 Hospitals by Revenue
SELECT TOP 10
    Hospital,
    COUNT(*) AS Patient_Count,
    SUM(Billing_Amount) AS Total_Revenue,
    AVG(CAST(Billing_Amount AS FLOAT)) AS Avg_Bill
FROM Final_Healthcare
GROUP BY Hospital
ORDER BY Total_Revenue DESC;
