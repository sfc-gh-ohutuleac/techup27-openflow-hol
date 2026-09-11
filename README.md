# TechUp FY27 — Openflow Hands-on Lab

Build real data pipelines with **Openflow** (Apache NiFi on Snowpark Container Services). Choose one or both use cases below to get hands-on experience with REST API ingestion and real-time Change Data Capture.

## Repository Structure

```
├── prerequisites.sql              # Global setup: role, database, deployment, runtime
├── 1_rest-api/
│   ├── README.md                  # Overview + step-by-step build guide
│   ├── 1.techup27_setup.sql       # Snowflake objects (tables, EAI, grants)
│   ├── 2.techup27_cleanup.sql     # Teardown script
│   ├── techup27_flow.json         # Importable NiFi flow (solution/reference)
└── 2_postgres-cdc/
    ├── README.md                  # Use case overview & code structure
    ├── 1.Pre_requisite.sql        # Postgres instance, network, DBeaver, Openflow
    ├── 2.Postgres_healthcare.sql  # Healthcare schema & synthetic data (run in Postgres)
    ├── 3.Openflow_setup.sql       # Deploy & configure the CDC connector
    ├── 4.Postgres_CDC.sql         # Test real-time CDC (INSERT/UPDATE)
    └── 5.Cleanup.sql              # Teardown all resources
```

## Prerequisites

> **Time:** ~20 minutes | **Role required:** ACCOUNTADMIN

Run [`prerequisites.sql`](prerequisites.sql) in a Snowflake SQL Worksheet. This creates:

- **OPENFLOW_ADMIN** role with required grants
- **OPENFLOW** database and schema for the runtime
- **Openflow Deployment** and **Runtime** (SPCS-backed, takes ~10 min to provision)

The runtime is suspended at the end of the script — each use case will resume it when needed.

## Use Cases

### 1. REST API Ingestion — [`1_rest-api/`](1_rest-api/README.md)

| | |
|---|---|
| **Duration** | 25–30 min |
| **Source** | Public REST API ([dummyjson.com](https://dummyjson.com)) |
| **Pattern** | Fetch → Enrich → Write |
| **Destination** | Regular table + Iceberg table |

Build a 10-processor NiFi flow from scratch that fetches 30 users, enriches each with shopping cart data via a second API call, and writes the joined result into Snowflake using Snowpipe Streaming.

**What you will learn:**
- NiFi canvas basics (processors, connections, Controller Services)
- REST API ingestion with InvokeHTTP, SplitJson, EvaluateJsonPath
- Data enrichment using NiFi Expression Language
- Snowpipe Streaming via PublishSnowpipeStreaming
- External Access Integration setup
- Writing to Apache Iceberg tables

**Start here:** [`1_rest-api/README.md`](1_rest-api/README.md)

---

### 2. PostgreSQL CDC — [`2_postgres-cdc/`](2_postgres-cdc/README.md)

| | |
|---|---|
| **Duration** | 30–40 min |
| **Source** | Snowflake Managed Postgres |
| **Pattern** | Connector-based CDC (deploy from registry) |
| **Destination** | Regular tables (case-sensitive) |

Set up a real-time Change Data Capture pipeline from Snowflake Managed Postgres to Snowflake. Uses a healthcare dataset (patients, doctors, appointments, visits) with ~380 rows initial load and continuous streaming.

**What you will learn:**
- Snowflake Managed Postgres (instance creation, network policies)
- PostgreSQL logical replication and publications
- Deploying the Openflow CDC connector from the Snowflake Connector Registry
- External Access Integration for SPCS (EGRESS + POSTGRES_INGRESS)
- Real-time CDC verification (INSERT/UPDATE propagation within ~60s)
- Working with case-sensitive identifiers in Snowflake

**Start here:** [`2_postgres-cdc/README.md`](2_postgres-cdc/README.md)
