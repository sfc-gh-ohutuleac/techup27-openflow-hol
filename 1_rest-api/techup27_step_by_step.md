# TechUp27 — Step by Step Guide

## Goal

Fetch 30 users from an API, enrich each with their shopping cart data from a second API call, and write the joined result to Snowflake via Snowpipe Streaming.

## APIs Used

Both APIs are on the same host (`dummyjson.com`), free, no authentication required.

| API | URL |
|-----|-----|
| Users | `GET https://dummyjson.com/users?limit=30&select=id,firstName,lastName,email,address` |
| Carts | `GET https://dummyjson.com/carts/user/{userId}` |

---

## Flow Overview

```
  +---------------------------+
  | 1. GenerateFlowFile       |  Trigger — kicks off the pipeline
  +---------------------------+
              |
  +---------------------------+
  | 2. InvokeHTTP             |  GET /users — fetches all 30 users as JSON array
  +---------------------------+
              |
  +---------------------------+
  | 3. SplitJson              |  Split array into 30 individual FlowFiles
  +---------------------------+
              |
  +---------------------------+
  | 4. EvaluateJsonPath       |  Extract user fields into FlowFile attributes
  +---------------------------+
              |
  +---------------------------+
  | 5. InvokeHTTP             |  GET /carts/user/{id} — fetch cart for this user
  +---------------------------+
              |
  +---------------------------+
  | 6. EvaluateJsonPath       |  Extract cart totals into FlowFile attributes
  +---------------------------+
              |
  +---------------------------+
  | 7. UpdateAttribute        |  Set ingestion timestamp
  +---------------------------+
              |
  +---------------------------+
  | 8. AttributesToJSON       |  Convert attributes -> flat JSON (FlowFile content)
  +---------------------------+
              |
  +---------------------------+
  | 9. PutSnowpipeStreaming2  |  Write to TECHUP27.PUBLIC.USER_SPENDING
  +---------------------------+
```

---

## How to add a processor

1. Drag the **processor icon** from the top toolbar onto the canvas
<img width="627" height="211" alt="image" src="https://github.com/user-attachments/assets/c5185507-874d-4945-b17e-dc99241fb54b" />

2. In the dialog, search for the processor type (e.g., "GenerateFlowFile")
3. Select it and click **Add**
4. Double-click the processor to configure its properties

---

## How connections work

Connections are created **between two existing processors**. You cannot create a connection until both the source and destination processors exist on the canvas.

**To create a connection:**
1. Hover over the source processor until you see a small arrow icon
2. Drag from the source processor to the destination processor
<img width="598" height="560" alt="image" src="https://github.com/user-attachments/assets/a95699d5-6dcf-4b44-8257-fed910193355" />

3. In the dialog, select which **relationship(s)** to route (e.g., "success", "Response")
4. Click **Add**



> **Note:** In the steps below, each processor mentions which relationship to connect and where. Create the connection **after** you have added both the current processor and the next one.

---

## How to list FlowFiles and view their content

When debugging, you can inspect what's queued between two processors:

1. Click on a **connection** (the line between two processors)
2. Click **"List queue"** in the context panel
3. You'll see a list of FlowFiles currently waiting in that connection
4. Click the **eye icon** on a FlowFile to view its **attributes**
5. Click the **"View content"** button to see the actual **content** (the JSON body)

This is essential for debugging:
- After InvokeHTTP: check the API response is what you expect
- After EvaluateJsonPath: verify attributes were extracted correctly
- After AttributesToJSON: confirm the final flat JSON matches your table schema

> **Tip:** To inspect FlowFiles mid-flow, temporarily stop the downstream processor. FlowFiles will queue up in the connection and you can inspect them. Start the processor again when done.

---

## How to test as you build

You don't have to build the entire flow before testing. You can test incrementally:

