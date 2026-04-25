-- =====================================================================================================================================================================================
-- SEIS732 DATA WAREHOUSE
-- FINAL PROJECT
-- STUDENT: HUNG TRAN - EAGLE
-- Project: Point of Interest around Twin Cities area
-- =====================================================================================================================================================================================

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

-- =====================================================================================================================================================================================
-- SECTION 1: Curation Layer 
-- Schema:  RAW_POI
-- =====================================================================================================================================================================================

USE ROLE TRAINING_ROLE;
USE WAREHOUSE EAGLE_WH;
USE DATABASE POI_PROJECT;

-- Create curation schema
CREATE SCHEMA IF NOT EXISTS CUR_POI;
USE SCHEMA CUR_POI;

-- ============================================================
-- SEMANTIC TAG SETUP
-- Apply tag "EAGLE" to all curation objects
-- ============================================================
CREATE TAG IF NOT EXISTS POI_PROJECT.CUR_POI.EAGLE_TAG;

-- ============================================================
-- STEP 1: Base clean table — Standardize nulls & trim whitespace
-- Transformation: Replace empty strings with NULL,trim whitespace from text fields
-- Purpose: Raw CSV data often has messy whitespace and empty strings '' instead of real NULL. 
-- This step cleans all of that up. TRIM removes spaces, NULLIF(..., '') converts empty strings to proper NULL, and UPPER forces STATE to consistent uppercase. 
-- Every downstream step benefits from this being done first.
-- ============================================================

CREATE OR REPLACE TABLE CUR_POI.CUR_POI_BASE AS
SELECT
    POI_ID,
    LATITUDE,
    LONGITUDE,
    TRIM(NAME)                                          AS NAME,
    TRIM(CATEGORY)                                      AS CATEGORY,
    NULLIF(TRIM(SUB_CATEGORY_1), '')                    AS SUB_CATEGORY_1,
    NULLIF(TRIM(SUB_CATEGORY_2), '')                    AS SUB_CATEGORY_2,
    NULLIF(TRIM(SUB_CATEGORY_3), '')                    AS SUB_CATEGORY_3,
    NULLIF(TRIM(SUB_CATEGORY_4), '')                    AS SUB_CATEGORY_4,
    NULLIF(TRIM(SUB_CATEGORY_5), '')                    AS SUB_CATEGORY_5,
    NULLIF(TRIM(SUB_CATEGORY_6), '')                    AS SUB_CATEGORY_6,
    NULLIF(TRIM(SUB_CATEGORY_7), '')                    AS SUB_CATEGORY_7,
    NULLIF(TRIM(CUISINE), '')                           AS CUISINE,
    NULLIF(TRIM(HOUSE_NUMBER), '')                      AS HOUSE_NUMBER,
    NULLIF(TRIM(STREET), '')                            AS STREET,
    NULLIF(TRIM(CITY), '')                              AS CITY,
    NULLIF(TRIM(POSTCODE), '')                          AS POSTCODE,
    UPPER(NULLIF(TRIM(STATE), ''))                      AS STATE,
    NULLIF(TRIM(PHONE), '')                             AS PHONE,
    NULLIF(TRIM(WEBSITE), '')                           AS WEBSITE,
    NULLIF(TRIM(OPENING_HOURS), '')                     AS OPENING_HOURS,
    NULLIF(TRIM(WHEELCHAIR), '')                        AS WHEELCHAIR,
    NULLIF(TRIM(FEE), '')                               AS FEE
FROM RAW_POI.POI_RAW;

SELECT * FROM CUR_POI_BASE;

-- Count rows and columns to see changes
SELECT 
    (SELECT COUNT(*) FROM CUR_POI.CUR_POI_BASE) AS TOTAL_ROWS,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = 'CUR_POI' 
     AND TABLE_NAME = 'CUR_POI_BASE') AS TOTAL_COLUMNS;

ALTER TABLE CUR_POI.CUR_POI_BASE
    SET TAG POI_PROJECT.CUR_POI.EAGLE_TAG = 'EagleProject';

-- ============================================================
-- STEP 2: Address completeness flag
-- Transformation: Flag records that have a full address
--                 vs partial vs no address at all
-- Purpose: Not every POI has a complete address — parks, nature areas, and landmarks often only have coordinates. 
-- This step grades each record as Full, Partial, or None so downstream users know how reliable the address data is. 
-- It also builds a single FULL_ADDRESS string by concatenating the address parts, useful for display in dashboards.
-- ============================================================
CREATE OR REPLACE TABLE CUR_POI.CUR_POI_ADDRESS AS
SELECT
    *,
    CASE
        WHEN HOUSE_NUMBER IS NOT NULL
         AND STREET       IS NOT NULL
         AND CITY         IS NOT NULL
         AND POSTCODE     IS NOT NULL
        THEN 'Full'
        WHEN CITY IS NOT NULL OR STREET IS NOT NULL
        THEN 'Partial'
        ELSE 'None'
    END                                                 AS ADDRESS_COMPLETENESS,

    -- Full formatted address for display
    -- Make sure what even if the address is missing just city, or just postal code, we still concat into Full_Address
    -- Therefore, Partial will still be useful 
    -- NULL Address_Completeness will automatically be NULL in Full_Address
CASE 
    WHEN ADDRESS_COMPLETENESS = 'None' THEN NULL
    ELSE
        NULLIF(
            TRIM(
                CONCAT_WS(' ',
                    IFNULL(TRIM(HOUSE_NUMBER), ''),
                    IFNULL(TRIM(STREET), ''),
                    IFNULL(TRIM(CITY), ''),
                    IFNULL(TRIM(STATE), ''),
                    IFNULL(TRIM(POSTCODE), '')
                )
            ),
        '')
END                                             AS FULL_ADDRESS
FROM CUR_POI.CUR_POI_BASE;

SELECT * FROM CUR_POI_ADDRESS;  

-- Count rows and columns to see changes
SELECT 
    (SELECT COUNT(*) FROM CUR_POI.CUR_POI_ADDRESS) AS TOTAL_ROWS,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = 'CUR_POI' 
     AND TABLE_NAME = 'CUR_POI_ADDRESS') AS TOTAL_COLUMNS;

-- Address completeness breakdown
SELECT ADDRESS_COMPLETENESS, COUNT(*) AS CNT
FROM CUR_POI.CUR_POI_ADDRESS
GROUP BY ADDRESS_COMPLETENESS ORDER BY CNT DESC;

ALTER TABLE CUR_POI.CUR_POI_ADDRESS
    SET TAG POI_PROJECT.CUR_POI.EAGLE_TAG = 'EagleProject';

