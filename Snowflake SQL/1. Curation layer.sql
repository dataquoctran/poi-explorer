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