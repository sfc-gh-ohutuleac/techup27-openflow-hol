## 11. Cleanup

When done with the demo, clean up resources to avoid ongoing costs:

```sql
USE ROLE ACCOUNTADMIN;

-- Stop the OpenFlow connector (do this in the UI first)

-- Drop destination database
DROP DATABASE IF EXISTS QUICKSTART_PGCDC_DB;

-- Drop warehouse
DROP WAREHOUSE IF EXISTS QUICKSTART_PGCDC_WH;

-- Drop role
DROP ROLE IF EXISTS QUICKSTART_ROLE;

-- Drop EAI
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS QUICKSTART_PGCDC_ACCESS;

-- Drop Postgres network policy and rule
DROP NETWORK POLICY IF EXISTS NP_PG_DEV_TEST;
DROP NETWORK RULE IF EXISTS CONFIG.NETWORK.NR_PG_DEV_TEST_ALLOWED;

-- Suspend or drop Postgres instance
ALTER POSTGRES INSTANCE dev_test SUSPEND;
-- Or permanently: DROP POSTGRES INSTANCE dev_test;
```
--Delete the deployment from Openflow to save the cost.
---