-- ============================================================
-- STEP 3: Enrichment flags
-- Transformation: Add Yes/No indicator columns for
--                 key attributes useful for filtering
-- Purpose: These Y/N flags make filtering very easy in dashboards and queries — instead of writing WHERE PHONE IS NOT NULL everywhere, you just do WHERE HAS_PHONE = 'Y'.
-- The DATA_QUALITY_SCORE (0-5) adds up how complete each record is — phone, website, hours, full address, and sub-category each contribute 1 point. This lets you filter for high-quality records or identify which POIs need enrichment.
-- The CATEGORY_DEPTH (1-7) counts how many sub-category levels are filled. A restaurant with fast_food > seafood > cajun scores 3, while a basic park scores 1.
-- ============================================================
CREATE OR REPLACE TABLE CUR_POI.CUR_POI_ENRICHED AS
SELECT
    *,
    -- Accessibility flag
    IFF(UPPER(WHEELCHAIR) = 'YES', 'Y', 'N')           AS IS_WHEELCHAIR_ACCESSIBLE,

    -- Has contact info flags
    IFF(PHONE IS NOT NULL, 'Y', 'N')                    AS HAS_PHONE,
    IFF(WEBSITE IS NOT NULL, 'Y', 'N')                  AS HAS_WEBSITE,
    IFF(OPENING_HOURS IS NOT NULL, 'Y', 'N')            AS HAS_HOURS,
    IFF(FEE = 'yes', 'Y', 'N')                          AS HAS_FEE,

    -- Data quality score (0-5 based on how complete the record is)
    (
        IFF(PHONE        IS NOT NULL, 1, 0) +
        IFF(WEBSITE      IS NOT NULL, 1, 0) +
        IFF(OPENING_HOURS IS NOT NULL, 1, 0) +
        IFF(ADDRESS_COMPLETENESS = 'Full', 1, 0) +
        IFF(SUB_CATEGORY_2 IS NOT NULL, 1, 0)
    )                                                   AS DATA_QUALITY_SCORE,

    -- Sub-category depth (how detailed the classification is)
    (
        IFF(SUB_CATEGORY_1 IS NOT NULL, 1, 0) +
        IFF(SUB_CATEGORY_2 IS NOT NULL, 1, 0) +
        IFF(SUB_CATEGORY_3 IS NOT NULL, 1, 0) +
        IFF(SUB_CATEGORY_4 IS NOT NULL, 1, 0) +
        IFF(SUB_CATEGORY_5 IS NOT NULL, 1, 0) +
        IFF(SUB_CATEGORY_6 IS NOT NULL, 1, 0) +
        IFF(SUB_CATEGORY_7 IS NOT NULL, 1, 0)
    )                                                   AS CATEGORY_DEPTH
FROM CUR_POI.CUR_POI_ADDRESS;

SELECT * FROM CUR_POI_ENRICHED;

-- Count rows and columns to see changes
SELECT 
    (SELECT COUNT(*) FROM CUR_POI.CUR_POI_ENRICHED) AS TOTAL_ROWS,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = 'CUR_POI' 
     AND TABLE_NAME = 'CUR_POI_ENRICHED') AS TOTAL_COLUMNS;

-- Data quality score distribution
SELECT DATA_QUALITY_SCORE, COUNT(*) AS CNT
FROM CUR_POI.CUR_POI_ENRICHED
GROUP BY DATA_QUALITY_SCORE ORDER BY DATA_QUALITY_SCORE DESC;

ALTER TABLE CUR_POI.CUR_POI_ENRICHED
    SET TAG POI_PROJECT.CUR_POI.EAGLE_TAG = 'EagleProject';

-- ============================================================
-- STEP 4: Opening hours classification
-- Transformation: Parse opening hours text into a business-friendly label
-- Purpose: Raw opening hours like "Mo-Fr 07:00-17:00; Sa 08:00-14:00" are hard to filter on directly. 
-- This step parses the text pattern and buckets each POI into a human-readable schedule label. 
-- The IS_LATE_NIGHT flag catches venues open past midnight (bars, 24-hour diners) by looking for hour values like 02:00, 24:00 in the string — useful for nightlife analysis.
-- ============================================================
CREATE OR REPLACE TABLE CUR_POI.CUR_POI_HOURS AS
SELECT
    *,
    CASE
        WHEN OPENING_HOURS IS NULL
            THEN 'Unknown'
        WHEN UPPER(OPENING_HOURS) LIKE '%24/7%'
          OR UPPER(OPENING_HOURS) LIKE '%00:00-24:00%'
          OR UPPER(OPENING_HOURS) LIKE '%0:00-24:00%'
            THEN '24/7'
        WHEN UPPER(OPENING_HOURS) LIKE '%MO%'
         AND UPPER(OPENING_HOURS) LIKE '%SA%'
         AND UPPER(OPENING_HOURS) NOT LIKE '%SU%'
            THEN 'Mon-Sat'
        WHEN UPPER(OPENING_HOURS) LIKE '%MO%'
         AND UPPER(OPENING_HOURS) LIKE '%FR%'
         AND UPPER(OPENING_HOURS) NOT LIKE '%SA%'
         AND UPPER(OPENING_HOURS) NOT LIKE '%SU%'
            THEN 'Weekdays Only'
        WHEN UPPER(OPENING_HOURS) LIKE '%SA%'
          OR UPPER(OPENING_HOURS) LIKE '%SU%'
            THEN 'Includes Weekends'
        ELSE 'Other Schedule'
    END                                                 AS HOURS_CATEGORY,

    -- Flag for late night (open past midnight)
    IFF(
        OPENING_HOURS LIKE '%02:00%'
        OR OPENING_HOURS LIKE '%03:00%'
        OR OPENING_HOURS LIKE '%24:00%'
        OR OPENING_HOURS LIKE '%01:00%',
        'Y', 'N'
    )                                                   AS IS_LATE_NIGHT

FROM CUR_POI.CUR_POI_ENRICHED;

SELECT * FROM CUR_POI_HOURS;

-- Count rows and columns to see changes
SELECT 
    (SELECT COUNT(*) FROM CUR_POI.CUR_POI_HOURS) AS TOTAL_ROWS,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = 'CUR_POI' 
     AND TABLE_NAME = 'CUR_POI_HOURS') AS TOTAL_COLUMNS;

-- Count of each HOURS_CATEGORY
SELECT HOURS_CATEGORY, COUNT(*) AS CNT
FROM CUR_POI.CUR_POI_HOURS
GROUP BY HOURS_CATEGORY
ORDER BY CNT DESC;

-- Count of each IS_LATE_NIGHT
SELECT IS_LATE_NIGHT, COUNT(*) AS CNT
FROM CUR_POI.CUR_POI_HOURS
GROUP BY IS_LATE_NIGHT
ORDER BY CNT DESC;

ALTER TABLE CUR_POI.CUR_POI_HOURS
    SET TAG POI_PROJECT.CUR_POI.EAGLE_TAG = 'EagleProject';

-- ============================================================
-- STEP 5: City tier classification
-- Transformation: Classify cities into Metro Core, Inner Suburb, Outer Suburb
-- Purpose: Great for comparing POI density and variety between urban and suburban areas. 
-- GEO_QUADRANT uses the actual lat/lon coordinates to split the metro into four geographic zones, useful for spatial analysis without needing a mapping tool.
-- ============================================================
CREATE OR REPLACE TABLE CUR_POI.CUR_POI_FINAL AS
SELECT
    *,
    CASE
        WHEN CITY IN ('Minneapolis', 'Saint Paul', 'St. Paul')
            THEN 'Metro Core'
        WHEN CITY IN ('Bloomington','Plymouth','Brooklyn Park','Maple Grove',
                      'Woodbury','Eagan','Burnsville','Eden Prairie',
                      'Minnetonka','Edina','St. Louis Park','Richfield',
                      'Roseville','Maplewood','Blaine','Coon Rapids')
            THEN 'Inner Suburb'
        WHEN CITY IS NOT NULL
            THEN 'Outer Suburb'
        ELSE 'Unknown'
    END                                                 AS CITY_TIER,

    -- Geographic quadrant based on lat/lon center of Twin Cities
    CASE
        WHEN LATITUDE  >= 44.98 AND LONGITUDE < -93.27  THEN 'Northwest'
        WHEN LATITUDE  >= 44.98 AND LONGITUDE >= -93.27 THEN 'Northeast'
        WHEN LATITUDE  <  44.98 AND LONGITUDE < -93.27  THEN 'Southwest'
        ELSE                                                  'Southeast'
    END                                                 AS GEO_QUADRANT

FROM CUR_POI.CUR_POI_HOURS;

SELECT * FROM CUR_POI_FINAL;

-- Count rows and columns to see changes
SELECT 
    (SELECT COUNT(*) FROM CUR_POI.CUR_POI_FINAL) AS TOTAL_ROWS,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = 'CUR_POI' 
     AND TABLE_NAME = 'CUR_POI_FINAL') AS TOTAL_COLUMNS;

