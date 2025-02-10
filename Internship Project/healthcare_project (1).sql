CREATE DATABASE hcare

-------------------------------------------------------------------------------------------------

-- STEP 1 UNDESTANDING THE DATA
SELECT *
FROM [dbo].[healthcare]

-----------------------------------------------------------------------------------------------------

--STEP 2 CHECKED FOR ABNORMALITIES IN THE DATA
--1. checking for nulls
SELECT *
FROM [dbo].[healthcare]
WHERE Name IS NULL OR  Age IS NULL OR Gender IS NULL OR Blood_Type IS NULL OR Medical_Condition IS NULL OR Date_of_Admission IS NULL 
OR Doctor IS NULL OR Hospital IS NULL OR Insurance_Provider IS NULL OR Billing_Amount IS NULL OR Room_Number IS NULL OR Admission_Type IS NULL
OR Discharge_Date IS NULL OR Medication IS NULL OR Test_Results IS NULL

--2. Checking for duplicates 
SELECT Name, Medical_Condition, Room_Number, Age, Date_of_Admission, COUNT(*) AS Duplicate 
FROM [dbo].[healthcare]
GROUP BY Name, Medical_Condition, Room_Number, Age, Date_of_Admission
HAVING COUNT(Name) > 1 --539 records contain duplicate

--3. Filtering records to check inconsitencies
SELECT DISTINCT Name
FROM [dbo].[healthcare]

SELECT DISTINCT Age
FROM [dbo].[healthcare]

SELECT DISTINCT Gender
FROM [dbo].[healthcare]

SELECT DISTINCT Blood_Type
FROM [dbo].[healthcare]

SELECT DISTINCT Medical_Condition
FROM [dbo].[healthcare]

SELECT DISTINCT Date_of_Admission
FROM [dbo].[healthcare]

SELECT DISTINCT Doctor
FROM [dbo].[healthcare]

SELECT DISTINCT Hospital
FROM [dbo].[healthcare]

SELECT DISTINCT Insurance_Provider
FROM [dbo].[healthcare]

SELECT DISTINCT Billing_Amount
FROM [dbo].[healthcare]

SELECT DISTINCT Room_Number
FROM [dbo].[healthcare]

SELECT DISTINCT Admission_Type
FROM [dbo].[healthcare]

SELECT DISTINCT Discharge_Date
FROM [dbo].[healthcare]

SELECT DISTINCT Medication
FROM [dbo].[healthcare]

SELECT DISTINCT Test_Results
FROM [dbo].[healthcare]

-------------------------------------------------------------------------------------------------------------

--STEP 3 - CLEANING THE DATA

--1. Deleting duplicates

-------------adding new column 'row_num' which presents how many duplicates are there for each record
ALTER TABLE healthcare1
ADD row_num INT;

------------calculates number of duplicates for each rows
WITH DuplicateCounts AS (
    SELECT 
        Name, Age, Gender, Blood_Type, Medical_Condition, Date_of_Admission, Doctor, Hospital, Insurance_Provider,
        Billing_Amount, Room_Number, Admission_Type, Discharge_Date, Medication, Test_Results,
        COUNT(*) AS duplicate_count
    FROM [dbo].[healthcare1]
    GROUP BY 
        Name, Age, Gender, Blood_Type, Medical_Condition, Date_of_Admission, Doctor, Hospital, Insurance_Provider,
        Billing_Amount, Room_Number, Admission_Type, Discharge_Date, Medication, Test_Results
)
UPDATE [dbo].[healthcare1]
SET row_num = (
    SELECT duplicate_count
    FROM DuplicateCounts
    WHERE DuplicateCounts.Name = [dbo].[healthcare1].Name 
      AND DuplicateCounts.Age = [dbo].[healthcare1].Age
      AND DuplicateCounts.Gender = [dbo].[healthcare1].Gender
      AND DuplicateCounts.Blood_Type = [dbo].[healthcare1].Blood_Type
      AND DuplicateCounts.Medical_Condition = [dbo].[healthcare1].Medical_Condition
      AND DuplicateCounts.Date_of_Admission = [dbo].[healthcare1].Date_of_Admission
      AND DuplicateCounts.Doctor = [dbo].[healthcare1].Doctor
      AND DuplicateCounts.Hospital = [dbo].[healthcare1].Hospital
      AND DuplicateCounts.Insurance_Provider = [dbo].[healthcare1].Insurance_Provider
      AND DuplicateCounts.Billing_Amount = [dbo].[healthcare1].Billing_Amount
      AND DuplicateCounts.Room_Number = [dbo].[healthcare1].Room_Number
      AND DuplicateCounts.Admission_Type = [dbo].[healthcare1].Admission_Type
      AND DuplicateCounts.Discharge_Date = [dbo].[healthcare1].Discharge_Date
      AND DuplicateCounts.Medication = [dbo].[healthcare1].Medication
      AND DuplicateCounts.Test_Results = [dbo].[healthcare1].Test_Results
);

