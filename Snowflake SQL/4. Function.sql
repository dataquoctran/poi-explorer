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