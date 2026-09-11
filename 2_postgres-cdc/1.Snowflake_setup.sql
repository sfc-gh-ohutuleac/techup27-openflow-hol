-------------------------------------------------------------------------------
-- TECHUP27: Openflow PostgreSQL CDC - Lab Setup Script
-- 
-- Lab: Real-time CDC from Snowflake Managed Postgres to Snowflake
--      using the Openflow PostgreSQL CDC Connector
--
-- Prerequisites:
--   - ACCOUNTADMIN access
--   - DBeaver (or another Postgres client) installed
--
-- What this script creates:
--   1. Snowflake Managed Postgres instance (via Snowsight UI or SQL)
--   2. Network policy for Postgres (Postgres INGRESS)
--   3. Dedicated role, warehouse, and destination database
--   4. Network rule + External Access Integration (EGRESS to Postgres)
--   5. All required grants to the quickstart role
--
-- Run this script as ACCOUNTADMIN in your demo account.
-- Steps marked [UI] must be done in Snowsight or DBeaver — not in SQL.
-------------------------------------------------------------------------------

-- ============================================================================
-- VARIABLES (adjust these to match your environment)
-- ============================================================================
SET pg_hostname = '<pg-hostname-after-step-1>';   -- Fill in after Step 1
SET pg_instance = 'dev_test';                     -- Postgres instance name
SET openflow_role = 'OPENFLOW_ADMIN';             -- Openflow Admin Role
SET openflow_db = 'OPENFLOW';                     -- Database where your runtime lives
SET openflow_schema = 'OPENFLOW';                 -- Schema where your runtime lives
SET openflow_runtime = 'TECHUP27_RUNTIME';        -- Your runtime name

-- ============================================================================
-- 1. CREATE SNOWFLAKE MANAGED POSTGRES INSTANCE
-- ============================================================================
-- Using SQL or UI
USE ROLE ACCOUNTADMIN;

-- Option 1: SQL
-- IMPORTANT: Save the credentials from the output — they cannot be retrieved later.
CREATE POSTGRES INSTANCE IDENTIFIER($pg_instance)
  COMPUTE_FAMILY = 'BURST_S'
  STORAGE_SIZE_GB = 10
  AUTHENTICATION_AUTHORITY = POSTGRES
  POSTGRES_VERSION = 18
  COMMENT = 'TechUp27 Openflow CDC lab - healthcare demo';

-- IMPORTANT: Save the credentials from the output — they cannot be retrieved later.
--      - Username:  snowflake_admin
--      - Password:  (generated — save securely)
--      - Hostname:  <instance-id>.<account>.<region>.postgres.snowflake.app
--      - Port:      5432
--      - Database:  postgres

-- Check instance status (wait until state = READY)
DESCRIBE POSTGRES INSTANCE IDENTIFIER($pg_instance);

-- Once READY, update the $pg_hostname variable above with your actual hostname,
-- then re-run the SET statement before continuing to Step 2.

-- Option 2: This step can also be done in the Snowsight UI:
--   1. Navigate to Manage > Postgres
--   2. Click the + button
--   3. Configure:
--      - Name:            dev_test
--      - Instance class:  Burstable (BURST_S)
--      - Storage:         10 GB
--      - Postgres version: Latest (18.x)
--   4. Save the credentials shown on screen:
--      - Username:  snowflake_admin
--      - Password:  (generated — save securely)
--      - Hostname:  <instance-id>.<account>.<region>.postgres.snowflake.app
--      - Port:      5432
--      - Database:  postgres

-- IMPORTANT: Save the credentials from the screen — they cannot be retrieved later.

-- Once READY, update the $pg_hostname variable above with your actual hostname,
-- then re-run the SET statement before continuing to Step 2.

-- Grant usage on the Postgres instance to the Openflow admin role
GRANT USAGE ON POSTGRES INSTANCE IDENTIFIER($pg_instance) TO ROLE IDENTIFIER($openflow_role);

