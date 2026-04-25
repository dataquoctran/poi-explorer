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