-- Count of each CITY_TIER
SELECT CITY_TIER, COUNT(*) AS CNT
FROM CUR_POI.CUR_POI_FINAL
GROUP BY CITY_TIER
ORDER BY CNT DESC;

-- Count of each GEO_QUADRANT
SELECT GEO_QUADRANT, COUNT(*) AS CNT
FROM CUR_POI.CUR_POI_FINAL
GROUP BY GEO_QUADRANT
ORDER BY CNT DESC;

ALTER TABLE CUR_POI.CUR_POI_FINAL
    SET TAG POI_PROJECT.CUR_POI.EAGLE_TAG = 'EagleProject';

-- ============================================================
-- STEP 6: Create a clean VIEW on top of the final table
-- Transformation: Useful as the main entry point for downstream layers
-- Purpose: This is just a SELECT of the most useful columns from CUR_POI_FINAL, presented as a view. 
-- It hides the raw/intermediate columns and gives the aggregation layer (Worksheet 3) a clean, stable interface to query from. Think of it as the "published API" of the curation layer.
-- ============================================================
CREATE OR REPLACE VIEW CUR_POI.CUR_POI_VIEW AS
SELECT
    POI_ID,
    NAME,
    CATEGORY,
    SUB_CATEGORY_1,
    SUB_CATEGORY_2,
    SUB_CATEGORY_3,
    CUISINE,
    FULL_ADDRESS,
    CITY,
    CITY_TIER,
    GEO_QUADRANT,
    STATE,
    POSTCODE,
    PHONE,
    WEBSITE,
    OPENING_HOURS,
    HOURS_CATEGORY,
    IS_LATE_NIGHT,
    IS_WHEELCHAIR_ACCESSIBLE,
    HAS_PHONE,
    HAS_WEBSITE,
    HAS_HOURS,
    HAS_FEE,
    DATA_QUALITY_SCORE,
    CATEGORY_DEPTH,
    ADDRESS_COMPLETENESS,
    LATITUDE,
    LONGITUDE
FROM CUR_POI.CUR_POI_FINAL;

SELECT * FROM CUR_POI_VIEW;

-- Count rows and columns to see changes
SELECT 
    (SELECT COUNT(*) FROM CUR_POI.CUR_POI_VIEW) AS TOTAL_ROWS,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = 'CUR_POI' 
     AND TABLE_NAME = 'CUR_POI_VIEW') AS TOTAL_COLUMNS;

ALTER VIEW CUR_POI.CUR_POI_VIEW
    SET TAG POI_PROJECT.CUR_POI.EAGLE_TAG = 'EagleProject';

-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- Row count check
SELECT COUNT(*) AS TOTAL_ROWS FROM CUR_POI.CUR_POI_FINAL;

-- Address completeness breakdown
SELECT ADDRESS_COMPLETENESS, COUNT(*) AS CNT
FROM CUR_POI.CUR_POI_FINAL
GROUP BY ADDRESS_COMPLETENESS ORDER BY CNT DESC;

-- City tier breakdown
SELECT CITY_TIER, COUNT(*) AS CNT
FROM CUR_POI.CUR_POI_FINAL
GROUP BY CITY_TIER ORDER BY CNT DESC;

-- Hours category breakdown
SELECT HOURS_CATEGORY, COUNT(*) AS CNT
FROM CUR_POI.CUR_POI_FINAL
GROUP BY HOURS_CATEGORY ORDER BY CNT DESC;

-- Data quality score distribution
SELECT DATA_QUALITY_SCORE, COUNT(*) AS CNT
FROM CUR_POI.CUR_POI_FINAL
GROUP BY DATA_QUALITY_SCORE ORDER BY DATA_QUALITY_SCORE DESC;

-- Late night venues
SELECT NAME, CITY, CATEGORY, OPENING_HOURS
FROM CUR_POI.CUR_POI_FINAL
WHERE IS_LATE_NIGHT = 'Y'
LIMIT 10;

-- Preview the final view
SELECT * FROM CUR_POI.CUR_POI_VIEW LIMIT 10;

-- =====================================================================================================================================================================================
-- SECTION 2: Stored Procedure
-- Schema:  CUR_POI
-- =====================================================================================================================================================================================

USE DATABASE POI_PROJECT;
USE SCHEMA CUR_POI;

