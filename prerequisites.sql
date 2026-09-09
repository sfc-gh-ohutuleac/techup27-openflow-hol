--------------------------------------------------------------------------------
-- TECHUP27: Openflow "Zero to Hero" - Lab Setup Script
-- --
-- Prerequisites:
--   - ACCOUNTADMIN access
--   - Runtime role: OPENFLOW_ADMIN (adjust if different)
--
-- What this script creates:
--   1. Database TECHUP27 with schema PUBLIC
--   2. Target table for ingestion (USER_SPENDING)
--   3. Network Rule for dummyjson.com
--   4. External Access Integration
--   5. All required grants to the Openflow runtime role
--   6. Attaches EAI to the runtime (SOM) or instructions for UI (pre-SOM)
--
-- Run this script as ACCOUNTADMIN before the lab session.
--------------------------------------------------------------------------------

-- ============================================================================
-- VARIABLES (adjust these to match your environment)
-- ============================================================================
SET openflow_role = 'OPENFLOW_ADMIN';            -- Openflow Admin Role
SET openflow_db = 'OPENFLOW';                    -- Database where your runtime lives
SET openflow_schema = 'OPENFLOW';                -- Schema where your runtime lives
SET openflow_deployment = 'TECHUP27_DEPLOYMENT'; -- Deployment display name
SET openflow_runtime = 'TECHUP27_RUNTIME';       -- Your runtime name

-- ============================================================================
-- 1. DATABASE & SCHEMA
-- ============================================================================
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS IDENTIFIER($openflow_role);
GRANT ROLE IDENTIFIER($openflow_role) TO ROLE SYSADMIN;

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS TECHUP27
  COMMENT = 'Openflow Zero-to-Hero Hands-on Lab - TechUp27';

USE DATABASE TECHUP27;
USE SCHEMA PUBLIC;

-- ============================================================================
-- 2. GRANTS TO OPENFLOW ROLE
-- ============================================================================
-- Grant access to the lab database and tables
GRANT USAGE ON DATABASE TECHUP27 TO ROLE IDENTIFIER($openflow_role);
GRANT USAGE ON SCHEMA TECHUP27.PUBLIC TO ROLE IDENTIFIER($openflow_role);
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA TECHUP27.PUBLIC TO ROLE IDENTIFIER($openflow_role);
GRANT ALL PRIVILEGES ON ALL ICEBERG TABLES IN SCHEMA TECHUP27.PUBLIC TO ROLE IDENTIFIER($openflow_role);
GRANT CREATE TABLE ON SCHEMA TECHUP27.PUBLIC TO ROLE IDENTIFIER($openflow_role);

-- Grant future tables too (in case attendees create additional tables)
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA TECHUP27.PUBLIC TO ROLE IDENTIFIER($openflow_role);

GRANT CREATE OPENFLOW DEPLOYMENT ON ACCOUNT TO ROLE IDENTIFIER($openflow_role);
GRANT CREATE OPENFLOW RUNTIME ON SCHEMA OPENFLOW.OPENFLOW TO ROLE IDENTIFIER($openflow_role);

-- ============================================================================
-- 3. CREATE OPENFLOW DEPLOYMENT
-- ============================================================================
USE ROLE IDENTIFIER($openflow_role);

CREATE OPENFLOW DEPLOYMENT IDENTIFIER($openflow_deployment)
DEPLOYMENT_TYPE = 'SNOWFLAKE'
COMMENT = 'TechUp27 Openflow Deployment';

-- ============================================================================
-- 4. CREATE OPENFLOW RUNTIME
-- ============================================================================
USE ROLE IDENTIFIER($openflow_role);
USE SCHEMA OPENFLOW.OPENFLOW;
CREATE OPENFLOW RUNTIME IDENTIFIER($openflow_runtime)
IN DEPLOYMENT IDENTIFIER($openflow_deployment)
MIN_NODES = 1
MAX_NODES = 1
NODE_TYPE = 'SMALL'
EXECUTE_AS_ROLE = OPENFLOW_ADMIN
COMMENT = 'TechUp27 Openflow Runtime';

CALL SYSTEM$WAIT(5, 'MINUTES');

-- Wait for 5 minutes if the following statement is still failing - runtime is still CREATING
ALTER OPENFLOW RUNTIME IDENTIFIER($openflow_runtime) SUSPEND;

-- ============================================================================
-- 5. VERIFICATION
-- ============================================================================
-- Confirm grants
SHOW GRANTS TO ROLE IDENTIFIER($openflow_role);

-- Confirm openflow deployment
SHOW OPENFLOW DEPLOYMENTS;
SHOW OPENFLOW RUNTIMES;
-- ============================================================================
-- DONE! Your environment is ready for the lab.
-- 
-- ============================================================================