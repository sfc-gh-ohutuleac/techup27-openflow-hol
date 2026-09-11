--------------------------------------------------------------------------------
-- TECHUP27: PostgreSQL CDC Lab — Cleanup Script
-- 
-- Run this after the lab session to remove all objects created during the lab.
-- Execute as ACCOUNTADMIN.
--
-- This reverses everything created by 1.Snowflake_setup.sql:
--   1. TECHUP27 database (includes network rules, secret, and replicated tables)
--   2. PG_WAREHOUSE warehouse
--   3. TECHUP27_PGCDC_EAI external access integration
--   4. NP_PG_DEV_TEST network policy + NR_PG_DEV_TEST_ALLOWED rule
--   5. dev_test Postgres instance (suspended by default)
--
-- IMPORTANT: This script does NOT drop the Openflow deployment or runtime.
-- Those are shared resources that may be used by other labs or demos.
-- Uncomment the Openflow section at the end if you want to remove them too.
--------------------------------------------------------------------------------

-- ============================================================================
-- VARIABLES (adjust these to match your environment)
-- ============================================================================
SET pg_instance    = 'dev_test';
SET openflow_role  = 'OPENFLOW_ADMIN';
SET openflow_db    = 'OPENFLOW';
SET openflow_schema = 'OPENFLOW';
SET openflow_runtime = 'TECHUP27_RUNTIME';

-- ============================================================================
-- 1. STOP THE CDC CONNECTOR (do this in the Openflow UI first!)
-- ============================================================================
-- Before running this script:
--   1. Open the Openflow canvas for your runtime
--   2. Right-click the PostgreSQL CDC process group
--   3. Click "Stop" to stop all processors
--   4. Optionally delete the process group from the canvas
--
-- If you skip this step, the connector will error out once the database is
-- dropped (it won't cause harm, but will generate bulletin errors).

-- ============================================================================
-- 2. DETACH EAI FROM RUNTIME
-- ============================================================================
-- Remove the lab EAI from the runtime so it can be dropped cleanly.
USE ROLE IDENTIFIER($openflow_role);
USE DATABASE IDENTIFIER($openflow_db);
USE SCHEMA IDENTIFIER($openflow_schema);

ALTER OPENFLOW RUNTIME IDENTIFIER($openflow_runtime)
  SET EXTERNAL_ACCESS_INTEGRATIONS = ();  -- or list only the EAIs you want to keep

-- ============================================================================
-- 3. REVOKE GRANTS
-- ============================================================================
USE ROLE ACCOUNTADMIN;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA TECHUP27.PUBLIC FROM ROLE IDENTIFIER($openflow_role);
REVOKE ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA TECHUP27.PUBLIC FROM ROLE IDENTIFIER($openflow_role);
REVOKE CREATE TABLE ON SCHEMA TECHUP27.PUBLIC FROM ROLE IDENTIFIER($openflow_role);
REVOKE CREATE SCHEMA ON DATABASE TECHUP27 FROM ROLE IDENTIFIER($openflow_role);
REVOKE USAGE ON SCHEMA TECHUP27.PUBLIC FROM ROLE IDENTIFIER($openflow_role);
REVOKE USAGE ON DATABASE TECHUP27 FROM ROLE IDENTIFIER($openflow_role);
REVOKE USAGE ON INTEGRATION TECHUP27_PGCDC_EAI FROM ROLE IDENTIFIER($openflow_role);
REVOKE USAGE ON WAREHOUSE PG_WAREHOUSE FROM ROLE IDENTIFIER($openflow_role);
REVOKE CREATE OPENFLOW CONNECTOR ON SCHEMA OPENFLOW.OPENFLOW FROM ROLE IDENTIFIER($openflow_role);
REVOKE USAGE ON POSTGRES INSTANCE IDENTIFIER($pg_instance) FROM ROLE IDENTIFIER($openflow_role);

-- ============================================================================
-- 4. DROP POSTGRES NETWORK POLICY
-- ============================================================================
-- Detach the policy from the instance first, then drop
ALTER POSTGRES INSTANCE IDENTIFIER($pg_instance) UNSET NETWORK_POLICY;

DROP NETWORK POLICY IF EXISTS NP_PG_DEV_TEST;

-- ============================================================================
-- 5. SUSPEND OR DROP POSTGRES INSTANCE
-- ============================================================================
-- Suspend to stop compute costs but keep data:
ALTER POSTGRES INSTANCE IDENTIFIER($pg_instance) SUSPEND;

-- Or permanently drop (irreversible — all data is lost):
DROP POSTGRES INSTANCE IDENTIFIER($pg_instance);

-- ============================================================================
-- 6. DROP LAB OBJECTS (in dependency order)
-- ============================================================================
USE ROLE ACCOUNTADMIN;

-- Drop database (includes replicated tables, network rule, secret)
DROP DATABASE IF EXISTS TECHUP27;

-- Drop warehouse
DROP WAREHOUSE IF EXISTS PG_WAREHOUSE;

-- Drop EAI (must be done after detaching from runtime)
DROP INTEGRATION IF EXISTS TECHUP27_PGCDC_EAI;

-- ============================================================================
-- 7. OPENFLOW (optional — uncomment if you want to remove shared resources)
-- ============================================================================
ALTER OPENFLOW CONNECTOR OPENFLOW.OPENFLOW.TECHUP27_PG_CONNECTOR STOP;
ALTER OPENFLOW CONNECTOR OPENFLOW.OPENFLOW.TECHUP27_PG_CONNECTOR TERMINATE;
DROP OPENFLOW CONNECTOR OPENFLOW.OPENFLOW.TECHUP27_PG_CONNECTOR;
ALTER OPENFLOW RUNTIME OPENFLOW.OPENFLOW.TECHUP27_RUNTIME SUSPEND;
-- ALTER OPENFLOW RUNTIME OPENFLOW.OPENFLOW.TECHUP27_RUNTIME TERMINATE;
-- DROP OPENFLOW RUNTIME OPENFLOW.OPENFLOW.TECHUP27_RUNTIME;
-- ALTER OPENFLOW DEPLOYMENT TECHUP27_DEPLOYMENT TERMINATE;
-- DROP OPENFLOW DEPLOYMENT TECHUP27_DEPLOYMENT;

SHOW OPENFLOW RUNTIMES;
SHOW OPENFLOW CONNECTORS;
SHOW OPENFLOW DEPLOYMENTS;

-- ============================================================================
-- 8. VERIFICATION
-- ============================================================================
-- Confirm everything is gone
SHOW DATABASES LIKE 'TECHUP27';              -- Should return 0 rows
SHOW WAREHOUSES LIKE 'PG_WAREHOUSE';         -- Should return 0 rows
SHOW INTEGRATIONS LIKE 'TECHUP27_PGCDC%';   -- Should return 0 rows
SHOW POSTGRES INSTANCES;                      -- Should show SUSPENDED or gone

-- ============================================================================
-- DONE! All lab resources have been cleaned up.
--
-- What remains (intentionally not removed):
--   - Openflow deployment and runtime (shared infrastructure)
--   - OPENFLOW_ADMIN role (shared across labs)
--   - The connector on the NiFi canvas (delete manually if desired)
-- ============================================================================
