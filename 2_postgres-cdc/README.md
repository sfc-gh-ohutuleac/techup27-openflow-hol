# TechUp27 - Usecase 2: Ingest data from a Postgres database

**Snowflake Managed Postgres to Snowflake via OpenFlow CDC**

In this lab we will use the Postgres Connector and Change Data Capture (CDC) to build a workflow that ingests data from a Postgres database into Snowflake, using a healthcare appointment management dataset as the demo scenario.

## Code Structure

The lab is segregated into the following numbered scripts, meant to be run in order. `1.Pre_requisite.sql` is the master guide/table of contents and links out to the other scripts for the steps that involve running SQL against Postgres or OpenFlow.

| # | File | Purpose | Covers Steps |
|---|------|---------|--------------|
| 1 | [`1.Pre_requisite.sql`](./1.Pre_requisite.sql) | Master guide: software setup, Postgres instance creation, network policy, DBeaver connection, and OpenFlow deployment/runtime/EAI setup | 1-7 |
| 2 | [`2.Postgres_healthcare.sql`](./2.Postgres_healthcare.sql) | Initializes the Postgres healthcare database with schema, synthetic snapshot data, and CDC publication | 5-6 |
| 3 | [`3.Openflow_setup.sql`](./3.Openflow_setup.sql) | Deploys and configures the PostgreSQL CDC connector in OpenFlow, then starts and verifies the pipeline | 8-9 |
| 4 | [`4.Postgres_CDC.sql`](./4.Postgres_CDC.sql) | Tests real-time CDC by inserting/updating data in Postgres and verifying it replicates to Snowflake | 10 |
| 5 | [`5.Cleanup.sql`](./5.Cleanup.sql) | Tears down all resources created during the lab (database, warehouse, role, EAI, network policy, Postgres instance) | 11 |

---

## 1. `1.Pre_requisite.sql` — Prerequisites & OpenFlow Setup

1. **Prerequisites and Software Setup** - `ACCOUNTADMIN` access, OpenFlow enabled, install DBeaver and (optionally) Snowflake CLI.
2. **Create Snowflake Postgres Instance** - Create a managed Postgres instance (`dev-test`) via Snowsight UI; save credentials; wait for `READY` state.
3. **Create Network Policy for Postgres** - Create a `POSTGRES_INGRESS` network rule/policy and attach it to the Postgres instance so external clients (DBeaver, OpenFlow) can connect.
4. **Connect to Postgres via DBeaver** - Configure a DBeaver connection and verify with `SELECT version();`.
5. **Create Healthcare Demo Data** - *(see [`2.Postgres_healthcare.sql`](./2.Postgres_healthcare.sql))*
6. **Configure Postgres for CDC Replication** - *(see [`2.Postgres_healthcare.sql`](./2.Postgres_healthcare.sql))*
7. **Set Up OpenFlow Deployment, Runtime and EAI**:
   - 7.1 Create dedicated role, warehouse, and destination database
   - 7.2 Create an External Access Integration (EAI) so OpenFlow (SPCS) can reach Postgres
   - 7.3 Create the OpenFlow SPCS deployment
   - 7.4 Create the OpenFlow runtime

## 2. `2.Postgres_healthcare.sql` — Healthcare Schema & CDC Publication

1. **Grant Replication Privileges** - Verifies `wal_level = logical` (required for CDC). Enabled by default on Snowflake Managed Postgres.
2. **Create Schema** - Creates (and resets) the `healthcare` schema.
3. **Create Tables** - `patients`, `doctors`, `appointments` (main CDC demo table), `visits`, plus supporting indexes.
4. **Load Synthetic Snapshot Data** - 10 doctors, 100 patients, 150 appointments, 100 visits (derived from completed appointments).
5. **Verify Data** - Row-count check across all four tables.
6. **Configure Postgres for CDC Replication** - Confirms `wal_level = logical` and creates publication `healthcare_cdc_publication` covering all four healthcare tables.

## 3. `3.Openflow_setup.sql` — Deploy & Verify the CDC Connector

1. **Deploy and Configure the CDC Connector**:
   - 8.1 Open the OpenFlow dashboard / NiFi canvas for the runtime
   - 8.2 Deploy the PostgreSQL connector from the Snowflake Connector Registry
   - 8.3 Configure source, destination, and ingestion parameters (connection URL, publication name, destination DB/role/warehouse, table regex, ingestion type `full`)
   - Upload JDBC driver if prompted
   - 8.5 Enable all controller services
   - 8.6 Start the flow
2. **Start and Verify the Pipeline**:
   - 9.1 Monitor snapshot/incremental replication status in the OpenFlow dashboard
   - 9.2 Verify tables and row counts in Snowflake match the Postgres source
   - 9.3 Run a sample join query on the replicated data

## 4. `4.Postgres_CDC.sql` — Real-Time CDC Test

1. **Insert New Data** (in DBeaver) - Insert a test patient and appointment into Postgres.
2. **Verify in Snowflake** - Confirm the new rows appear after replication (~30-60s).
3. **Test UPDATE** - Update the test patient's city in Postgres.
4. **Verify UPDATE in Snowflake** - Confirm the change is reflected.
5. **Verify Updated Row Counts** - Re-check row counts across all tables.

## 5. `5.Cleanup.sql` — Teardown

- Stop the OpenFlow connector (via UI)
- Drop destination database (`QUICKSTART_PGCDC_DB`), warehouse (`QUICKSTART_PGCDC_WH`), and role (`QUICKSTART_ROLE`)
- Drop the External Access Integration (`QUICKSTART_PGCDC_ACCESS`)
- Drop the Postgres network policy and rule
- Suspend or drop the Postgres instance (`dev_test`)
- Delete the OpenFlow deployment to stop incurring cost

---

## Prerequisites

- Snowflake account with `ACCOUNTADMIN` role (or equivalent) and OpenFlow enabled
- DBeaver (or another Postgres client) installed
- PostgreSQL 12+ with logical replication enabled (`wal_level = logical`) — enabled by default on Snowflake Managed Postgres
