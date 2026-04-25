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