CREATE OR REPLACE PROCEDURE CUR_POI.SP_CURATE_POI()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN

    -- --------------------------------------------------------
    -- TRANSFORMATION 1: Business Type Classification
    -- Classify each POI name into:
    --   National Chain, Corporate, Local Brand, Independent
    -- --------------------------------------------------------
    CREATE OR REPLACE TABLE CUR_POI.CUR_POI_NAMES AS
    SELECT
        *,
        CASE
            WHEN UPPER(NAME) LIKE '%LLC%'
              OR UPPER(NAME) LIKE '%INC%'
              OR UPPER(NAME) LIKE '%CORP%'
              OR UPPER(NAME) LIKE '%LTD%'
            THEN 'Corporate'
            WHEN UPPER(NAME) LIKE '%MCDONALD%'
              OR UPPER(NAME) LIKE '%STARBUCKS%'
              OR UPPER(NAME) LIKE '%SUBWAY%'
              OR UPPER(NAME) LIKE '%WALMART%'
              OR UPPER(NAME) LIKE '%TARGET%'
              OR UPPER(NAME) LIKE '%WALGREENS%'
              OR UPPER(NAME) LIKE '%CVS%'
              OR UPPER(NAME) LIKE '%ALDI%'
              OR UPPER(NAME) LIKE '%DOMINO%'
              OR UPPER(NAME) LIKE '%TACO BELL%'
              OR UPPER(NAME) LIKE '%BURGER KING%'
              OR UPPER(NAME) LIKE '%WENDY%'
              OR UPPER(NAME) LIKE '%CHIPOTLE%'
              OR UPPER(NAME) LIKE '%CHICK-FIL-A%'
              OR UPPER(NAME) LIKE '%DUNKIN%'
              OR UPPER(NAME) LIKE '%PANERA%'
              OR UPPER(NAME) LIKE '%CULVER%'
              OR UPPER(NAME) LIKE '%HOLIDAY%'
              OR UPPER(NAME) LIKE '%KWIK TRIP%'
            THEN 'National Chain'
            WHEN UPPER(NAME) LIKE '%MINNEAPOLIS%'
              OR UPPER(NAME) LIKE '%SAINT PAUL%'
              OR UPPER(NAME) LIKE '%ST PAUL%'
              OR UPPER(NAME) LIKE '%MINNESOTA%'
              OR UPPER(NAME) LIKE '%TWIN CITIES%'
              OR UPPER(NAME) LIKE '%MN %'
            THEN 'Local Brand'
            ELSE 'Independent'
        END                                             AS BUSINESS_TYPE,
        IFF(NAME REGEXP '[0-9]', 'Y', 'N')             AS NAME_HAS_NUMBER,
        CASE
            WHEN LENGTH(NAME) <= 10 THEN 'Short'
            WHEN LENGTH(NAME) <= 25 THEN 'Medium'
            ELSE 'Long'
        END                                             AS NAME_LENGTH_BUCKET
    FROM CUR_POI.CUR_POI_FINAL;

    -- --------------------------------------------------------
    -- TRANSFORMATION 2: Ethnicity Reference
    -- Scan ALL 7 sub_category slots for cuisine/type values
    -- that map to an ethnicity or cultural region.
    -- Priority: Asian > American > Latin American >
    --           Middle Eastern & African > European > NULL
    -- --------------------------------------------------------
    CREATE OR REPLACE TABLE CUR_POI.CUR_POI_PROCESSED AS
    SELECT
        *,
        CASE
            -- Asian
            WHEN LOWER(SUB_CATEGORY_1) IN ('vietnamese','chinese','japanese','korean','thai','asian','filipino','malaysian','taiwanese','lao','laotian','hmong','cantonese','sichuan','dim_sum','ramen','sushi','teppanyaki','poke','mongolian_grill','bubble_tea','milk_tea','tibetan','nepalese','himalayan','indonesian','singaporean')
              OR LOWER(SUB_CATEGORY_2) IN ('vietnamese','chinese','japanese','korean','thai','asian','filipino','malaysian','taiwanese','lao','laotian','hmong','cantonese','sichuan','dim_sum','ramen','sushi','teppanyaki','poke','mongolian_grill','bubble_tea','milk_tea','tibetan','nepalese','himalayan','indonesian','singaporean')
              OR LOWER(SUB_CATEGORY_3) IN ('vietnamese','chinese','japanese','korean','thai','asian','filipino','malaysian','taiwanese','lao','laotian','hmong','cantonese','sichuan','dim_sum','ramen','sushi','teppanyaki','poke','mongolian_grill','bubble_tea','milk_tea','tibetan','nepalese','himalayan','indonesian','singaporean')
              OR LOWER(SUB_CATEGORY_4) IN ('vietnamese','chinese','japanese','korean','thai','asian','filipino','malaysian','taiwanese','lao','laotian','hmong','cantonese','sichuan','dim_sum','ramen','sushi','teppanyaki','poke','mongolian_grill','bubble_tea','milk_tea','tibetan','nepalese','himalayan','indonesian','singaporean')
              OR LOWER(SUB_CATEGORY_5) IN ('vietnamese','chinese','japanese','korean','thai','asian','filipino','malaysian','taiwanese','lao','laotian','hmong','cantonese','sichuan','dim_sum','ramen','sushi','teppanyaki','poke','mongolian_grill','bubble_tea','milk_tea','tibetan','nepalese','himalayan','indonesian','singaporean')
              OR LOWER(SUB_CATEGORY_6) IN ('vietnamese','chinese','japanese','korean','thai','asian','filipino','malaysian','taiwanese','lao','laotian','hmong','cantonese','sichuan','dim_sum','ramen','sushi','teppanyaki','poke','mongolian_grill','bubble_tea','milk_tea','tibetan','nepalese','himalayan','indonesian','singaporean')
              OR LOWER(SUB_CATEGORY_7) IN ('vietnamese','chinese','japanese','korean','thai','asian','filipino','malaysian','taiwanese','lao','laotian','hmong','cantonese','sichuan','dim_sum','ramen','sushi','teppanyaki','poke','mongolian_grill','bubble_tea','milk_tea','tibetan','nepalese','himalayan','indonesian','singaporean')
            THEN 'Asian'

            -- American
            WHEN LOWER(SUB_CATEGORY_1) IN ('american','burger','bbq','barbecue','southern','soul_food','comfort_food','diner','hot_dog','hotdog','cheesesteak','american_indian','indigenous','hawaiian','tex-mex','cajun','bar_and_grill','steak','steak_house','fried_chicken','wings','supper_club','regional')
              OR LOWER(SUB_CATEGORY_2) IN ('american','burger','bbq','barbecue','southern','soul_food','comfort_food','diner','hot_dog','hotdog','cheesesteak','american_indian','indigenous','hawaiian','tex-mex','cajun','bar_and_grill','steak','steak_house','fried_chicken','wings','supper_club','regional')
              OR LOWER(SUB_CATEGORY_3) IN ('american','burger','bbq','barbecue','southern','soul_food','comfort_food','diner','hot_dog','hotdog','cheesesteak','american_indian','indigenous','hawaiian','tex-mex','cajun','bar_and_grill','steak','steak_house','fried_chicken','wings','supper_club','regional')
              OR LOWER(SUB_CATEGORY_4) IN ('american','burger','bbq','barbecue','southern','soul_food','comfort_food','diner','hot_dog','hotdog','cheesesteak','american_indian','indigenous','hawaiian','tex-mex','cajun','bar_and_grill','steak','steak_house','fried_chicken','wings','supper_club','regional')
              OR LOWER(SUB_CATEGORY_5) IN ('american','burger','bbq','barbecue','southern','soul_food','comfort_food','diner','hot_dog','hotdog','cheesesteak','american_indian','indigenous','hawaiian','tex-mex','cajun','bar_and_grill','steak','steak_house','fried_chicken','wings','supper_club','regional')
              OR LOWER(SUB_CATEGORY_6) IN ('american','burger','bbq','barbecue','southern','soul_food','comfort_food','diner','hot_dog','hotdog','cheesesteak','american_indian','indigenous','hawaiian','tex-mex','cajun','bar_and_grill','steak','steak_house','fried_chicken','wings','supper_club','regional')
              OR LOWER(SUB_CATEGORY_7) IN ('american','burger','bbq','barbecue','southern','soul_food','comfort_food','diner','hot_dog','hotdog','cheesesteak','american_indian','indigenous','hawaiian','tex-mex','cajun','bar_and_grill','steak','steak_house','fried_chicken','wings','supper_club','regional')
            THEN 'American'

            -- Latin American
            WHEN LOWER(SUB_CATEGORY_1) IN ('mexican','latin','latin_american','latin american','latin_fusion','salvadoran','salvadorian','el_salvadoran','el_salvadorian','colombian','venezuelan','ecuadorian','equadorian','brazilian','cuban','caribbean','jamaican','argentinian','peruvian','tacos','burrito','empanada','mayan')
              OR LOWER(SUB_CATEGORY_2) IN ('mexican','latin','latin_american','latin american','latin_fusion','salvadoran','salvadorian','el_salvadoran','el_salvadorian','colombian','venezuelan','ecuadorian','equadorian','brazilian','cuban','caribbean','jamaican','argentinian','peruvian','tacos','burrito','empanada','mayan')
              OR LOWER(SUB_CATEGORY_3) IN ('mexican','latin','latin_american','latin american','latin_fusion','salvadoran','salvadorian','el_salvadoran','el_salvadorian','colombian','venezuelan','ecuadorian','equadorian','brazilian','cuban','caribbean','jamaican','argentinian','peruvian','tacos','burrito','empanada','mayan')
              OR LOWER(SUB_CATEGORY_4) IN ('mexican','latin','latin_american','latin american','latin_fusion','salvadoran','salvadorian','el_salvadoran','el_salvadorian','colombian','venezuelan','ecuadorian','equadorian','brazilian','cuban','caribbean','jamaican','argentinian','peruvian','tacos','burrito','empanada','mayan')
              OR LOWER(SUB_CATEGORY_5) IN ('mexican','latin','latin_american','latin american','latin_fusion','salvadoran','salvadorian','el_salvadoran','el_salvadorian','colombian','venezuelan','ecuadorian','equadorian','brazilian','cuban','caribbean','jamaican','argentinian','peruvian','tacos','burrito','empanada','mayan')
              OR LOWER(SUB_CATEGORY_6) IN ('mexican','latin','latin_american','latin american','latin_fusion','salvadoran','salvadorian','el_salvadoran','el_salvadorian','colombian','venezuelan','ecuadorian','equadorian','brazilian','cuban','caribbean','jamaican','argentinian','peruvian','tacos','burrito','empanada','mayan')
              OR LOWER(SUB_CATEGORY_7) IN ('mexican','latin','latin_american','latin american','latin_fusion','salvadoran','salvadorian','el_salvadoran','el_salvadorian','colombian','venezuelan','ecuadorian','equadorian','brazilian','cuban','caribbean','jamaican','argentinian','peruvian','tacos','burrito','empanada','mayan')
            THEN 'Latin American'

            -- Middle Eastern & African
            WHEN LOWER(SUB_CATEGORY_1) IN ('middle_eastern','arab','lebanese','turkish','moroccan','afghan','persian','mediterranean','kebab','falafel','african','east_african','ethiopian','eritrean','somali','somalian','uzbek','pakistani','indian','north-indian')
              OR LOWER(SUB_CATEGORY_2) IN ('middle_eastern','arab','lebanese','turkish','moroccan','afghan','persian','mediterranean','kebab','falafel','african','east_african','ethiopian','eritrean','somali','somalian','uzbek','pakistani','indian','north-indian')
              OR LOWER(SUB_CATEGORY_3) IN ('middle_eastern','arab','lebanese','turkish','moroccan','afghan','persian','mediterranean','kebab','falafel','african','east_african','ethiopian','eritrean','somali','somalian','uzbek','pakistani','indian','north-indian')
              OR LOWER(SUB_CATEGORY_4) IN ('middle_eastern','arab','lebanese','turkish','moroccan','afghan','persian','mediterranean','kebab','falafel','african','east_african','ethiopian','eritrean','somali','somalian','uzbek','pakistani','indian','north-indian')
              OR LOWER(SUB_CATEGORY_5) IN ('middle_eastern','arab','lebanese','turkish','moroccan','afghan','persian','mediterranean','kebab','falafel','african','east_african','ethiopian','eritrean','somali','somalian','uzbek','pakistani','indian','north-indian')
              OR LOWER(SUB_CATEGORY_6) IN ('middle_eastern','arab','lebanese','turkish','moroccan','afghan','persian','mediterranean','kebab','falafel','african','east_african','ethiopian','eritrean','somali','somalian','uzbek','pakistani','indian','north-indian')
              OR LOWER(SUB_CATEGORY_7) IN ('middle_eastern','arab','lebanese','turkish','moroccan','afghan','persian','mediterranean','kebab','falafel','african','east_african','ethiopian','eritrean','somali','somalian','uzbek','pakistani','indian','north-indian')
            THEN 'Middle Eastern & African'

            -- European
            WHEN LOWER(SUB_CATEGORY_1) IN ('italian','french','german','greek','spanish','irish','swedish','ukrainian','european','pizza','pasta','tapas','crepe','creperie','bistro','fish_and_chips','pretzel','schnitzel')
              OR LOWER(SUB_CATEGORY_2) IN ('italian','french','german','greek','spanish','irish','swedish','ukrainian','european','pizza','pasta','tapas','crepe','creperie','bistro','fish_and_chips','pretzel','schnitzel')
              OR LOWER(SUB_CATEGORY_3) IN ('italian','french','german','greek','spanish','irish','swedish','ukrainian','european','pizza','pasta','tapas','crepe','creperie','bistro','fish_and_chips','pretzel','schnitzel')
              OR LOWER(SUB_CATEGORY_4) IN ('italian','french','german','greek','spanish','irish','swedish','ukrainian','european','pizza','pasta','tapas','crepe','creperie','bistro','fish_and_chips','pretzel','schnitzel')
              OR LOWER(SUB_CATEGORY_5) IN ('italian','french','german','greek','spanish','irish','swedish','ukrainian','european','pizza','pasta','tapas','crepe','creperie','bistro','fish_and_chips','pretzel','schnitzel')
              OR LOWER(SUB_CATEGORY_6) IN ('italian','french','german','greek','spanish','irish','swedish','ukrainian','european','pizza','pasta','tapas','crepe','creperie','bistro','fish_and_chips','pretzel','schnitzel')
              OR LOWER(SUB_CATEGORY_7) IN ('italian','french','german','greek','spanish','irish','swedish','ukrainian','european','pizza','pasta','tapas','crepe','creperie','bistro','fish_and_chips','pretzel','schnitzel')
            THEN 'European'

            ELSE NULL
        END                                             AS ETHNICITY_REFERENCE

    FROM CUR_POI.CUR_POI_NAMES;

    -- Apply Eagle tag
    ALTER TABLE CUR_POI.CUR_POI_NAMES
        SET TAG POI_PROJECT.CUR_POI.EAGLE_TAG = 'EagleProject';
    ALTER TABLE CUR_POI.CUR_POI_PROCESSED
        SET TAG POI_PROJECT.CUR_POI.EAGLE_TAG = 'EagleProject';

    RETURN 'SP_CURATE_POI completed. CUR_POI_NAMES and CUR_POI_PROCESSED created.';

