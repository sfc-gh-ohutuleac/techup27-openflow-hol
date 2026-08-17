# TechUp27 — REST API

**"User Spending Enrichment"** — Join two REST APIs into Snowflake with Openflow

| | |
|---|---|
| **Duration** | 25-30 minutes (after a 10-15 min Openflow overview presentation) |
| **Audience** | Internal Snowflake SEs/SAs, first-time Openflow users (Easy track) |
| **Source APIs** | [DummyJSON Users](https://dummyjson.com/users) + [DummyJSON Carts](https://dummyjson.com/carts) (free, no auth) |

---

## Files in this repo

| File | Description |
|------|-------------|
| `techup27_setup.sql` | SQL script to provision the environment. Run as ACCOUNTADMIN **before** the lab. |
| `techup27_step_by_step.md` | Processor-by-processor cheat sheet with all configs and gotchas. |
| `techup27_flow.json` | Exportable/importable NiFi flow definition. Use as a solution key or starting point. |
| `README.md` | This file. |

---

## Prerequisites (complete before the session)

1. **Openflow quickstart guide completed** — deployment + runtime created and running. Follow: [Getting Started with Openflow on SPCS](https://www.snowflake.com/en/developers/guides/getting-started-with-openflow-spcs/)
2. **Run `techup27_setup.sql` as ACCOUNTADMIN** — creates database, tables, EAI, and grants
3. **Attach `TECHUP27_LAB_EAI` to the runtime** — via Openflow UI or SQL (see setup script for details)
4. **Verify runtime is accessible** — open the NiFi canvas from Snowsight

---

## Goal

Build a data integration pipeline that fetches user data from one API endpoint,
enriches each user with their shopping cart from a second API call, and writes
the joined result into Snowflake — both a regular table and an Iceberg table — all without writing code.

By the end of this lab, attendees can say:

> "I built a multi-source data pipeline in Openflow that calls external APIs,
> joins data across endpoints, and streams results into both a regular Snowflake
> table and an Iceberg table."

---

## What you learn

### 1. NiFi Canvas Basics
- Creating a Process Group
- Adding and configuring processors
- Connecting processors via relationships
- Controller Services (what they are, how to create and enable them)

### 2. FlowFile Concepts
- Content vs Attributes (the two parts of every FlowFile)
- How data moves through processors as FlowFiles
- How processors read/write content vs attributes

### 3. REST API Ingestion Pattern
- Using InvokeHTTP to call external APIs
- Handling JSON array responses with SplitJson
- Extracting fields with EvaluateJsonPath

### 4. Data Enrichment / Lookup Pattern
- Using attributes from one API call to parameterize a second call
- Expression Language basics (`${user_id}` in URLs)
- Joining data from two sources into a single record

### 5. Writing to Snowflake with Snowpipe Streaming
- PutSnowpipeStreaming2 (High-Performance Architecture — best practice)
- Why AttributesToJSON is needed (content vs attributes)
- Authentication via `SNOWFLAKE_MANAGED` on SPCS
- Table constraints (no DEFAULT columns with Snowpipe Streaming)
- Pipe naming convention (`<TABLE_NAME>-STREAMING`, auto-created)

### 6. External Access Integration (EAI)
- Why SPCS runtimes need EAI for external network access
- Network Rules (host:port egress rules)
- Attaching EAI to a runtime (SQL or UI)

### 7. Apache Iceberg (bonus)
- Snowflake-managed Iceberg tables (`EXTERNAL_VOLUME = SNOWFLAKE_MANAGED`)
- Switching from regular to Iceberg = changing one property (the Pipe name)
- Fan-out pattern: same data to regular + Iceberg tables
- `INT` vs `NUMBER` for Iceberg column types
- FLOAT precision differences (IEEE 754 in Parquet)

---

## What is covered

**Snowflake objects created (by setup script):**
- Database (`TECHUP27`)
- Regular table (`USER_SPENDING`)
- Iceberg table (`USER_SPENDING_ICEBERG` — Snowflake-managed)
- Network Rule + External Access Integration
- Role grants

**NiFi processors used (10 total):**
- GenerateFlowFile (trigger/scheduler)
- InvokeHTTP x2 (REST API calls)
- SplitJson (JSON array splitting)
- EvaluateJsonPath x2 (field extraction to attributes)
- UpdateAttribute (set custom attribute values)
- AttributesToJSON (attributes -> JSON content)
- PutSnowpipeStreaming2 x2 (write to regular table + Iceberg table)

**NiFi concepts demonstrated:**
- Process Groups
- Controller Services (JsonTreeReader, StandardWebClientServiceProvider)
- Relationships and auto-termination
- Expression Language (`${attribute_name}`)
- FlowFile content vs attributes
- Run Once (manual trigger for testing)

**Data flow pattern:**
```
Trigger -> Fetch Users (API 1) -> Split -> Extract User Info
  -> Fetch Cart (API 2) -> Extract Cart Totals -> Set Timestamp
  -> Build Record (AttributesToJSON)
      |
      +-> PutSnowpipeStreaming2 (Pipe: USER_SPENDING-STREAMING)         -> regular table
      +-> PutSnowpipeStreaming2 (Pipe: USER_SPENDING_ICEBERG-STREAMING) -> Iceberg table
```

---

## Success criteria

The lab is complete when:
- `SELECT COUNT(*) FROM TECHUP27.PUBLIC.USER_SPENDING` returns **30 rows**
- `SELECT COUNT(*) FROM TECHUP27.PUBLIC.USER_SPENDING_ICEBERG` returns **30 rows**
- All columns are populated (USER_ID, names, cart totals, INGESTED_AT)
- No bulletin errors on the NiFi canvas
- Attendee understands the fetch -> enrich -> write pattern