1. **After connecting your first three processors** (e.g., Trigger -> Fetch Users -> Split Users):
   - Right-click the Trigger processor > **"Run Once"**
   - Right-click Fetch Users > **"Run Once"**
   - The FlowFile queues in the connection between Fetch Users and Split Users

2. **Inspect the result:**
   - Click the connection between Fetch Users and Split Users
   - Click **"List queue"** > click the eye icon > **"View content"**
   - You should see the full JSON response from the API

3. **Continue building:**
   - Add the next processor (e.g., Extract User Info), connect Split Users to it
   - Right-click Split Users > **"Run Once"**
   - Inspect the connection between Split Users and Extract User Info to see the 30 individual records
   - Repeat: add next processor, connect, run once, inspect

This "build one step, test, build next step" approach helps catch issues early. You'll know immediately if an API call failed, a JsonPath is wrong, or an attribute wasn't extracted correctly.

> **Why three processors minimum?** With only two processors connected, there's no outgoing connection on the second processor to queue FlowFiles into — the FlowFile has nowhere to go. You need at least a third processor (or auto-terminated relationships) to create a queue you can inspect.

---

## Step-by-step

### Step 1: GenerateFlowFile

| Property | Value |
|----------|-------|
| **Name** | `Trigger (run once)` |
| **Scheduling** | Run Schedule: `1 hour` |

Leave all other properties as default. For the lab, you will trigger it manually with right-click > **"Run Once"**.

**Connection to next:** After creating Step 2, connect `success` -> Fetch Users.

---

### Step 2: InvokeHTTP — Fetch Users

| Property | Value |
|----------|-------|
| **Name** | `Fetch Users` |
| HTTP Method | `GET` |
| HTTP URL | `https://dummyjson.com/users?limit=30&select=id,firstName,lastName,email,address` |

**Auto-terminate:** Original, Retry, No Retry, Failure

**Connection to next:** After creating Step 3, connect `Response` -> Split Users.

---

### Step 3: SplitJson

| Property | Value |
|----------|-------|
| **Name** | `Split Users` |
| JsonPath Expression | `$.users[*]` |

**Auto-terminate:** original, failure

**Connection to next:** After creating Step 4, connect `split` -> Extract User Info.

---

### Step 4: EvaluateJsonPath — Extract User Info

| Property | Value |
|----------|-------|
| **Name** | `Extract User Info` |
| Destination | `flowfile-attribute` |
| Return Type | `auto-detect` |

**Dynamic properties** (click "+" to add each one):

| Property name | Value |
|---------------|-------|
| `user_id` | `$.id` |
| `first_name` | `$.firstName` |
| `last_name` | `$.lastName` |
| `email` | `$.email` |
| `city` | `$.address.city` |
| `country` | `$.address.country` |

**Auto-terminate:** failure, unmatched

**Connection to next:** After creating Step 5, connect `matched` -> Fetch Cart.

---

### Step 5: InvokeHTTP — Fetch Cart

| Property | Value |
|----------|-------|
| **Name** | `Fetch Cart` |
| HTTP Method | `GET` |
| HTTP URL | `https://dummyjson.com/carts/user/${user_id}` |

The `${user_id}` is NiFi Expression Language — it reads the FlowFile attribute set by Step 4. This is how we parameterize the second API call per user.

**Auto-terminate:** Original, Retry, No Retry, Failure

**Connection to next:** After creating Step 6, connect `Response` -> Extract Cart Totals.

---

### Step 6: EvaluateJsonPath — Extract Cart Totals

| Property | Value |
|----------|-------|
| **Name** | `Extract Cart Totals` |
| Destination | `flowfile-attribute` |
| Return Type | `auto-detect` |

**Dynamic properties:**

| Property name | Value |
|---------------|-------|
| `cart_total` | `$.carts[0].total` |
| `cart_discounted` | `$.carts[0].discountedTotal` |
| `total_products` | `$.carts[0].totalProducts` |
| `total_quantity` | `$.carts[0].totalQuantity` |