END;
$$;

-- ============================================================
-- EXECUTE THE STORED PROCEDURE
-- ============================================================
CALL CUR_POI.SP_CURATE_POI();

-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- Row and column count
SELECT
    (SELECT COUNT(*) FROM CUR_POI.CUR_POI_PROCESSED)       AS TOTAL_ROWS,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = 'CUR_POI'
     AND TABLE_NAME = 'CUR_POI_PROCESSED')                  AS TOTAL_COLUMNS;

-- Business type breakdown
SELECT BUSINESS_TYPE, COUNT(*) AS CNT
FROM CUR_POI.CUR_POI_PROCESSED
GROUP BY BUSINESS_TYPE
ORDER BY CNT DESC;

-- Ethnicity reference breakdown
SELECT COALESCE(ETHNICITY_REFERENCE, 'No Ethnicity Tag') AS ETHNICITY_REFERENCE,
       COUNT(*) AS CNT
FROM CUR_POI.CUR_POI_PROCESSED
GROUP BY ETHNICITY_REFERENCE
ORDER BY CNT DESC;

-- Sample Asian POIs
SELECT NAME, CITY, SUB_CATEGORY_1, SUB_CATEGORY_2, ETHNICITY_REFERENCE
FROM CUR_POI.CUR_POI_PROCESSED
WHERE ETHNICITY_REFERENCE = 'Asian'
LIMIT 10;

-- Sample Latin American POIs
SELECT NAME, CITY, SUB_CATEGORY_1, SUB_CATEGORY_2, ETHNICITY_REFERENCE
FROM CUR_POI.CUR_POI_PROCESSED
WHERE ETHNICITY_REFERENCE = 'Latin American'
LIMIT 10;

-- =====================================================================================================================================================================================
-- SECTION 3: Aggregation Layer
-- Schema:  AGG_POI
-- =====================================================================================================================================================================================

USE DATABASE POI_PROJECT;

CREATE SCHEMA IF NOT EXISTS AGG_POI;
USE SCHEMA AGG_POI;

-- ============================================================
-- AGG TABLE 1: Category count in zip code 55105
-- Aggregation: COUNT
-- ============================================================
CREATE OR REPLACE TABLE AGG_POI.AGG_ZIPCODE_55105 AS
SELECT
    CATEGORY,
    COUNT(*)                                            AS TOTAL_POIS
FROM CUR_POI.CUR_POI_PROCESSED
WHERE POSTCODE = '55105'
GROUP BY CATEGORY
ORDER BY TOTAL_POIS DESC;

SELECT * FROM AGG_ZIPCODE_55105;

ALTER TABLE AGG_POI.AGG_ZIPCODE_55105
    SET TAG POI_PROJECT.CUR_POI.EAGLE_TAG = 'EagleProject';

-- ============================================================
-- AGG TABLE 2: Saint Paul cultural food diversity
-- Aggregation: COUNT, AVG
-- ============================================================
CREATE OR REPLACE TABLE AGG_POI.AGG_SAINTPAUL_FOOD AS
SELECT
    COALESCE(ETHNICITY_REFERENCE, 'No Ethnicity Tag')  AS ETHNICITY_REFERENCE,
    COUNT(*)                                            AS TOTAL_VENUES,
    ROUND(AVG(DATA_QUALITY_SCORE), 2)                  AS AVG_DATA_QUALITY_SCORE