SELECT *
FROM  [dbo].[healthcare1]
WHERE row_num = 2

----------created a new duplicate table 
SELECT *
INTO [dbo].[duplicates]
FROM [dbo].[healthcare1]
WHERE row_num = 2

CREATE CLUSTERED INDEX IX_Name
ON [dbo].[duplicates](Name);

SELECT *
FROM [dbo].[duplicates]

----------added new ID Column
ALTER TABLE [dbo].[duplicates]
ADD ID INT IDENTITY(1,1);

----------removed alternative rows
WITH NumberedRecords AS (
    SELECT 
        ID,
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_num
    FROM [dbo].[duplicates]
)
DELETE FROM [dbo].[duplicates]
WHERE ID IN (
    SELECT ID
    FROM NumberedRecords
    WHERE row_num % 2 = 1  -- Deletes odd-numbered rows (alternating rows)
);

----------deleting ID Column
ALTER TABLE [dbo].[duplicates]
DROP COLUMN ID;

---------deleting all duplicate records from [dbo].[healthcare1]
DELETE 
FROM [dbo].[healthcare1]
WHERE row_num = 2

-------Appending [dbo].[healthcare1] AND [dbo].[duplicates]
SELECT *
INTO [dbo].[healthcaredata]
FROM (
    SELECT *
    FROM [dbo].[duplicates]
    UNION ALL
    SELECT *
    FROM [dbo].[healthcare1]
) AS UnionResult;

---------deleting row_num column
ALTER TABLE [dbo].[healthcaredata]
DROP COLUMN row_num 

SELECT *
FROM [dbo].[healthcaredata]
ORDER BY Name ASC

SELECT *
INTO [dbo].[tblHealthcare]
FROM [dbo].[healthcaredata]

--2.Replacing NULL values with mean of billing amount
UPDATE [dbo].[tblHealthcare]
SET Billing_Amount = COALESCE(Billing_Amount, (SELECT AVG(Billing_Amount) FROM [dbo].[tblHealthcare]))
WHERE Billing_Amount IS NULL

--3. Converting names to a proper format

------converting all letters to lower case
UPDATE [dbo].[tblHealthcare1]
SET Name = LOWER(Name)
FROM [dbo].[tblHealthcare1]
------converting 1st letter lo upper case
UPDATE [dbo].[tblHealthcare1]
SET Name = UPPER(LEFT(Name, 1)) + LOWER(SUBSTRING(Name, 2, LEN(Name) - 1))
FROM [dbo].[tblHealthcare1]
----converting 1st letter of 2nd name to upper
UPDATE [dbo].[tblHealthcare]
SET Name = LEFT(Name, CHARINDEX(' ', Name)) +  
    UPPER(SUBSTRING(Name, CHARINDEX(' ', Name) + 1, 1)) + 
    LOWER(SUBSTRING(Name, CHARINDEX(' ', Name) + 2, LEN(Name) - CHARINDEX(' ', Name)))