-- ============================================================================
-- 2. NETWORK POLICY FOR POSTGRES (INBOUND)
-- ============================================================================
-- Snowflake Managed Postgres requires MODE = POSTGRES_INGRESS.
-- This is different from regular Snowflake network rules (INGRESS/EGRESS).
-- Without this, no external connections (DBeaver, Openflow) can reach Postgres.

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS TECHUP27;
USE DATABASE TECHUP27;
USE SCHEMA PUBLIC;

-- Create Secret with the postgres instance password
CREATE SECRET TECHUP27_PG_SECRET
    TYPE = GENERIC_STRING
    SECRET_STRING = '<your-postgres-instance-password>';

GRANT USAGE, READ ON SECRET TECHUP27_PG_SECRET TO ROLE IDENTIFIER($openflow_role);

-- Allow all IPs (demo only — restrict to specific CIDRs in production)
CREATE OR REPLACE NETWORK RULE NR_PG_DEV_TEST_ALLOWED
  TYPE = IPV4
  MODE = POSTGRES_INGRESS
  VALUE_LIST = ('0.0.0.0/0');

CREATE OR REPLACE NETWORK POLICY NP_PG_DEV_TEST
  ALLOWED_NETWORK_RULE_LIST = ('TECHUP27.PUBLIC.NR_PG_DEV_TEST_ALLOWED');

-- Attach the network policy to the Postgres instance
ALTER POSTGRES INSTANCE IDENTIFIER($pg_instance) SET NETWORK_POLICY = 'NP_PG_DEV_TEST';

-- Check instance network_policy
DESCRIBE POSTGRES INSTANCE IDENTIFIER($pg_instance);

-- ============================================================================
-- 3. ROLE, WAREHOUSE & DESTINATION DATABASE
-- ============================================================================
USE ROLE ACCOUNTADMIN;

-- Warehouse for merge operations
CREATE WAREHOUSE IF NOT EXISTS PG_WAREHOUSE
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

GRANT USAGE ON WAREHOUSE PG_WAREHOUSE TO ROLE IDENTIFIER($openflow_role);

-- Destination Database
CREATE DATABASE IF NOT EXISTS TECHUP27
  COMMENT = 'Openflow Zero-to-Hero Hands-on Lab - TechUp #27';

USE DATABASE TECHUP27;
USE SCHEMA PUBLIC;
GRANT USAGE ON DATABASE TECHUP27 TO ROLE IDENTIFIER($openflow_role);
GRANT CREATE SCHEMA ON DATABASE TECHUP27 TO ROLE IDENTIFIER($openflow_role);
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA TECHUP27.PUBLIC TO ROLE IDENTIFIER($openflow_role);
GRANT CREATE TABLE ON SCHEMA TECHUP27.PUBLIC TO ROLE IDENTIFIER($openflow_role);

-- Grant future tables too (in case attendees create additional tables)
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA TECHUP27.PUBLIC TO ROLE IDENTIFIER($openflow_role);

-- Grant Create Openflow Connector to role
GRANT CREATE OPENFLOW CONNECTOR ON SCHEMA OPENFLOW.OPENFLOW TO ROLE IDENTIFIER($openflow_role);

-- ============================================================================
-- 4. NETWORK RULE + EXTERNAL ACCESS INTEGRATION (OUTBOUND)
-- ============================================================================
-- Openflow runs in SPCS — no outbound network by default.
-- This EAI allows the runtime to connect OUT to your Postgres instance.
--
-- NOTE: Replace <your-postgres-hostname> with the actual hostname from Step 1
--       before running this section.

USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE NETWORK RULE TECHUP27.PUBLIC.POSTGRES_NETWORK_RULE
  TYPE = HOST_PORT
  MODE = EGRESS
  VALUE_LIST = ('<your-postgres-hostname>:5432')
  COMMENT = 'Openflow CDC lab - outbound to Snowflake Managed Postgres';