FROM CUR_POI.CUR_POI_PROCESSED
WHERE CITY IN ('Saint Paul', 'St. Paul')
  AND CATEGORY IN ('Food & Drink', 'Grocery & Food')
GROUP BY ETHNICITY_REFERENCE
ORDER BY TOTAL_VENUES DESC;

SELECT * FROM AGG_SAINTPAUL_FOOD;

ALTER TABLE AGG_POI.AGG_SAINTPAUL_FOOD
    SET TAG POI_PROJECT.CUR_POI.EAGLE_TAG = 'EagleProject';

-- ============================================================
-- AGG TABLE 3: Top 10 cities by avg data quality score
-- Aggregation: AVG, MIN, MAX, COUNT
-- ============================================================
CREATE OR REPLACE TABLE AGG_POI.AGG_CITY_QUALITY AS
SELECT
    CITY,
    COUNT(*)                                            AS TOTAL_POIS,
    ROUND(AVG(DATA_QUALITY_SCORE), 2)                  AS AVG_DATA_QUALITY_SCORE,
    MIN(DATA_QUALITY_SCORE)                            AS MIN_DATA_QUALITY_SCORE,
    MAX(DATA_QUALITY_SCORE)                            AS MAX_DATA_QUALITY_SCORE,
    ROUND(AVG(CATEGORY_DEPTH), 2)                      AS AVG_CATEGORY_DEPTH
FROM CUR_POI.CUR_POI_PROCESSED
WHERE CITY IS NOT NULL
GROUP BY CITY
ORDER BY TOTAL_POIS DESC
LIMIT 10;

SELECT * FROM AGG_CITY_QUALITY;

ALTER TABLE AGG_POI.AGG_CITY_QUALITY
    SET TAG POI_PROJECT.CUR_POI.EAGLE_TAG = 'EagleProject';

-- ============================================================
-- AGG TABLE 4: All cities with count of each category as columns
-- Aggregation: COUNT (pivot style)
-- Ordered by Food & Drink count descending
-- ============================================================
CREATE OR REPLACE TABLE AGG_POI.AGG_CITY_CATEGORY_PIVOT AS
SELECT
    CITY,
    COUNT(*)                                                        AS TOTAL_POIS,
    COUNT(CASE WHEN CATEGORY = 'Food & Drink'     THEN 1 END)      AS FOOD_AND_DRINK,
    COUNT(CASE WHEN CATEGORY = 'Grocery & Food'   THEN 1 END)      AS GROCERY_AND_FOOD,
    COUNT(CASE WHEN CATEGORY = 'Shopping'         THEN 1 END)      AS SHOPPING,
    COUNT(CASE WHEN CATEGORY = 'Leisure'          THEN 1 END)      AS LEISURE,
    COUNT(CASE WHEN CATEGORY = 'Education'        THEN 1 END)      AS EDUCATION,
    COUNT(CASE WHEN CATEGORY = 'Health'           THEN 1 END)      AS HEALTH,
    COUNT(CASE WHEN CATEGORY = 'Finance'          THEN 1 END)      AS FINANCE,
    COUNT(CASE WHEN CATEGORY = 'Transport'        THEN 1 END)      AS TRANSPORT,
    COUNT(CASE WHEN CATEGORY = 'Tourism'          THEN 1 END)      AS TOURISM,
    COUNT(CASE WHEN CATEGORY = 'Entertainment'    THEN 1 END)      AS ENTERTAINMENT,
    COUNT(CASE WHEN CATEGORY = 'Public Services'  THEN 1 END)      AS PUBLIC_SERVICES,
    COUNT(CASE WHEN CATEGORY = 'Nature'           THEN 1 END)      AS NATURE,
    COUNT(CASE WHEN CATEGORY = 'Services'         THEN 1 END)      AS SERVICES,
    COUNT(CASE WHEN CATEGORY = 'Other'            THEN 1 END)      AS OTHER
FROM CUR_POI.CUR_POI_PROCESSED
WHERE CITY IS NOT NULL
GROUP BY CITY
ORDER BY TOTAL_POIS DESC;

SELECT * FROM AGG_CITY_CATEGORY_PIVOT;

ALTER TABLE AGG_POI.AGG_CITY_CATEGORY_PIVOT
    SET TAG POI_PROJECT.CUR_POI.EAGLE_TAG = 'EagleProject';

-- ============================================================
-- MATERIALIZED VIEW: Summary AGG_CITY_CATEGORY_PIVOT
-- ============================================================
CREATE OR REPLACE MATERIALIZED VIEW AGG_POI.AGG_MV_CITY_SUMMARY AS
SELECT
    CITY,
    TOTAL_POIS,
    FOOD_AND_DRINK,
    GROCERY_AND_FOOD,
    SHOPPING,
    LEISURE,
    EDUCATION,
    HEALTH,
    FINANCE,
    TRANSPORT,
    TOURISM,
    ENTERTAINMENT,
    PUBLIC_SERVICES,
    NATURE
FROM AGG_POI.AGG_CITY_CATEGORY_PIVOT;

SELECT * FROM AGG_CITY_CATEGORY_PIVOT;

-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- AGG 1: Category count in zip 55105
SELECT * FROM AGG_POI.AGG_ZIPCODE_55105;

-- AGG 2: Saint Paul food diversity
SELECT * FROM AGG_POI.AGG_SAINTPAUL_FOOD;

-- AGG 3: Top 10 cities by data quality
SELECT * FROM AGG_POI.AGG_CITY_QUALITY;

-- AGG 4: City category pivot
SELECT * FROM AGG_POI.AGG_CITY_CATEGORY_PIVOT
LIMIT 20;

-- Materialized view
SELECT * FROM AGG_POI.AGG_MV_CITY_SUMMARY;

-- =====================================================================================================================================================================================
-- SECTION 4: Table Function
-- Schema:  AGG_POI
-- -- =====================================================================================================================================================================================


USE DATABASE POI_PROJECT;
USE SCHEMA AGG_POI;

-- ============================================================
-- TABLE FUNCTION: FN_GET_CITY_POIS
-- Returns all POIs for a given city and optional category
-- Use case: Application retrieves POI data for a specific city and filters by category if needed
-- ============================================================
CREATE OR REPLACE FUNCTION AGG_POI.FN_GET_CITY_POIS(
    INPUT_CITY      VARCHAR,
    INPUT_CATEGORY  VARCHAR
)
RETURNS TABLE (
    POI_ID              VARCHAR,
    NAME                VARCHAR,
    CATEGORY            VARCHAR,
    SUB_CATEGORY_1      VARCHAR,
    SUB_CATEGORY_2      VARCHAR,
    ETHNICITY_REFERENCE VARCHAR,
    BUSINESS_TYPE       VARCHAR,
    FULL_ADDRESS        VARCHAR,
    CITY                VARCHAR,
    POSTCODE            VARCHAR,
    PHONE               VARCHAR,
    WEBSITE             VARCHAR,
    HOURS_CATEGORY      VARCHAR,
    IS_LATE_NIGHT       VARCHAR,
    IS_WHEELCHAIR_ACCESSIBLE VARCHAR,
    DATA_QUALITY_SCORE  NUMBER,
    CITY_TIER           VARCHAR,
    GEO_QUADRANT        VARCHAR
)
AS
$$
    SELECT
        POI_ID,
        NAME,
        CATEGORY,
        SUB_CATEGORY_1,
        SUB_CATEGORY_2,
        ETHNICITY_REFERENCE,
        BUSINESS_TYPE,
        FULL_ADDRESS,
        CITY,
        POSTCODE,
        PHONE,
        WEBSITE,
        HOURS_CATEGORY,
        IS_LATE_NIGHT,
        IS_WHEELCHAIR_ACCESSIBLE,
        DATA_QUALITY_SCORE,
        CITY_TIER,
        GEO_QUADRANT
    FROM CUR_POI.CUR_POI_PROCESSED
    WHERE CITY = INPUT_CITY
      AND (INPUT_CATEGORY = 'ALL' OR CATEGORY = INPUT_CATEGORY)
