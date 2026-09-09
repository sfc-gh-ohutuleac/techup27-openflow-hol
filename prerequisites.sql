--------------------------------------------------------------------------------
-- TECHUP27: Openflow "Zero to Hero" - Lab Setup Script
-- --
-- Prerequisites:
--   - ACCOUNTADMIN access
--
-- What this script creates:
--   1. Openflow Admin Role
--   2. Database OPENFLOW with schema OPENFLOW (for runtime)
--   3. All required grants to the Openflow runtime role
--   4. Openflow Deployment at account level
--   5. Openflow Runtime in the OPENFLOW.OPENFLOW schema
--
-- Run this script as ACCOUNTADMIN before the lab session.
--------------------------------------------------------------------------------

-- ============================================================================
-- VARIABLES (adjust these to match your environment)
-- ============================================================================
SET openflow_role = 'OPENFLOW_ADMIN';             -- Openflow Admin Role
SET openflow_db = 'OPENFLOW';                     -- Database where your runtime lives
SET openflow_schema = 'OPENFLOW';                 -- Schema where your runtime lives
SET openflow_deployment = 'TECHUP27_DEPLOYMENT';  -- Deployment name
SET openflow_runtime = 'TECHUP27_RUNTIME';        -- Your runtime name

-- ============================================================================
-- 1. DATABASE & SCHEMA
-- ============================================================================
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS IDENTIFIER($openflow_role);
GRANT ROLE IDENTIFIER($openflow_role) TO ROLE SYSADMIN;

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS IDENTIFIER($openflow_db)
  COMMENT = 'Openflow database for runtime and deployments';
USE DATABASE IDENTIFIER($openflow_db);

CREATE SCHEMA IF NOT EXISTS IDENTIFIER($openflow_schema)
  COMMENT = 'Openflow schema for runtime objects';
USE SCHEMA IDENTIFIER($openflow_schema);

-- ============================================================================
-- 2. GRANTS TO OPENFLOW ROLE
-- ============================================================================
-- Grant access to the Openflow database and schema
GRANT USAGE ON DATABASE IDENTIFIER($openflow_db) TO ROLE IDENTIFIER($openflow_role);
GRANT USAGE ON SCHEMA IDENTIFIER($openflow_schema) TO ROLE IDENTIFIER($openflow_role);

GRANT CREATE COMPUTE POOL ON ACCOUNT TO ROLE IDENTIFIER($openflow_role);
GRANT CREATE OPENFLOW DEPLOYMENT ON ACCOUNT TO ROLE IDENTIFIER($openflow_role);
GRANT CREATE OPENFLOW RUNTIME ON SCHEMA IDENTIFIER($openflow_schema) TO ROLE IDENTIFIER($openflow_role);

-- ============================================================================
-- 3. CREATE OPENFLOW DEPLOYMENT
-- ============================================================================
USE ROLE IDENTIFIER($openflow_role);

CREATE OPENFLOW DEPLOYMENT IF NOT EXISTS IDENTIFIER($openflow_deployment)
DEPLOYMENT_TYPE = 'SNOWFLAKE'
COMMENT = 'TechUp27 Openflow Deployment';

SHOW OPENFLOW DEPLOYMENTS;

-- Wait for the deployment to become active, 7-8 minutes
CALL SYSTEM$WAIT(8, 'MINUTES');

-- ============================================================================
-- 4. CREATE OPENFLOW RUNTIME
-- ============================================================================
USE ROLE IDENTIFIER($openflow_role);
USE DATABASE IDENTIFIER($openflow_db);
USE SCHEMA IDENTIFIER($openflow_schema);

CREATE OPENFLOW RUNTIME IF NOT EXISTS IDENTIFIER($openflow_runtime)
IN DEPLOYMENT IDENTIFIER($openflow_deployment)
MIN_NODES = 1
MAX_NODES = 1
NODE_TYPE = 'SMALL'
EXECUTE_AS_ROLE = $openflow_role
COMMENT = 'TechUp27 Openflow Runtime';

SHOW OPENFLOW RUNTIMES;

-- Wait for the runtime creation to finish, 4-5 minutes
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