----Removing Mr, Ms, Mrs, Dr from name
UPDATE [dbo].[tblHealthcare]
SET Name = LTRIM(RTRIM(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(Name, 'Mr. ', ''), 
                        'Ms. ', ''),
                    'Dr. ', ''),
                'Mrs. ', '')
        )) 
FROM [dbo].[tblHealthcare]


UPDATE tblHealthcare1
SET Name = LEFT(Name, CHARINDEX(' ', Name, CHARINDEX(' ', Name) + 1) - 1)
WHERE LEN(Name) - LEN(REPLACE(Name, ' ', '')) = 2;

SELECT *
FROM [dbo].[tblHealthcare]

--5. Cleaning Hospital names
------Removing commas in Hospital names
UPDATE [dbo].[tblHealthcare1]
SET Hospital = REPLACE(Hospital, ',', '')
FROM tblHealthcare
------Removing 'and' in the beginning and end of the hospital names
UPDATE tblHealthcare
SET Hospital = CASE
				 WHEN RIGHT(Hospital, 4) = ' and' THEN LEFT(Hospital, LEN(Hospital) - 4)
				 WHEN LEFT(Hospital, 4) = 'and ' THEN SUBSTRING(Hospital, 5, LEN(Hospital) - 4)
			   END
FROM tblHealthcare
WHERE Hospital LIKE '% and' OR Hospital LIKE 'and %';

----5. Rounding up billing amount to 2 decimal places
UPDATE tblHealthcare
SET Billing_Amount = ROUND(Billing_Amount, 2)
FROM tblHealthcare

------------------------------------------------------------------------------------------------------------------

--STEP 5 ASSIGNING patient_id to each patient
ALTER TABLE [dbo].[tblHealthcare]
ADD ID INT IDENTITY(1,1)

EXEC sp_rename 'tblHealthcare.ID', 'patient_ID', 'COLUMN';
 
 ----------------------------------------------------------------------------------------------------

SELECT *
INTO tblHealthcare1
FROM tblHealthcare

--STEP 7 CREATING DIMENSIONAL TABLES

---1. Blood type dim table
CREATE TABLE dimBlood_Type 
(
    Blood_typeID INT PRIMARY KEY IDENTITY(1,1),  
    Blood_Type VARCHAR(20)                        
);

INSERT INTO [dbo].[dimBlood_Type] ([Blood_Type])
SELECT DISTINCT [Blood_Type] 
FROM [dbo].[tblHealthcare1]

---2. Medical condition Dim table
CREATE TABLE dimMedicalCondition
(
	Medical_ConditionID INT PRIMARY KEY IDENTITY(1,1),
	Medical_Condition VARCHAR(20)
)

INSERT INTO [dbo].[dimMedicalCondition] (Medical_Condition)
SELECT DISTINCT [Medical_Condition] 
FROM [dbo].[tblHealthcare1]

---3. Dim Insurance Provider table
CREATE TABLE DimInsuranceProvider
(
	Insurance_ProviderID INT PRIMARY KEY IDENTITY (1,1),
	Insurance_Provider VARCHAR(50)
)

INSERT INTO DimInsuranceProvider (Insurance_Provider)
SELECT DISTINCT [Insurance_Provider]
FROM tblHealthcare1 

---4. Dim Admission Type
CREATE TABLE DimAdmissionType
(
	Admission_TypeID INT PRIMARY KEY IDENTITY(1,1),
	Admission_Type VARCHAR(30)
)

INSERT INTO DimAdmissionType ([Admission_Type])
SELECT DISTINCT [Admission_Type] 
FROM [dbo].[tblHealthcare1]

---5. Dim Medication table
CREATE TABLE DimMedication
(
	MedicationID INT PRIMARY KEY IDENTITY(1,1),
	Medication VARCHAR(20) 
)

INSERT INTO DimMedication ([Medication])
SELECT DISTINCT [Medication] 
FROM [dbo].[tblHealthcare1]