$$;

-- ============================================================
-- EXAMPLE 
-- ============================================================

-- All POIs in Minneapolis
SELECT * FROM TABLE(AGG_POI.FN_GET_CITY_POIS('Minneapolis', 'ALL'))
ORDER BY CATEGORY, NAME
LIMIT 20;

-- Food & Drink in Saint Paul
SELECT * FROM TABLE(AGG_POI.FN_GET_CITY_POIS('Saint Paul', 'Food & Drink'))
ORDER BY DATA_QUALITY_SCORE DESC
LIMIT 20;

-- Shopping in Bloomington
SELECT * FROM TABLE(AGG_POI.FN_GET_CITY_POIS('Bloomington', 'Shopping'))
ORDER BY NAME
LIMIT 20;

-- Late night venues in Minneapolis
SELECT NAME, SUB_CATEGORY_1, HOURS_CATEGORY, PHONE
FROM TABLE(AGG_POI.FN_GET_CITY_POIS('Minneapolis', 'Food & Drink'))
WHERE IS_LATE_NIGHT = 'Y'
ORDER BY NAME;

-- Asian food in Saint Paul
SELECT NAME, SUB_CATEGORY_1, SUB_CATEGORY_2, ETHNICITY_REFERENCE, FULL_ADDRESS
FROM TABLE(AGG_POI.FN_GET_CITY_POIS('Saint Paul', 'Food & Drink'))
WHERE ETHNICITY_REFERENCE = 'Asian'
ORDER BY NAME;

-- =====================================================================================================================================================================================
-- SECTION 5: Task
-- Schema:  CUR_POI
- =====================================================================================================================================================================================

USE DATABASE POI_PROJECT;
USE SCHEMA CUR_POI;

-- ============================================================
-- TASK: TSK_WEEKLY_CURATE_POI
-- Runs every Sunday at 4:00 AM
-- Executes the stored procedure SP_CURATE_POI to refresh
-- CUR_POI_NAMES and CUR_POI_PROCESSED tables
-- ============================================================
CREATE OR REPLACE TASK CUR_POI.TSK_WEEKLY_CURATE_POI
    WAREHOUSE = EAGLE_WH
    SCHEDULE  = 'USING CRON 0 4 * * 0 America/Chicago'
AS
    CALL CUR_POI.SP_CURATE_POI();

-- ============================================================
-- TEST the task manually before suspending
-- ============================================================
EXECUTE TASK CUR_POI.TSK_WEEKLY_CURATE_POI;

-- Check task ran successfully
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME => 'TSK_WEEKLY_CURATE_POI'
))
ORDER BY SCHEDULED_TIME DESC
LIMIT 5;

-- ============================================================
-- SUSPEND the task after testing
-- ============================================================
ALTER TASK CUR_POI.TSK_WEEKLY_CURATE_POI SUSPEND;

-- Confirm task is suspended
SHOW TASKS IN SCHEMA CUR_POI;

-- =====================================================================================================================================================================================
-- SECTION 6: PROJECT SUMMARY
-- =====================================================================================================================================================================================

-- ============================================================
-- DATASET
-- ============================================================
/*
    Name:       Twin Cities Metro Point-of-Interest (POI) Data
    Source:     OpenStreetMap via Overpass API (overpass-api.de)
    Coverage:   Twin Cities Metro Area, Minnesota Bounding box: 44.7N-45.2N, 93.7W-92.9W
    Records:    17,270 POIs across 14 categories
    Columns:    23 columns after Python preprocessing

    Description:
        This dataset contains point-of-interest records for the Twin Cities metropolitan area including Minneapolis, Saint Paul, and surrounding suburbs. 
        It covers restaurants, shops, parks, schools, hospitals, banks,and more. 
        Data was fetched from OpenStreetMap using the Overpass API across 7 category queries, then loading into Snowflake as the raw source layer.
*/

-- ============================================================
-- NAMING CONVENTIONS and SCHEMAS
-- ============================================================
/*
    DATABASE: POI_PROJECT

    SCHEMA: RAW_POI
        Objects: POI_RAW
        Purpose: Raw ingestion layer. Source CSV loaded as-is.

    SCHEMA: CUR_POI
        Objects: CUR_POI_BASE, CUR_POI_ADDRESS,
                 CUR_POI_ENRICHED, CUR_POI_HOURS,
                 CUR_POI_FINAL, CUR_POI_VIEW (view),
                 CUR_POI_NAMES, CUR_POI_PROCESSED
        Purpose: Curation layer. Cleaned, enriched, and flagged data. Built as a pipeline where each table feeds the next.

    SCHEMA: AGG_POI
        Objects: AGG_ZIPCODE_55105, AGG_SAINTPAUL_FOOD,
                 AGG_CITY_QUALITY, AGG_CITY_CATEGORY_PIVOT,
                 AGG_MV_CITY_SUMMARY (materialized view),
                 FN_GET_CITY_POIS (table function)
        Purpose: Aggregation layer. Summary tables for analysis and dashboard consumption.

    ALL objects are tagged: EAGLE_TAG = 'EagleProject'
*/

-- Quick navigation queries:
SHOW TABLES IN SCHEMA POI_PROJECT.RAW_POI;
SHOW TABLES IN SCHEMA POI_PROJECT.CUR_POI;
SHOW TABLES IN SCHEMA POI_PROJECT.AGG_POI;

