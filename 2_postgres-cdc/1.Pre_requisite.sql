# OpenFlow PostgreSQL CDC Demo Guide

**Snowflake Managed Postgres to Snowflake via OpenFlow CDC**

This guide walks through setting up a real-time Change Data Capture (CDC) pipeline from Snowflake Managed Postgres to Snowflake using OpenFlow. It uses a healthcare appointment management dataset as the demo scenario.

---

## Table of Contents

1. [Prerequisites and Software Setup](#1-prerequisites-and-software-setup)
2. [Create Snowflake Postgres Instance](#2-create-snowflake-postgres-instance)
3. [Create Network Policy for Postgres](#3-create-network-policy-for-postgres)
4. [Connect to Postgres via DBeaver](#4-connect-to-postgres-via-dbeaver)
5. [Create Healthcare Demo Data](#5-create-healthcare-demo-data)--Refer Postgres_healthcare.Sql
6. [Configure Postgres for CDC Replication](#6-configure-postgres-for-cdc-replication)--Refer Postgres_healthcare.Sql
7. [Set Up OpenFlow Deployment, Runtime and EAI](#7-set-up-openflow-Deployment-runtime-and-eai)
8. [Deploy and Configure the CDC Connector](#8-deploy-and-configure-the-cdc-connector)--Refer Openflow_Setup.sql
9. [Start and Verify the Pipeline](#9-start-and-verify-the-pipeline)--Refer Openflow_Setup.sql
10. [Test Real-Time CDC](#10-test-real-time-cdc) -- Refer Postgres_CDC.sql
11. [Cleanup](#11-cleanup)--Refer Cleanup.sql

---

## 1. Prerequisites and Software Setup

### Snowflake Account Requirements

- Snowflake account with `ACCOUNTADMIN` role (or equivalent privileges)
- OpenFlow enabled on the account (check with your Snowflake representative)

### Software to Install

#### DBeaver (Database Client for Postgres)

DBeaver is a free, cross-platform database tool for connecting to Postgres.

**macOS:**
```bash
brew install --cask dbeaver-community
```

**Windows:**
- Download from: https://dbeaver.io/download/
- Run the installer (.exe), accept defaults

**Linux (Ubuntu/Debian):**
```bash
sudo snap install dbeaver-ce
```

#### Snowflake CLI (Optional - for SQL worksheet alternative)

```bash
# macOS
brew install --cask snowflake-cli

# Or via pip
pip install snowflake-cli
```

---

## 2. Create Snowflake Postgres Instance

Run the following in a Snowflake SQL Worksheet (using `ACCOUNTADMIN` role):

--Sql
-- Use ACCOUNTADMIN role
USE ROLE ACCOUNTADMIN;

--create from Snowsight UI:
1. In the manage, click Postgres
2. Click the **+** button in the top navigation
3. Configure:
   - **Name:** `dev-test`
   - **Instance class:** Standard/Burstable, Select the minimum configuration
   - **Storage:** 10 GB
   - **Postgres version:** Latest (18.x)

After creation, **save the credentials shown on screen** (username, password, hostname). You will need:
- **Username:** `snowflake_admin`
- **Password:** (generated - save securely)
- **Hostname:** `<instance-id>.<account>.westeurope.azure.postgres.snowflake.app`
- **Port:** `5432`
- **Database:** `postgres`

Check instance status:
--sql
SHOW POSTGRES INSTANCES;


Wait until `state` shows `READY` before proceeding.

---

## 3. Create Network Policy for Postgres

> **CRITICAL:** Snowflake Managed Postgres requires a network policy with `MODE = POSTGRES_INGRESS`. This is different from regular Snowflake network rules which use `INGRESS` or `EGRESS`. Without this specific mode, no external connections can reach your Postgres instance.

--sql
USE ROLE ACCOUNTADMIN;

-- Create a schema for network configuration (if not exists)
CREATE DATABASE IF NOT EXISTS CONFIG;
CREATE SCHEMA IF NOT EXISTS CONFIG.NETWORK;

-- Create network rule allowing all IPs (for demo purposes)
-- In production, restrict to specific IP ranges
CREATE OR REPLACE NETWORK RULE CONFIG.NETWORK.NR_PG_DEV_TEST_ALLOWED
  TYPE = IPV4
  MODE = POSTGRES_INGRESS
  VALUE_LIST = ('0.0.0.0/0');

-- Create network policy and attach the rule
CREATE OR REPLACE NETWORK POLICY NP_PG_DEV_TEST
  ALLOWED_NETWORK_RULE_LIST = ('CONFIG.NETWORK.NR_PG_DEV_TEST_ALLOWED');

-- Attach the network policy to the Postgres instance
ALTER POSTGRES INSTANCE dev_test SET NETWORK_POLICY = 'NP_PG_DEV_TEST';


> **Why 0.0.0.0/0?** This allows connections from any IP address. This is required because:
> - DBeaver connections from any team member''s machine
> - OpenFlow runtime (SPCS) connects from dynamic IPs
> - For production, you would restrict to specific CIDRs after identifying the OpenFlow runtime IP


## 4. Connect to Postgres via DBeaver

### Step-by-Step DBeaver Connection

1. Open DBeaver
2. Click **Database** > **New Database Connection** (or the plug icon)
3. Select **PostgreSQL** and click **Next**
4. Fill in connection details:

| Field | Value |
|-------|-------|
| **Host** | `<your-instance-hostname>.postgres.snowflake.app` |
| **Port** | `5432` |
| **Database** | `postgres` |
| **Username** | `snowflake_admin` |
| **Password** | (the password from instance creation) |

5. Click **Test Connection** - should show "Connected"
6. Click **Finish**

### Verify Connection

Once connected, expand the database tree in DBeaver to see:
- `postgres` database
- `public` schema
- (No tables yet)

Run a quick test query:
```sql
SELECT version();
```

You should see PostgreSQL 18.x output.

-----------------------------------------------------------------------------------------------------------------------
--Refer Postgres_healthcare.sql complete 5 and 6 steps,However continue the step 7
-----------------------------------------------------------------------------------------------------------------------


## 7. Set Up OpenFlow Deployment, Runtime and EAI in Snowflake Acccount

Back in Snowflake SQL Worksheet, run the following:

### 7.1 Create Roles and Database
--sql
USE ROLE ACCOUNTADMIN;

-- Create a dedicated role for this demo
CREATE ROLE IF NOT EXISTS QUICKSTART_ROLE;
GRANT ROLE QUICKSTART_ROLE TO ROLE ACCOUNTADMIN;

-- Create warehouse
CREATE WAREHOUSE IF NOT EXISTS QUICKSTART_PGCDC_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

GRANT USAGE ON WAREHOUSE QUICKSTART_PGCDC_WH TO ROLE QUICKSTART_ROLE;

-- Create destination database
CREATE DATABASE IF NOT EXISTS QUICKSTART_PGCDC_DB;
GRANT OWNERSHIP ON DATABASE QUICKSTART_PGCDC_DB TO ROLE QUICKSTART_ROLE;

-- Grant OpenFlow admin role (optional)
--GRANT ROLE OPENFLOW_ADMIN TO ROLE ACCOUNTADMIN;

-- Grant required privileges to QUICKSTART_ROLE
GRANT CREATE SCHEMA ON DATABASE QUICKSTART_PGCDC_DB TO ROLE QUICKSTART_ROLE;


### 7.2 Create External Access Integration (EAI) for OpenFlow

> **CRITICAL:** OpenFlow runs in SPCS (Snowpark Container Services). SPCS has no outbound network access by default. You must create an EAI to allow the runtime to connect to your Postgres instance.

--sql
USE ROLE ACCOUNTADMIN;

-- Create network rule for OpenFlow to reach Postgres
-- Replace the hostname with YOUR Postgres instance hostname
CREATE OR REPLACE NETWORK RULE QUICKSTART_PGCDC_DB.PUBLIC.POSTGRES_NETWORK_RULE
  TYPE = HOST_PORT
  MODE = EGRESS
  VALUE_LIST = ('<your-postgres-hostname>:5432');

-- Example with actual hostname:
-- VALUE_LIST = ('jczlrovesnbszaqo6v7pzuylxi.sfseeurope-demo-dws-se-ps.westeurope.azure.postgres.snowflake.app:5432');

-- Create the External Access Integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION QUICKSTART_PGCDC_ACCESS
  ALLOWED_NETWORK_RULES = (QUICKSTART_PGCDC_DB.PUBLIC.POSTGRES_NETWORK_RULE)
  ENABLED = TRUE;


> **Key difference from Step 3:** 
> - Step 3 network rule uses `MODE = POSTGRES_INGRESS` (allows INBOUND connections TO Postgres)
> - This rule uses `MODE = EGRESS` with `TYPE = HOST_PORT` (allows OUTBOUND connections FROM OpenFlow to Postgres)
> - Both are needed: one lets DBeaver/clients connect IN, the other lets OpenFlow connect OUT

### 7.3 Create the SPCS Deployment in the Opendflow menu
1. In snowsight UI, Click Ingesttion, openflow
2. Clink Launch Openflow button
3. Sign in to OPenflow interface with Same Id and password.
4. Click Create Deployment, Click next and location as Snowflake, and give tech_up as deployment k8s.namespace.name
5. Click next and click create deployment.
6. Wait for Deployment to be created successfuly and become status as Active from Provisioning

### 7.4 Create the OpenFlow Runtime

Go to **Snowsight** > **Data** > **Ingestion** > **OpenFlow** (or navigate directly):

1. Click **+ Runtime**
2. Configure:
   - **Name:** `QUICKSTART_PGCDC_RUNTIME`
   - **Database:** `QUICKSTART_PGCDC_DB`
   - **Schema:** `PUBLIC` (or create a dedicated schema)
   - **Warehouse:** `QUICKSTART_PGCDC_WH`
   - **External Access Integration:** `QUICKSTART_PGCDC_ACCESS`
   - **Role:** `QUICKSTART_ROLE`
3. Click **Create**

Wait for the runtime status to show **Active** (this may take 2-3 minutes).

Alternatively, if SQL-based runtime creation is supported on your account:

--sql
USE ROLE ACCOUNTADMIN;

CREATE OPENFLOW RUNTIME QUICKSTART_PGCDC_DB.PUBLIC.QUICKSTART_PGCDC_RUNTIME
  WAREHOUSE = QUICKSTART_PGCDC_WH
  EXTERNAL_ACCESS_INTEGRATIONS = (QUICKSTART_PGCDC_ACCESS);


---