**Auto-terminate:** failure, unmatched

**Connection to next:** After creating Step 7, connect `matched` -> Set Timestamp.

---

### Step 7: UpdateAttribute

| Property | Value |
|----------|-------|
| **Name** | `Set Timestamp` |

**Dynamic properties:**

| Property name | Value |
|---------------|-------|
| `ingested_at` | `${now():format('yyyy-MM-dd HH:mm:ss')}` |

**Auto-terminate:** failure

**Connection to next:** After creating Step 8, connect `success` -> Build Record.

---

### Step 8: AttributesToJSON

| Property | Value |
|----------|-------|
| **Name** | `Build Record` |
| Attributes List | `user_id,first_name,last_name,email,city,country,cart_total,cart_discounted,total_products,total_quantity,ingested_at` |
| Destination | `flowfile-content` |
| Include Core Attributes | `false` |
| Null Value | `false` |

**Auto-terminate:** failure

**Connection to next:** After creating Step 9, connect `success` -> Write to USER_SPENDING.

> **Why this step?** PutSnowpipeStreaming2 reads FlowFile **content** as records (via the Record Reader). The previous steps stored data in FlowFile **attributes**. This processor converts those attributes into a flat JSON object in the FlowFile content so the Record Reader can parse it.

---

### Step 9a: Create Controller Services

PutSnowpipeStreaming2 requires two controller services. Create and enable them now.

**How to create a controller service:**
1. Right-click on empty canvas space inside your Process Group
2. Select **"Controller Services"**
3. Click the **"+"** button
4. Search for the service type, select it, click **Add**
5. Click the **lightning bolt** icon to **Enable** it

| # | Type to search | Notes |
|---|---------------|-------|
| 1 | `JsonTreeReader` | Parses JSON content into records. Default settings are fine. |
| 2 | `StandardWebClientServiceProvider` | HTTP client used by PutSnowpipeStreaming2. Default settings are fine. |

---

### Step 9b: PutSnowpipeStreaming2

| Property | Value |
|----------|-------|
| **Name** | `Write to USER_SPENDING` |
| **Processor type** | `PutSnowpipeStreaming2` |
| Authentication Strategy | `SNOWFLAKE_MANAGED` |
| Database | `TECHUP27` |
| Schema | `PUBLIC` |
| Pipe | `USER_SPENDING-STREAMING` |
| Web Client Service Provider | *(select the StandardWebClientServiceProvider you created)* |
| Transfer Strategy | `ROWS` |
| Offset Tracking Resolution | `FLOW_FILE` |
| Offset Token Start Expression | `${user_id}` |
| Offset Token End Expression | `${user_id}` |
| Channel Group | `SHARED` |

**Auto-terminate:** success, failure, invalid

> **About the Pipe name:** PutSnowpipeStreaming2 writes through a PIPE object, not directly to a table. The pipe `<TABLE_NAME>-STREAMING` is auto-created by Snowflake on first use. You do NOT need to create it manually.

> **About Authentication Strategy:** When set to `SNOWFLAKE_MANAGED`, the processor uses the runtime's built-in session token. No Account, User, Role, or Private Key configuration is needed — those fields can be left empty or set to any value.

> **About Offset Tokens:** These track which records have been committed (for delivery guarantees). They must be **numeric**. We use `${user_id}` because it's already available as an attribute, is numeric (1-30), and is meaningful. In production you'd use a Kafka offset or sequence number.

> **Reloading data after a mistake:** Because we use `user_id` as the offset token, the processor remembers which user IDs have already been committed. If you need to reload the data (e.g., wrong config on first run), simply **truncate the target table** and the processor will re-send all records on the next trigger:
> ```sql
> TRUNCATE TABLE TECHUP27.PUBLIC.USER_SPENDING;
> ```
> The offset tracking resets when the table is truncated.

---

## Verification

