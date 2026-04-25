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