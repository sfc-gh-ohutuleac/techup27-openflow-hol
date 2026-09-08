

## 8. Deploy and Configure the CDC Connector

### 8.1 Open the OpenFlow Dashboard

Navigate to the OpenFlow UI:
- Go to **Snowsight** > **Data** > **Ingestion** > **OpenFlow**
- Click on your runtime (`QUICKSTART_PGCDC_RUNTIME`)
- This opens the NiFi-based flow canvas

### 8.2 Deploy the PostgreSQL CDC Connector

1. In the OpenFlow canvas, click **Add Connector** (or drag from the registry)
2. Select **PostgreSQL** from the Snowflake Connector Registry
3. The connector will be deployed to the canvas

### 8.3 Configure Parameters

Right-click the PostgreSQL process group > **Parameters** (or click the gear icon).

Configure the following parameter contexts:

#### PostgreSQL Source Parameters

| Parameter | Value |
|-----------|-------|
| **PostgreSQL Connection URL** | `jdbc:postgresql://<your-postgres-hostname>:5432/postgres` |
| **PostgreSQL Username** | `snowflake_admin` |
| **PostgreSQL Password** | (your Postgres password from Step 2) |
| **Publication Name** | `healthcare_cdc_publication` |
| **Replication Slot Name** | (leave empty - auto-generated) |

### Upload JDBC Driver (if prompted)

If the connector prompts for a JDBC driver:
1. Download from: https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.13/postgresql-42.7.13.jar
2. Upload via the parameter context asset upload

#### PostgreSQL Destination Parameters

| Parameter | Value |
|-----------|-------|
| **Destination Database** | `QUICKSTART_PGCDC_DB` |
| **Snowflake Role** | `QUICKSTART_ROLE` |
| **Snowflake Warehouse** | `QUICKSTART_PGCDC_WH` |
| **Snowflake Authentication Strategy** | `SNOWFLAKE_MANAGED` |


#### PostgreSQL Ingestion Parameters

| Parameter | Value |
|-----------|-------|
| **Included Table Regex** | `healthcare\\..*` |
| **Ingestion Type** | `full` |
| **Object Identifier Resolution** | `CASE_SENSITIVE` |
| **Merge Task Schedule CRON** | `0 * * * * ?` |

> **Note on Ingestion Type:** `full` means the connector performs a full initial snapshot of all data, then switches to incremental CDC streaming. This is the correct setting for new pipelines. `incremental` would skip the initial snapshot and only capture future changes.

> **Note on Object Identifier Resolution:** `CASE_SENSITIVE` preserves the original PostgreSQL lowercase naming. This means when querying in Snowflake, you must quote schema and table names: `SELECT * FROM QUICKSTART_PGCDC_DB."healthcare"."patients"`. If you prefer uppercase Snowflake naming (no quoting needed), use `CASE_INSENSITIVE`.



> **Note:** Newer connector versions (0.64.0+) may include the JDBC driver automatically.

### 8.5 Enable Controller Services

1. Right-click the PostgreSQL process group
2. Select **Enable all controller services**
3. Wait for all services to show **ENABLED** (green lightning bolt)
4. The **Snowflake Private Key Service** will remain DISABLED - this is expected on SPCS deployments

### 8.6 Start the Flow

1. Right-click the PostgreSQL process group
2. Select **Start**
3. All processors should turn green (running)

---

## 9. Start and Verify the Pipeline

### 9.1 Monitor in OpenFlow Dashboard

After starting, monitor the connector:
- **Snapshot Load** process group should show flowfiles being processed
- Tables will progress through states: `NEW` > `SNAPSHOT_REPLICATION` > `INCREMENTAL_REPLICATION`
- The initial snapshot should complete within 1-2 minutes for this dataset size

### 9.2 Verify Data in Snowflake

Run in Snowflake SQL Worksheet:

```sql
USE ROLE QUICKSTART_ROLE;
USE WAREHOUSE QUICKSTART_PGCDC_WH;

-- Check if tables were created
SHOW TABLES IN SCHEMA QUICKSTART_PGCDC_DB."healthcare";

-- Verify row counts match source
SELECT 'patients' AS tbl, COUNT(*) AS cnt FROM QUICKSTART_PGCDC_DB."healthcare"."patients"
UNION ALL SELECT 'doctors', COUNT(*) FROM QUICKSTART_PGCDC_DB."healthcare"."doctors"
UNION ALL SELECT 'appointments', COUNT(*) FROM QUICKSTART_PGCDC_DB."healthcare"."appointments"
UNION ALL SELECT 'visits', COUNT(*) FROM QUICKSTART_PGCDC_DB."healthcare"."visits"
ORDER BY tbl;
```

Expected output:

| TBL | CNT |
|-----|-----|
| appointments | 170 |
| doctors | 10 |
| patients | 100 |
| visits | 100 |

### 9.3 Sample Query on Replicated Data

```sql
-- Top doctors by appointment count
SELECT 
    d."first_name" || ' ' || d."last_name" AS doctor_name,
    d."specialization",
    COUNT(a."appointment_id") AS total_appointments
FROM QUICKSTART_PGCDC_DB."healthcare"."appointments" a
JOIN QUICKSTART_PGCDC_DB."healthcare"."doctors" d 
    ON a."doctor_id" = d."doctor_id"
GROUP BY d."first_name", d."last_name", d."specialization"
ORDER BY total_appointments DESC;
```

---