---6. Dim Test results
CREATE TABLE DimTestResults
(
	Test_ResultsID INT PRIMARY KEY IDENTITY(1,1),
	Test_Results VARCHAR(30)
)

INSERT INTO [dbo].[DimTestResults]
SELECT DISTINCT ([Test_Results])
FROM tblHealthcare1

---7. Dim Age table
CREATE TABLE DimAge2
( 
	AgeID INT PRIMARY KEY IDENTITY(1,1),
	Age INT,
	AgeGroup NVARCHAR(30),
	AgeCategory VARCHAR(40)
)

INSERT INTO [dbo].[DimAge2] ([Age])
SELECT DISTINCT ([Age])
FROM tblHealthcare1

UPDATE DimAge2
SET 
    AgeGroup = 
        CASE
            WHEN Age BETWEEN 1 AND 12 THEN '1-12'
            WHEN Age BETWEEN 13 AND 19 THEN '13-19'
            WHEN Age BETWEEN 20 AND 40 THEN '20-40'
            WHEN Age BETWEEN 41 AND 60 THEN '41-60'
            WHEN Age >= 61 THEN '61+'
        END,
    AgeCategory =
        CASE
            WHEN Age BETWEEN 1 AND 12 THEN 'Kid'
            WHEN Age BETWEEN 13 AND 19 THEN 'Teenage'
            WHEN Age BETWEEN 20 AND 40 THEN 'Adult'
            WHEN Age BETWEEN 41 AND 60 THEN 'MiddleAge'
            WHEN Age >= 61 THEN 'OldAge'
        END;

CREATE TABLE DimAgeCategory
(
	AgeCategoryID INT PRIMARY KEY IDENTITY(1,1),
	AgeGroup NVARCHAR(30),
	AgeCategory VARCHAR(20)
)

INSERT INTO [dbo].[DimAgeCategory] ([AgeGroup])
SELECT DISTINCT ([AgeGroup])
FROM DimAge2


UPDATE DimAgeCategory
SET 
    AgeCategory =
        CASE
            WHEN AgeGroup = '13-19' THEN 'Teenage'
            WHEN AgeGroup = '20-40' THEN 'Adult'
            WHEN AgeGroup = '41-60' THEN 'MiddleAge'
            WHEN AgeGroup = '61+' THEN 'OldAge'
        END;

--------------------updating age category to [dbo].[FactHealthcare]
UPDATE [dbo].[FactHealthcare]
SET 
    AgeCategory = 
        CASE
            WHEN Age BETWEEN 1 AND 12 THEN 'Kid'
            WHEN Age BETWEEN 13 AND 19 THEN 'Teenage'
            WHEN Age BETWEEN 20 AND 40 THEN 'Adult'
            WHEN Age BETWEEN 41 AND 60 THEN 'MiddleAge'
            WHEN Age >= 61 THEN 'OldAge'
        END

------------------------------------------------------------------------------------------------------------------

--STEP 8 CREATING FACT TABLE

CREATE TABLE FactHealthcareData
(
	Name VARCHAR(50),
    Age INT,
    Gender VARCHAR(50),
    Date_of_Admission DATE,                 
    Doctor VARCHAR(50),
    Hospital NVARCHAR(50),
    Billing_Amount FLOAT,
    Room_Number INT,
    Discharge_Date DATE,
    Blood_Type NVARCHAR(50),
    Medical_Condition VARCHAR(50),
    Insurance_Provider VARCHAR(50),
    Admission_Type VARCHAR(50),
    Medication VARCHAR(50),
    Test_Results VARCHAR(50),
    Blood_TypeID INT, 
    Admission_TypeID INT, 
    AgeCategoryID INT,
    Insurance_ProviderID INT, 
    MedicationID INT, 
    Test_ResultsID INT,
	AgeCategory VARCHAR(50)
)