-- ============================================================
-- MINI DATA CATALOG
-- ============================================================
/*
    All custom fields below reside in the CUR_POI schema.

-- Curation Layer (CUR_POI_ADDRESS) 

    ADDRESS_COMPLETENESS
        Logic  : 'Full'    — HOUSE_NUMBER, STREET, CITY,
                             POSTCODE all NOT NULL
                 'Partial' — at least one address field
                             is NOT NULL
                 'None'    — all address fields are NULL
        Purpose: Identifies records with incomplete addresses.

    FULL_ADDRESS
        Logic  : CONCAT_WS(' ', HOUSE_NUMBER, STREET, CITY,
                 STATE, POSTCODE) using IFNULL to skip NULLs.
                 Returns NULL if ADDRESS_COMPLETENESS = 'None'.
        Purpose: Single formatted address string for display.

-- Curation Layer (CUR_POI_ENRICHED) 

    IS_WHEELCHAIR_ACCESSIBLE
        Logic  : IFF(UPPER(WHEELCHAIR) = 'YES', 'Y', 'N')
        Purpose: Quick accessibility filter flag.

    HAS_PHONE / HAS_WEBSITE / HAS_HOURS / HAS_FEE
        Logic  : IFF(column IS NOT NULL, 'Y', 'N')
        Purpose: Easy Y/N flags for filtering and dashboards.

    DATA_QUALITY_SCORE (0-5)
        Logic  : Sum of 5 binary indicators (1 pt each):
                   + HAS_PHONE = 'Y'
                   + HAS_WEBSITE = 'Y'
                   + HAS_HOURS = 'Y'
                   + ADDRESS_COMPLETENESS = 'Full'
                   + SUB_CATEGORY_2 IS NOT NULL
        Purpose: Measures how complete each POI record is.

    CATEGORY_DEPTH (1-7)
        Logic  : Count of filled SUB_CATEGORY_1 through
                 SUB_CATEGORY_7 slots.
        Purpose: Measures richness of category classification.

-- Curation Layer (CUR_POI_HOURS) 

    HOURS_CATEGORY
        Logic  : Parsed from OPENING_HOURS text patterns:
                   '24/7'              — contains '24/7' or '00:00-24:00'
                   'Weekdays Only'     — has MO-FR, no SA/SU
                   'Mon-Sat'           — has MO and SA, no SU
                   'Includes Weekends' — has SA or SU
                   'Other Schedule'    — any other pattern
                   'Unknown'           — OPENING_HOURS is NULL
        Purpose: Human-readable schedule bucket for filtering.

    IS_LATE_NIGHT
        Logic  : IFF(OPENING_HOURS LIKE '%02:00%'
                  OR OPENING_HOURS LIKE '%03:00%'
                  OR OPENING_HOURS LIKE '%24:00%'
                  OR OPENING_HOURS LIKE '%01:00%', 'Y', 'N')
        Purpose: Flag for nightlife and late-night venues.

-- Curation Layer (CUR_POI_FINAL) 

    CITY_TIER
        Logic  : 'Metro Core'    — Minneapolis, Saint Paul
                 'Inner Suburb'  — Bloomington, Eagan, Edina, Plymouth, Maple Grove, etc.
                 'Outer Suburb'  — all other named cities
                 'Unknown'       — CITY IS NULL
        Purpose: Groups cities into urban density tiers.

    GEO_QUADRANT
        Logic  : Uses center point 44.98N, 93.27W:
                   LATITUDE >= 44.98 AND LONGITUDE < -93.27
                     → 'Northwest'
                   LATITUDE >= 44.98 AND LONGITUDE >= -93.27
                     → 'Northeast'
                   LATITUDE <  44.98 AND LONGITUDE < -93.27
                     → 'Southwest'
                   else → 'Southeast'
        Purpose: Geographic zone for spatial analysis.

-- Stored Procedure (CUR_POI_NAMES) 

    BUSINESS_TYPE
        Logic  : 'National Chain' — NAME matches known brands (McDonald's, Target,Starbucks, Walmart, etc.)
                 'Corporate'      — NAME contains LLC, Inc, Corp, or Ltd
                 'Local Brand'    — NAME contains Minneapolis, Minnesota, Twin Cities
                 'Independent'    — all others
        Purpose: Classifies ownership model of each POI.

    NAME_HAS_NUMBER
        Logic  : IFF(NAME REGEXP '[0-9]', 'Y', 'N')
        Purpose: Flags names containing digits (e.g. 7-Eleven).

    NAME_LENGTH_BUCKET
        Logic  : 'Short'  — LENGTH(NAME) <= 10
                 'Medium' — LENGTH(NAME) <= 25
                 'Long'   — LENGTH(NAME) > 25
        Purpose: Buckets name length for analysis.

-- Stored Procedure (CUR_POI_PROCESSED) 

    ETHNICITY_REFERENCE
        Logic  : Scans SUB_CATEGORY_1 through SUB_CATEGORY_7
                 using LOWER(col) IN (...) for each group:
                   'Asian'                  — vietnamese,
                     chinese, japanese, korean, thai, hmong,
                     lao, ramen, sushi, poke, bubble_tea, etc.
                   'American'               — american, burger,
                     bbq, southern, soul_food, cajun,
                     tex-mex, steak, fried_chicken, etc.
                   'Latin American'         — mexican, latin,
                     salvadoran, colombian, cuban, caribbean,
                     brazilian, tacos, burrito, etc.
                   'Middle Eastern & African' — ethiopian,
                     somali, lebanese, indian, moroccan,
                     arab, kebab, mediterranean, etc.
                   'European'              — italian, french,
                     german, greek, pizza, pasta, tapas, etc.
                   NULL — no ethnicity match found
        Purpose: Identifies cultural food diversity across
                 the Twin Cities metro area.
*/

-- ============================================================
-- DASHBOARD
-- ============================================================
/*
    Dashboard Name: EAGLE_PROJECT_DASHBOARD
    Total Tiles   : 9
 
    Layout:
        Row 1 — 4 Scorecards (quick snapshot metrics)
        Row 2 — Heatgrid (full width)
        Row 3 — Bar: POI Count by Category
                Bar: Top 10 Cities Food & Drink
        Row 4 — Bar: Saint Paul Food Culture
                Bar: Data Quality Score Distribution
 
--Row 1: Scorecards 
 
    Scorecard 1 — Total POIs in Twin Cities
        Chart : Scorecard
        Query : SELECT COUNT(*) AS TOTAL_POIS
                FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED
        Label : "Total POIs in Twin Cities"
 
    Scorecard 2 — Cities Covered
        Chart : Scorecard
        Query : SELECT COUNT(DISTINCT CITY) AS TOTAL_CITIES
                FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED
                WHERE CITY IS NOT NULL
        Label : "Cities Covered"
 
    Scorecard 3 — Total Food & Drink Venues
        Chart : Scorecard
        Query : SELECT COUNT(*) AS TOTAL_FOOD
                FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED
                WHERE CATEGORY = 'Food & Drink'
        Label : "Food & Drink Venues"
 
    Scorecard 4 — Avg Data Quality Score
        Chart : Scorecard
        Query : SELECT ROUND(AVG(DATA_QUALITY_SCORE), 2)
                  AS AVG_QUALITY
                FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED
        Label : "Avg Data Quality Score"
 
-- Row 2: Heatgrid 
 
    Tile 5 — POI Density by Category and City Tier
        Chart : Heatgrid
        Query : SELECT CATEGORY, CITY_TIER,
                       COUNT(*) AS TOTAL_POIS
                FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED
                WHERE CITY_TIER != 'Unknown'
                GROUP BY CATEGORY, CITY_TIER
                ORDER BY TOTAL_POIS DESC
        Row   : CATEGORY
        Column: CITY_TIER
        Value : TOTAL_POIS
        Label : "POI Density by Category and City Tier"
 
-- Row 3: Bar Charts 
 
    Tile 6 — POI Count by Category
        Chart : Bar chart
        Query : SELECT CATEGORY, COUNT(*) AS TOTAL_POIS
                FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED
                GROUP BY CATEGORY
                ORDER BY TOTAL_POIS DESC
        X-axis: CATEGORY
        Y-axis: TOTAL_POIS
        Label : "POI Count by Category"
 
    Tile 7 — Top 10 Cities by Food & Drink
        Chart : Bar chart
        Query : SELECT CITY, FOOD_AND_DRINK
                FROM POI_PROJECT.AGG_POI.AGG_CITY_CATEGORY_PIVOT
                ORDER BY FOOD_AND_DRINK DESC
                LIMIT 10
        X-axis: CITY
        Y-axis: FOOD_AND_DRINK
        Label : "Top 10 Cities — Food & Drink Venues"
 
-- Row 4: Bar Charts 
 
    Tile 8 — Saint Paul Food Culture by Ethnicity
        Chart : Bar chart
        Query : SELECT ETHNICITY_REFERENCE, TOTAL_VENUES
                FROM POI_PROJECT.AGG_POI.AGG_SAINTPAUL_FOOD
                ORDER BY TOTAL_VENUES DESC
        X-axis: ETHNICITY_REFERENCE
        Y-axis: TOTAL_VENUES
        Label : "Saint Paul Food Culture by Ethnicity"
 
    Tile 9 — Data Quality Score Distribution
        Chart : Bar chart
        Query : SELECT DATA_QUALITY_SCORE,
                       COUNT(*) AS TOTAL_POIS
                FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED
                GROUP BY DATA_QUALITY_SCORE
                ORDER BY DATA_QUALITY_SCORE ASC
        X-axis: DATA_QUALITY_SCORE
        Y-axis: TOTAL_POIS
        Label : "POI Data Quality Score Distribution (0-5)"
*/