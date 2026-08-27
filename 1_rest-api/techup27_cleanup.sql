--------------------------------------------------------------------------------
-- TECHUP27: Cleanup Script
-- 
-- Run this after the lab session to remove all objects created during the lab.
-- Execute as ACCOUNTADMIN.
--
-- IMPORTANT: This script does NOT drop the Openflow runtime or deployment.
-- Those are shared resources that may be used by other labs or demos.
-- This only cleans up the lab-specific database, EAI, and network rule.
--------------------------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- 1. STOP THE FLOW (do this in the NiFi UI first!)
-- ============================================================================
-- Before running this script:
--   1. Open the NiFi canvas
--   2. Right-click the "User Spending Enrichment" Process Group
--   3. Click "Stop" to stop all processors
--   4. Optionally delete the Process Group from the canvas
--
-- If you skip this step, the flow will error out once the tables are dropped
-- (it won't cause harm, but will generate bulletin errors).

-- ============================================================================
-- 2. DETACH EAI FROM RUNTIME
-- ============================================================================
-- Remove the lab EAI from the runtime so it can be dropped cleanly.
--
-- OPTION A: SQL (SOM accounts only)
-- ALTER OPENFLOW RUNTIME <db>.<schema>.<runtime>
--   SET EXTERNAL_ACCESS_INTEGRATIONS = ();  -- or list only the EAIs you want to keep
--
-- OPTION B: Openflow UI (works on all accounts)
--   1. Navigate to Data Engineering > Openflow
--   2. Click your runtime > "..." > "External access integrations"
--   3. Remove TECHUP27_LAB_EAI from the list
--   4. Click Save

-- ============================================================================
-- 3. REVOKE GRANTS
-- ============================================================================
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA TECHUP27.PUBLIC FROM ROLE QUICKSTART_ROLE;
REVOKE ALL PRIVILEGES ON ALL ICEBERG TABLES IN SCHEMA TECHUP27.PUBLIC FROM ROLE QUICKSTART_ROLE;
REVOKE ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA TECHUP27.PUBLIC FROM ROLE QUICKSTART_ROLE;
REVOKE USAGE ON SCHEMA TECHUP27.PUBLIC FROM ROLE QUICKSTART_ROLE;
REVOKE USAGE ON DATABASE TECHUP27 FROM ROLE QUICKSTART_ROLE;
REVOKE USAGE ON INTEGRATION TECHUP27_LAB_EAI FROM ROLE QUICKSTART_ROLE;

-- ============================================================================
-- 4. DROP OBJECTS (in dependency order)
-- ============================================================================
-- Drop the database (includes all tables, iceberg tables, and the network rule)
DROP DATABASE IF EXISTS TECHUP27;

-- Drop the EAI (must be done after detaching from runtime)
DROP INTEGRATION IF EXISTS TECHUP27_LAB_EAI;

-- ============================================================================
-- 5. VERIFICATION
-- ============================================================================
-- Confirm everything is gone
SHOW DATABASES LIKE 'TECHUP27';            -- Should return 0 rows
SHOW INTEGRATIONS LIKE 'TECHUP27%';        -- Should return 0 rows

-- ============================================================================
-- DONE! All lab resources have been cleaned up.
--
-- What remains (intentionally not removed):
--   - Openflow deployment and runtime (shared infrastructure)
--   - OPENFLOW_ADMIN / QUICKSTART_ROLE roles (from quickstart guide)
--   - User's default role setting
--   - The flow on the NiFi canvas (delete manually if desired)
-- ============================================================================