INSERT INTO FactHealthcareData (
    Name,
    Age,
    Gender,
    Date_of_Admission,                 
    Doctor,
    Hospital,
    Billing_Amount,
    Room_Number,
    Discharge_Date,
    Blood_Type,
    Medical_Condition,
    Insurance_Provider,
    Admission_Type,
    Medication,
    Test_Results,
    Blood_TypeID,
    Admission_TypeID,
    AgeCategoryID,				
    Insurance_ProviderID,
    Medical_ConditionID,
    MedicationID,
    Test_ResultsID,
	AgeCategory
)

SELECT
    F.Name,
    F.Age,
    F.Gender,
    F.Date_of_Admission,                 
    F.Doctor,
    F.Hospital,
    F.Billing_Amount,
    F.Room_Number,
    F.Discharge_Date,
    F.Blood_Type,
    F.Medical_Condition,
    F.Insurance_Provider,
    F.Admission_Type,
    F.Medication,
    F.Test_Results,
    B.Blood_TypeID,
    A.Admission_TypeID,
    C.AgeCategoryID,
    I.Insurance_ProviderID,
    M.Medical_ConditionID,
    D.MedicationID,
    T.Test_ResultsID,
	C.AgeCategory
FROM [dbo].[FactHealthcare] AS F	SELECT * FROM FactHealthcareData
JOIN [dbo].[dimBlood_Type] AS B
    ON B.Blood_Type = F.Blood_Type
JOIN [dbo].[DimAdmissionType] AS A
    ON A.Admission_Type = F.Admission_Type
JOIN [dbo].[DimAgeCategory] AS C
    ON C.AgeCategory = F.AgeCategory
JOIN [dbo].[DimInsuranceProvider] AS I
    ON I.Insurance_Provider = F.Insurance_Provider
JOIN [dbo].[dimMedicalCondition] AS M
    ON M.Medical_Condition = F.Medical_Condition
JOIN [dbo].[DimMedication] AS D
    ON D.Medication = F.Medication
JOIN [dbo].[DimTestResults] AS T
    ON T.Test_Results = F.Test_Results;

---------Creating primary key PatientID to FactHealthcareData
ALTER TABLE FactHealthcareData
ADD PatientID INT PRIMARY KEY IDENTITY(1,1)

SELECT *
FROM FactHealthcareData

-------------------------------------------------------------------------------------------------------------------------------------

--STEP 9 ASSIGNING FOREIGN KEYS

ALTER TABLE [dbo].[FactHealthcareData]
ADD CONSTRAINT FK_BloodType
FOREIGN KEY (Blood_TypeID)
REFERENCES [dbo].[dimBlood_Type] (Blood_TypeID);

ALTER TABLE [dbo].[FactHealthcareData]
ADD CONSTRAINT FK_AdmissionType
FOREIGN KEY (Admission_TypeID)
REFERENCES [dbo].[DimAdmissionType] (Admission_TypeID);

ALTER TABLE [dbo].[FactHealthcareData]
ADD CONSTRAINT FK_AgeCategory
FOREIGN KEY (AgeCategoryID)
REFERENCES [dbo].[DimAgeCategory] (AgeCategoryID);

ALTER TABLE [dbo].[FactHealthcareData]
ADD CONSTRAINT FK_InsuranceProvider
FOREIGN KEY (Insurance_ProviderID)
REFERENCES [dbo].[DimInsuranceProvider] (Insurance_ProviderID);

ALTER TABLE [dbo].[FactHealthcareData]
ADD CONSTRAINT FK_Medication
FOREIGN KEY (MedicationID)
REFERENCES [dbo].[DimMedication] (MedicationID);

ALTER TABLE [dbo].[FactHealthcareData]
ADD CONSTRAINT FK_TestResults
FOREIGN KEY (Test_ResultsID)
REFERENCES [dbo].[DimTestResults] (Test_ResultsID);

ALTER TABLE [dbo].[FactHealthcareData]
ADD CONSTRAINT FK_MedicalCondition
FOREIGN KEY (Medical_ConditionID)
REFERENCES [dbo].[dimMedicalCondition] (Medical_ConditionID)
