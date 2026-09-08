## 1. Test Real-Time CDC

Now test that changes in Postgres are replicated to Snowflake in real-time.

### 1.1 Insert New Data (in DBeaver)


-- Insert a new patient
INSERT INTO healthcare.patients (first_name, last_name, date_of_birth, gender, email, phone, city, state, zip_code, insurance_provider, insurance_id)
VALUES ('CDC', 'TestPatient', '2000-01-01', 'Male', 'cdc.test@email.com', '555-9999', 'San Francisco', 'CA', '94102', 'BlueCross', 'BC-CDC01');

-- Insert a new appointment
INSERT INTO healthcare.appointments (patient_id, doctor_id, appointment_date, appointment_type, status, notes)
VALUES (
    (SELECT patient_id FROM healthcare.patients WHERE last_name = 'TestPatient'),
    1,
    CURRENT_TIMESTAMP + INTERVAL '1 day',
    'consultation',
    'scheduled',
    'CDC test appointment - should appear in Snowflake'
);


### 1.2 Verify in Snowflake (wait ~30-60 seconds)

-- Check the new patient appeared
SELECT "first_name", "last_name", "email" 
FROM QUICKSTART_PGCDC_DB."healthcare"."patients"
WHERE "last_name" = 'TestPatient';

-- Check new appointment
SELECT a."appointment_type", a."status", a."notes"
FROM QUICKSTART_PGCDC_DB."healthcare"."appointments" a
WHERE a."notes" ILIKE '%CDC test%';


### 1.3 Test UPDATE (in DBeaver)


-- Update the test patient's city
UPDATE healthcare.patients 
SET city = 'Los Angeles', updated_at = CURRENT_TIMESTAMP
WHERE last_name = 'TestPatient';


### 1.4 Verify UPDATE in Snowflake (wait ~30-60 seconds)


SELECT "first_name", "last_name", "city", "updated_at"
FROM QUICKSTART_PGCDC_DB."healthcare"."patients"
WHERE "last_name" = 'TestPatient';
-- Should show city = 'Los Angeles'


### 1.5 Verify Updated Row Counts


SELECT 'patients' AS tbl, COUNT(*) AS cnt FROM QUICKSTART_PGCDC_DB."healthcare"."patients"
UNION ALL SELECT 'doctors', COUNT(*) FROM QUICKSTART_PGCDC_DB."healthcare"."doctors"
UNION ALL SELECT 'appointments', COUNT(*) FROM QUICKSTART_PGCDC_DB."healthcare"."appointments"
UNION ALL SELECT 'visits', COUNT(*) FROM QUICKSTART_PGCDC_DB."healthcare"."visits"
ORDER BY tbl;


Expected (after CDC inserts):

| TBL | CNT |
|-----|-----|
| appointments | 171 |
| doctors | 10 |
| patients | 101 |
| visits | 100 |

---