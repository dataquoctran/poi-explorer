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