-- Example format:
-- VALUE_LIST = ('<instance-id>.<account>.<region>.<cloud>.postgres.snowflake.app:5432');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION TECHUP27_PGCDC_EAI
  ALLOWED_NETWORK_RULES = (TECHUP27.PUBLIC.POSTGRES_NETWORK_RULE)
  ENABLED = TRUE
  COMMENT = 'EAI for Openflow CDC lab (Postgres egress)';

-- Verify
DESCRIBE INTEGRATION TECHUP27_PGCDC_EAI;

-- KEY DIFFERENCE from Step 2:
--   Step 2: MODE = POSTGRES_INGRESS  -> allows INBOUND connections TO Postgres
--   Step 4: MODE = EGRESS            -> allows OUTBOUND connections FROM Openflow
--   Both are needed.

-- Grant EAI usage to the openflow role
GRANT USAGE ON INTEGRATION TECHUP27_PGCDC_EAI TO ROLE IDENTIFIER($openflow_role);

-- ============================================================================
-- 5. ATTACH EAI TO RUNTIME
-- ============================================================================
-- There are TWO ways to attach an EAI to a runtime.
----
-- OPTION A: using SQL
--   Note: This REPLACES all EAIs on the runtime. If your runtime already has
--   other EAIs attached, include them all in the list.
--
--   To check existing EAIs before running:
USE ROLE IDENTIFIER($openflow_role);
USE DATABASE IDENTIFIER($openflow_db);
USE SCHEMA IDENTIFIER($openflow_schema);

SHOW OPENFLOW RUNTIMES;
DESCRIBE OPENFLOW RUNTIME IDENTIFIER($openflow_runtime);

--   If you have existing EAIs, include them:
--     SET EXTERNAL_ACCESS_INTEGRATIONS = (EXISTING_EAI_1, TECHUP27_PGCDC_EAI);
ALTER OPENFLOW RUNTIME IDENTIFIER($openflow_runtime)
  SET EXTERNAL_ACCESS_INTEGRATIONS = (TECHUP27_PGCDC_EAI);

-- Verify column external_access_integrations
DESCRIBE OPENFLOW RUNTIME IDENTIFIER($openflow_runtime);

----
-- OPTION B: Openflow UI in Snowsight (works on ALL accounts, including pre-SOM)
--   1. Navigate to Data Engineering > Openflow in Snowsight
--   2. Click on your runtime
--   3. Click the "..." menu > "External access integrations"
--   4. Select TECHUP27_PGCDC_EAI from the dropdown
--   5. Click Save
--   Pros: visual, additive (won't overwrite existing EAIs), no restart needed
--

-- ============================================================================
-- 6. VERIFICATION
-- ============================================================================
-- Confirm role grants
SHOW GRANTS TO ROLE IDENTIFIER($openflow_role);

-- Confirm destination database exists
SHOW DATABASES LIKE 'TECHUP27%';

-- Confirm EAI is active
SHOW EXTERNAL ACCESS INTEGRATIONS LIKE 'TECHUP27%';

-- Confirm Postgres instance is ready
SHOW POSTGRES INSTANCES;

-- ============================================================================
-- DONE! Your environment is ready for the lab.
--
-- Next steps:
--   1. Open the Openflow canvas for your runtime
--   2. Deploy the PostgreSQL CDC connector from the Snowflake Connector Registry
--   3. Configure source, destination, and ingestion parameters
--   4. Follow 3.Openflow_setup.sql for detailed connector configuration
--
-- Pipeline summary:
--   Snowflake Managed Postgres (healthcare schema, 4 tables)
--     -> Logical Replication (WAL, publication: healthcare_cdc_publication)
--     -> Openflow PostgreSQL CDC Connector (NiFi on SPCS)
--       1. Full initial snapshot (all 4 tables)
--       2. Incremental CDC streaming (INSERT/UPDATE/DELETE)
--     -> Snowflake tables (QUICKSTART_PGCDC_DB."healthcare".*)
-- ============================================================================
