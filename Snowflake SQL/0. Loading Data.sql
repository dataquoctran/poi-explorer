-- =====================================================================================================================================================================================
-- PRE-SECTION: RAW Layer — Create Table & Load CSV
-- Schema:  RAW_POI
-- =====================================================================================================================================================================================
 
-- Step 1: Create database and schema
USE ROLE TRAINING_ROLE;
USE WAREHOUSE EAGLE_WH;

CREATE DATABASE IF NOT EXISTS POI_PROJECT;
USE DATABASE POI_PROJECT;
 
CREATE SCHEMA IF NOT EXISTS RAW_POI;
USE SCHEMA RAW_POI;

SHOW TABLES;

-- Step 2: Create the raw table (no transformations — source as-is)
CREATE OR REPLACE TABLE RAW_POI.POI_RAW (
    POI_ID          VARCHAR(20),
    LATITUDE        FLOAT,
    LONGITUDE       FLOAT,
    NAME            VARCHAR(500),
    CATEGORY        VARCHAR(100),
    SUB_CATEGORY_1  VARCHAR(100),
    SUB_CATEGORY_2  VARCHAR(100),
    SUB_CATEGORY_3  VARCHAR(100),
    SUB_CATEGORY_4  VARCHAR(100),
    SUB_CATEGORY_5  VARCHAR(100),
    SUB_CATEGORY_6  VARCHAR(100),
    SUB_CATEGORY_7  VARCHAR(100),
    CUISINE         VARCHAR(500),
    HOUSE_NUMBER    VARCHAR(50),
    STREET          VARCHAR(500),
    CITY            VARCHAR(100),
    POSTCODE        VARCHAR(10),
    STATE           VARCHAR(50),
    PHONE           VARCHAR(500),
    WEBSITE         VARCHAR(1000),
    OPENING_HOURS   VARCHAR(500),
    WHEELCHAIR      VARCHAR(10),
    FEE             VARCHAR(500)
);

SELECT * FROM POI_RAW;

-- Step 3: Create a file format for the CSV
CREATE OR REPLACE FILE FORMAT RAW_POI.CSV_FORMAT
    TYPE                = 'CSV'
    FIELD_DELIMITER     = ','
    RECORD_DELIMITER    = '\n'
    SKIP_HEADER         = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF             = ('')
    EMPTY_FIELD_AS_NULL = TRUE
    ENCODING            = 'UTF-8';

-- Step 4: Create an internal stage
CREATE STAGE IF NOT EXISTS RAW_POI.POI_STAGE
    FILE_FORMAT = RAW_POI.CSV_FORMAT;

-- Step 5: Upload data to STAGE
--> Ingestion --> Add Data --> Load from Stage --> Database = POI_Project.Raw_POI ---> Stage = POI_Stage
LIST @RAW_POI.POI_STAGE;

-- Step 6: Load data from stage into raw table
COPY INTO RAW_POI.POI_RAW
FROM @RAW_POI.POI_STAGE/mn_poi_final_v2.csv
FILE_FORMAT = RAW_POI.CSV_FORMAT
ON_ERROR = 'CONTINUE'
FORCE = TRUE;

-- Step 7: Verify the load
SELECT COUNT(*)            AS TOTAL_ROWS     FROM RAW_POI.POI_RAW;
SELECT COUNT(DISTINCT CITY) AS UNIQUE_CITIES  FROM RAW_POI.POI_RAW;
SELECT CATEGORY, COUNT(*)  AS CNT
FROM RAW_POI.POI_RAW
GROUP BY CATEGORY
ORDER BY CNT DESC;

-- Step 8: Preview data
SELECT * FROM RAW_POI.POI_RAW LIMIT 10;