After building all processors and connections:

1. Right-click the **Trigger** processor > **"Run Once"**
2. Wait ~20 seconds for data to flow through
3. Check for errors: look for red bulletin icons on any processor
4. Query the results:

```sql
SELECT COUNT(*) FROM TECHUP27.PUBLIC.USER_SPENDING;
-- Expected: 30 rows

SELECT USER_ID, FIRST_NAME, LAST_NAME, CITY, CART_TOTAL, INGESTED_AT
FROM TECHUP27.PUBLIC.USER_SPENDING
ORDER BY CART_TOTAL DESC
LIMIT 5;
-- Top spender: user 30 (Addison Wright, ~$186K cart total)
```

---

## Bonus: Add Iceberg Table

The key insight: **switching from a regular table to Iceberg is a one-property change**. Since we already use PutSnowpipeStreaming2 for the regular table, adding Iceberg is:

1. Duplicate the processor (copy/paste or create a new one)
2. Change the **Pipe** property from `USER_SPENDING-STREAMING` to `USER_SPENDING_ICEBERG-STREAMING`

That's it. Same processor type, same auth, same config.

### Step 10: Add PutSnowpipeStreaming2 for Iceberg

| Property | Value |
|----------|-------|
| **Name** | `Write to USER_SPENDING_ICEBERG` |
| **Pipe** | `USER_SPENDING_ICEBERG-STREAMING` |
| *(everything else)* | *(identical to Step 9)* |

**Auto-terminate:** success, failure, invalid

**Connection:** Connect `Build Record` "success" -> `Write to USER_SPENDING_ICEBERG`

This is a **fan-out**: Build Record now has TWO outgoing "success" connections — NiFi automatically clones the FlowFile to both destinations.

### Verify Iceberg

```sql
SELECT COUNT(*) FROM TECHUP27.PUBLIC.USER_SPENDING_ICEBERG;
-- Expected: 30 rows (may take up to 30s due to Iceberg metadata commit latency)
```

### Key points for attendees

- Same processor, same config, only the pipe name changed
- The pipe `<TABLE_NAME>-STREAMING` is auto-created on first use
- `SNOWFLAKE_MANAGED` external volume = no S3/Azure configuration
- Same query syntax: `SELECT * FROM USER_SPENDING_ICEBERG` works identically
- Iceberg table stores data as Parquet + Iceberg metadata under the hood

---

## Gotchas and Tips

1. **EAI must be attached** before InvokeHTTP can reach dummyjson.com. "UnknownHostException" = EAI not attached.

2. **No DEFAULT columns.** PutSnowpipeStreaming2 cannot write to tables with DEFAULT values. That's why INGESTED_AT is VARCHAR, not `TIMESTAMP DEFAULT CURRENT_TIMESTAMP()`.

3. **Content vs Attributes.** PutSnowpipeStreaming2 reads FlowFile content, not attributes. AttributesToJSON bridges this gap.

4. **InvokeHTTP relationships.** "Response" = the API response body. "Original" = the input FlowFile (discard it).

5. **EvaluateJsonPath behavior.** With `Destination=flowfile-attribute`, the content stays unchanged but values are extracted into attributes. The next InvokeHTTP will overwrite the content.

6. **Duplicates.** The trigger fires every hour. Only run once per lab session. In production, use MERGE or dedup views.

7. **FLOAT precision in Iceberg.** Iceberg stores FLOAT as IEEE 754 single-precision (Parquet native). You may see `13037.879882812` instead of `13037.88`. Use `DECIMAL(10,2)` for exact monetary values.

8. **Iceberg DDL.** Use `INT` not `NUMBER` — Iceberg requires explicit precision for numeric types.

9. **Do NOT use PutSnowpipeStreaming (classic) for Iceberg with SNOWFLAKE_MANAGED storage.** It will hang indefinitely. Always use PutSnowpipeStreaming2 (HPA).
