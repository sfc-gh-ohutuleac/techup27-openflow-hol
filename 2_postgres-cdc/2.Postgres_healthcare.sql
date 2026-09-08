
-- ============================================================================
--
-- OpenFlow PostgreSQL CDC Quickstart - PostgreSQL Initialization
--
-- This script initializes the PostgreSQL database with:
-- 1. Healthcare schema and tables
-- 2. Synthetic snapshot data (100 patients, 10 doctors, 150 appointments, 100 visits)
-- 3. CDC configuration (publication for logical replication)
--
-- Run this script on your PostgreSQL instance
-- Prerequisites: PostgreSQL 12+, logical replication enabled
-- ============================================================================

-- Step 1: Grant Replication Privileges
-- ----------------------------------------------------------------------------
-- Prerequisites: 
--   - PostgreSQL 12+ with logical replication enabled (wal_level = logical)
--   - For managed services, enable logical replication via service console/UI

-- Grant replication privileges to the postgres user (required for CDC)
-- To use a different user, run: psql -v pguser=youruser -f 0.init_healthcare.sql
-- Or set PGUSER environment variable before running


select version();
> **Note:** Snowflake Managed Postgres comes with `wal_level = logical` enabled by default. No configuration change needed.

SHOW wal_level;
-- Step 2: Create Schema
-- ----------------------------------------------------------------------------

DROP SCHEMA IF EXISTS healthcare CASCADE;
CREATE SCHEMA healthcare;

SET search_path TO healthcare;

-- Step 3: Create Tables
-- ----------------------------------------------------------------------------

-- Patients table
CREATE TABLE healthcare.patients (
    patient_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    date_of_birth DATE NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100),
    address VARCHAR(200),
    city VARCHAR(50),
    state VARCHAR(2),
    insurance_provider VARCHAR(100),
    registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Doctors table
CREATE TABLE healthcare.doctors (
    doctor_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    specialization VARCHAR(50) NOT NULL,
    department VARCHAR(50),
    phone VARCHAR(20),
    email VARCHAR(100),
    years_of_experience INT CHECK (years_of_experience >= 0),
    accepting_new_patients BOOLEAN DEFAULT TRUE
);

-- Appointments table (main CDC demo table)
CREATE TABLE healthcare.appointments (
    appointment_id SERIAL PRIMARY KEY,
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('scheduled', 'confirmed', 'checked_in', 'in_progress', 'completed', 'cancelled', 'no_show')),
    reason_for_visit VARCHAR(200),
    appointment_type VARCHAR(20) CHECK (appointment_type IN ('routine', 'urgent', 'follow_up', 'annual')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
);

-- Visits table (completed appointment records)
CREATE TABLE healthcare.visits (
    visit_id SERIAL PRIMARY KEY,
    appointment_id INT NOT NULL,
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    visit_date DATE NOT NULL,
    visit_start_time TIMESTAMP NOT NULL,
    visit_end_time TIMESTAMP,
    diagnosis VARCHAR(200),
    treatment_notes TEXT,
    follow_up_required BOOLEAN DEFAULT FALSE,
    prescription_given BOOLEAN DEFAULT FALSE,
    total_charge DECIMAL(10,2) CHECK (total_charge >= 0),
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id),
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
);

-- Create indexes for better query performance
CREATE INDEX idx_appointments_patient ON appointments(patient_id);
CREATE INDEX idx_appointments_doctor ON appointments(doctor_id);
CREATE INDEX idx_appointments_date ON appointments(appointment_date);
CREATE INDEX idx_appointments_status ON appointments(status);
CREATE INDEX idx_visits_patient ON visits(patient_id);
CREATE INDEX idx_visits_doctor ON visits(doctor_id);
CREATE INDEX idx_visits_date ON visits(visit_date);

-- Step 4: Load Synthetic Snapshot Data
-- ----------------------------------------------------------------------------

-- Insert 10 Doctors (various specializations)
INSERT INTO doctors (first_name, last_name, specialization, department, phone, email, years_of_experience, accepting_new_patients) VALUES
('Sarah', 'Johnson', 'General Practice', 'Primary Care', '555-0101', 'sarah.johnson@democlinic.example', 15, TRUE),
('Michael', 'Chen', 'General Practice', 'Primary Care', '555-0102', 'michael.chen@democlinic.example', 8, TRUE),
('Emily', 'Rodriguez', 'General Practice', 'Primary Care', '555-0103', 'emily.rodriguez@democlinic.example', 12, TRUE),
('David', 'Patel', 'Cardiology', 'Cardiovascular', '555-0104', 'david.patel@democlinic.example', 20, TRUE),
('Jennifer', 'Williams', 'Cardiology', 'Cardiovascular', '555-0105', 'jennifer.williams@democlinic.example', 18, TRUE),
('Robert', 'Brown', 'Pediatrics', 'Children Services', '555-0106', 'robert.brown@democlinic.example', 10, TRUE),
('Lisa', 'Martinez', 'Pediatrics', 'Children Services', '555-0107', 'lisa.martinez@democlinic.example', 7, TRUE),
('James', 'Taylor', 'Orthopedics', 'Surgical Services', '555-0108', 'james.taylor@democlinic.example', 25, TRUE),
('Amanda', 'Anderson', 'Dermatology', 'Specialty Care', '555-0109', 'amanda.anderson@democlinic.example', 9, TRUE),
('Christopher', 'Thomas', 'Internal Medicine', 'Primary Care', '555-0110', 'christopher.thomas@democlinic.example', 14, TRUE);

select * from doctors d 

-- Insert 100 Patients (synthetic data with diverse demographics)
INSERT INTO patients (first_name, last_name, date_of_birth, phone, email, address, city, state, insurance_provider, registration_date) VALUES
('John', 'Smith', '1980-03-15', '555-1001', 'john.smith@email.com', '123 Main St', 'Springfield', 'IL', 'HealthGuard Insurance', '2022-01-15 09:30:00'),
('Mary', 'Johnson', '1975-07-22', '555-1002', 'mary.johnson@email.com', '456 Oak Ave', 'Portland', 'OR', 'WellCare Plus', '2022-01-20 10:15:00'),
('Patricia', 'Williams', '1992-11-08', '555-1003', 'patricia.williams@email.com', '789 Pine Rd', 'Austin', 'TX', 'Premier Health Network', '2022-02-05 14:20:00'),
('James', 'Brown', '1988-05-30', '555-1004', 'james.brown@email.com', '321 Elm St', 'Denver', 'CO', 'Wellness First Insurance', '2022-02-10 11:45:00'),
('Jennifer', 'Davis', '1995-09-12', '555-1005', 'jennifer.davis@email.com', '654 Maple Dr', 'Seattle', 'WA', 'CareBridge Health', '2022-03-01 13:00:00'),
('Michael', 'Miller', '1970-12-25', '555-1006', 'michael.miller@email.com', '987 Birch Ln', 'Boston', 'MA', 'Medicare', '2022-03-15 09:00:00'),
('Linda', 'Wilson', '1983-04-18', '555-1007', 'linda.wilson@email.com', '147 Cedar Ct', 'Phoenix', 'AZ', 'LifeSecure Health', '2022-04-01 10:30:00'),
('Robert', 'Moore', '1978-08-07', '555-1008', 'robert.moore@email.com', '258 Spruce Way', 'Miami', 'FL', 'Guardian Health Plans', '2022-04-12 15:45:00'),
('Barbara', 'Taylor', '1990-02-14', '555-1009', 'barbara.taylor@email.com', '369 Willow Pl', 'Chicago', 'IL', 'Medicaid', '2022-05-01 08:30:00'),
('William', 'Anderson', '1985-06-21', '555-1010', 'william.anderson@email.com', '741 Ash Blvd', 'Atlanta', 'GA', 'HealthGuard Insurance', '2022-05-15 12:00:00'),
('Elizabeth', 'Thomas', '1972-10-03', '555-1011', 'elizabeth.thomas@email.com', '852 Poplar Ave', 'Dallas', 'TX', 'WellCare Plus', '2022-06-01 09:15:00'),
('David', 'Jackson', '1998-01-28', '555-1012', 'david.jackson@email.com', '963 Sycamore St', 'San Diego', 'CA', 'Premier Health Network', '2022-06-10 14:30:00'),
('Susan', 'White', '1965-05-19', '555-1013', 'susan.white@email.com', '159 Hickory Rd', 'Philadelphia', 'PA', 'Medicare', '2022-07-01 10:45:00'),
('Joseph', 'Harris', '1993-09-09', '555-1014', 'joseph.harris@email.com', '357 Walnut Dr', 'Houston', 'TX', 'Wellness First Insurance', '2022-07-15 13:20:00'),
('Jessica', 'Martin', '1987-11-30', '555-1015', 'jessica.martin@email.com', '753 Chestnut Ln', 'San Antonio', 'TX', 'CareBridge Health', '2022-08-01 11:00:00'),
('Thomas', 'Thompson', '1976-03-22', '555-1016', 'thomas.thompson@email.com', '951 Beech Ct', 'San Jose', 'CA', 'LifeSecure Health', '2022-08-12 15:15:00'),
('Sarah', 'Garcia', '1991-07-11', '555-1017', 'sarah.garcia@email.com', '246 Fir Way', 'Jacksonville', 'FL', 'Guardian Health Plans', '2022-09-01 09:45:00'),
('Charles', 'Martinez', '1982-12-05', '555-1018', 'charles.martinez@email.com', '468 Redwood Pl', 'Columbus', 'OH', 'HealthGuard Insurance', '2022-09-15 12:30:00'),
('Karen', 'Robinson', '1989-04-16', '555-1019', 'karen.robinson@email.com', '579 Sequoia Blvd', 'Fort Worth', 'TX', 'WellCare Plus', '2022-10-01 10:00:00'),
('Daniel', 'Clark', '1974-08-27', '555-1020', 'daniel.clark@email.com', '791 Magnolia Ave', 'Charlotte', 'NC', 'Premier Health Network', '2022-10-15 14:45:00'),
('Nancy', 'Lewis', '1996-02-08', '555-1021', 'nancy.lewis@email.com', '135 Dogwood St', 'Indianapolis', 'IN', 'Medicaid', '2022-11-01 08:15:00'),
('Matthew', 'Lee', '1981-06-19', '555-1022', 'matthew.lee@email.com', '246 Laurel Rd', 'San Francisco', 'CA', 'CareBridge Health', '2022-11-10 13:00:00'),
('Betty', 'Walker', '1968-10-30', '555-1023', 'betty.walker@email.com', '357 Ivy Dr', 'Seattle', 'WA', 'Medicare', '2022-12-01 09:30:00'),
('Anthony', 'Hall', '1994-03-12', '555-1024', 'anthony.hall@email.com', '468 Holly Ln', 'Denver', 'CO', 'Wellness First Insurance', '2023-01-05 11:45:00'),
('Dorothy', 'Allen', '1986-07-23', '555-1025', 'dorothy.allen@email.com', '579 Rose Ct', 'El Paso', 'TX', 'LifeSecure Health', '2023-01-15 15:20:00'),
('Mark', 'Young', '1977-11-04', '555-1026', 'mark.young@email.com', '791 Tulip Way', 'Detroit', 'MI', 'Guardian Health Plans', '2023-02-01 10:15:00'),
('Margaret', 'Hernandez', '1992-05-15', '555-1027', 'margaret.hernandez@email.com', '135 Daisy Pl', 'Memphis', 'TN', 'HealthGuard Insurance', '2023-02-12 12:00:00'),
('Donald', 'King', '1973-09-26', '555-1028', 'donald.king@email.com', '246 Lily Blvd', 'Nashville', 'TN', 'WellCare Plus', '2023-03-01 14:30:00'),
('Lisa', 'Wright', '1999-01-07', '555-1029', 'lisa.wright@email.com', '357 Violet Ave', 'Portland', 'OR', 'Premier Health Network', '2023-03-15 09:45:00'),
('Paul', 'Lopez', '1984-05-18', '555-1030', 'paul.lopez@email.com', '468 Orchid St', 'Las Vegas', 'NV', 'CareBridge Health', '2023-04-01 13:15:00'),
('Sandra', 'Hill', '1971-09-29', '555-1031', 'sandra.hill@email.com', '579 Peony Rd', 'Louisville', 'KY', 'Medicare', '2023-04-10 11:30:00'),
('Steven', 'Scott', '1997-02-10', '555-1032', 'steven.scott@email.com', '791 Azalea Dr', 'Baltimore', 'MD', 'Medicaid', '2023-05-01 08:45:00'),
('Ashley', 'Green', '1988-06-21', '555-1033', 'ashley.green@email.com', '135 Jasmine Ln', 'Milwaukee', 'WI', 'Wellness First Insurance', '2023-05-15 10:20:00'),
('Kenneth', 'Adams', '1979-10-02', '555-1034', 'kenneth.adams@email.com', '246 Camellia Ct', 'Albuquerque', 'NM', 'LifeSecure Health', '2023-06-01 15:00:00'),
('Donna', 'Baker', '1995-03-14', '555-1035', 'donna.baker@email.com', '357 Gardenia Way', 'Tucson', 'AZ', 'Guardian Health Plans', '2023-06-12 12:45:00'),
('Joshua', 'Gonzalez', '1976-07-25', '555-1036', 'joshua.gonzalez@email.com', '468 Zinnia Pl', 'Fresno', 'CA', 'HealthGuard Insurance', '2023-07-01 09:00:00'),
('Carol', 'Nelson', '1991-11-05', '555-1037', 'carol.nelson@email.com', '579 Dahlia Blvd', 'Sacramento', 'CA', 'WellCare Plus', '2023-07-15 14:15:00'),
('Brian', 'Carter', '1983-04-17', '555-1038', 'brian.carter@email.com', '791 Carnation Ave', 'Kansas City', 'MO', 'Premier Health Network', '2023-08-01 11:00:00'),
('Michelle', 'Mitchell', '1969-08-28', '555-1039', 'michelle.mitchell@email.com', '135 Iris St', 'Mesa', 'AZ', 'Medicare', '2023-08-10 13:30:00'),
('George', 'Perez', '1994-12-09', '555-1040', 'george.perez@email.com', '246 Marigold Rd', 'Atlanta', 'GA', 'CareBridge Health', '2023-09-01 10:45:00'),
('Emily', 'Roberts', '2010-05-15', '555-1041', 'emily.roberts.parent@email.com', '123 Happy St', 'Portland', 'OR', 'WellCare Plus', '2023-01-10 09:00:00'),
('Noah', 'Collins', '2012-08-22', '555-1042', 'noah.collins.parent@email.com', '456 Sunshine Ave', 'Seattle', 'WA', 'HealthGuard Insurance', '2023-01-15 10:30:00'),
('Sophia', 'Edwards', '2008-11-30', '555-1043', 'sophia.edwards.parent@email.com', '789 Rainbow Rd', 'Denver', 'CO', 'Premier Health Network', '2023-02-01 11:00:00'),
('Oliver', 'Stewart', '2015-03-12', '555-1044', 'oliver.stewart.parent@email.com', '321 Bright Ln', 'Austin', 'TX', 'Medicaid', '2023-02-10 14:00:00'),
('Emma', 'Sanchez', '2011-07-19', '555-1045', 'emma.sanchez.parent@email.com', '654 Star Dr', 'Phoenix', 'AZ', 'CareBridge Health', '2023-03-01 09:30:00'),
('Liam', 'Morris', '2013-09-25', '555-1046', 'liam.morris.parent@email.com', '987 Cloud Ct', 'San Diego', 'CA', 'Wellness First Insurance', '2023-03-15 10:15:00'),
('Ava', 'Rogers', '2009-12-08', '555-1047', 'ava.rogers.parent@email.com', '147 Moon Way', 'Dallas', 'TX', 'LifeSecure Health', '2023-04-01 13:45:00'),
('Ethan', 'Reed', '2014-04-14', '555-1048', 'ethan.reed.parent@email.com', '258 Sky Pl', 'Houston', 'TX', 'Guardian Health Plans', '2023-04-12 11:20:00'),
('Isabella', 'Cook', '2010-06-28', '555-1049', 'isabella.cook.parent@email.com', '369 Dawn Blvd', 'Chicago', 'IL', 'HealthGuard Insurance', '2023-05-01 08:50:00'),
('Mason', 'Morgan', '2016-10-03', '555-1050', 'mason.morgan.parent@email.com', '741 Dream Ave', 'Miami', 'FL', 'WellCare Plus', '2023-05-15 15:00:00'),
('Richard', 'Bennett', '1945-03-20', '555-1051', 'richard.bennett@email.com', '852 Golden St', 'Boston', 'MA', 'Medicare', '2022-01-05 09:00:00'),
('Helen', 'Wood', '1948-07-15', '555-1052', 'helen.wood@email.com', '963 Silver Rd', 'Philadelphia', 'PA', 'Medicare', '2022-01-12 10:30:00'),
('Frank', 'Barnes', '1942-11-08', '555-1053', 'frank.barnes@email.com', '159 Bronze Dr', 'Phoenix', 'AZ', 'Medicare', '2022-02-01 11:15:00'),
('Ruth', 'Ross', '1950-02-28', '555-1054', 'ruth.ross@email.com', '357 Pearl Ln', 'San Antonio', 'TX', 'Medicare', '2022-02-15 14:00:00'),
('Raymond', 'Henderson', '1947-06-12', '555-1055', 'raymond.henderson@email.com', '753 Diamond Ct', 'San Diego', 'CA', 'Medicare', '2022-03-01 09:45:00'),
('Virginia', 'Coleman', '1944-09-24', '555-1056', 'virginia.coleman@email.com', '951 Ruby Way', 'Dallas', 'TX', 'Medicare', '2022-03-10 13:20:00'),
('Harold', 'Jenkins', '1949-12-30', '555-1057', 'harold.jenkins@email.com', '246 Emerald Pl', 'San Jose', 'CA', 'Medicare', '2022-04-01 10:00:00'),
('Janet', 'Perry', '1951-04-05', '555-1058', 'janet.perry@email.com', '468 Sapphire Blvd', 'Austin', 'TX', 'Medicare', '2022-04-15 12:30:00'),
('Gerald', 'Powell', '1946-08-17', '555-1059', 'gerald.powell@email.com', '579 Topaz Ave', 'Jacksonville', 'FL', 'Medicare', '2022-05-01 11:45:00'),
('Evelyn', 'Long', '1943-11-22', '555-1060', 'evelyn.long@email.com', '791 Opal St', 'Columbus', 'OH', 'Medicare', '2022-05-12 15:15:00'),
('Carl', 'Patterson', '1986-01-15', '555-1061', 'carl.patterson@email.com', '321 Valley Rd', 'Seattle', 'WA', 'WellCare Plus', '2023-06-01 09:00:00'),
('Deborah', 'Hughes', '1990-05-20', '555-1062', 'deborah.hughes@email.com', '654 Hill Dr', 'Portland', 'OR', 'HealthGuard Insurance', '2023-06-15 10:30:00'),
('Lawrence', 'Flores', '1978-09-10', '555-1063', 'lawrence.flores@email.com', '987 Creek Ln', 'Denver', 'CO', 'Premier Health Network', '2023-07-01 11:15:00'),
('Rose', 'Washington', '1993-02-28', '555-1064', 'rose.washington@email.com', '147 River Ct', 'Austin', 'TX', 'CareBridge Health', '2023-07-15 14:45:00'),
('Terry', 'Butler', '1981-06-14', '555-1065', 'terry.butler@email.com', '258 Lake Way', 'Phoenix', 'AZ', 'Wellness First Insurance', '2023-08-01 09:30:00'),
('Judy', 'Simmons', '1975-10-22', '555-1066', 'judy.simmons@email.com', '369 Pond Pl', 'San Diego', 'CA', 'LifeSecure Health', '2023-08-12 13:00:00'),
('Jeffrey', 'Foster', '1996-03-08', '555-1067', 'jeffrey.foster@email.com', '741 Stream Blvd', 'Dallas', 'TX', 'Guardian Health Plans', '2023-09-01 10:15:00'),
('Kathleen', 'Gonzales', '1984-07-18', '555-1068', 'kathleen.gonzales@email.com', '852 Bay Ave', 'Houston', 'TX', 'HealthGuard Insurance', '2023-09-15 12:45:00'),
('Harold', 'Bryant', '1972-11-25', '555-1069', 'harold.bryant@email.com', '963 Ocean St', 'Chicago', 'IL', 'WellCare Plus', '2023-10-01 11:30:00'),
('Amy', 'Alexander', '1998-04-02', '555-1070', 'amy.alexander@email.com', '159 Shore Rd', 'Miami', 'FL', 'Premier Health Network', '2023-10-15 15:00:00'),
('Gregory', 'Russell', '1987-08-13', '555-1071', 'gregory.russell@email.com', '357 Beach Dr', 'Boston', 'MA', 'Medicare', '2023-11-01 09:45:00'),
('Shirley', 'Griffin', '1970-12-19', '555-1072', 'shirley.griffin@email.com', '753 Coast Ln', 'Philadelphia', 'PA', 'Medicaid', '2023-11-10 14:20:00'),
('Eric', 'Diaz', '1994-05-30', '555-1073', 'eric.diaz@email.com', '951 Harbor Ct', 'Phoenix', 'AZ', 'CareBridge Health', '2023-12-01 10:30:00'),
('Angela', 'Hayes', '1982-09-07', '555-1074', 'angela.hayes@email.com', '246 Port Way', 'San Antonio', 'TX', 'Wellness First Insurance', '2024-01-05 13:15:00'),
('Stephen', 'Myers', '1976-02-14', '555-1075', 'stephen.myers@email.com', '468 Dock Pl', 'San Diego', 'CA', 'LifeSecure Health', '2024-01-15 11:00:00'),
('Laura', 'Ford', '1991-06-25', '555-1076', 'laura.ford@email.com', '579 Wharf Blvd', 'Dallas', 'TX', 'Guardian Health Plans', '2024-02-01 12:30:00'),
('Andrew', 'Hamilton', '1979-10-11', '555-1077', 'andrew.hamilton@email.com', '791 Marina Ave', 'San Jose', 'CA', 'HealthGuard Insurance', '2024-02-12 15:45:00'),
('Cynthia', 'Graham', '1995-03-22', '555-1078', 'cynthia.graham@email.com', '135 Pier St', 'Austin', 'TX', 'WellCare Plus', '2024-03-01 09:15:00'),
('Peter', 'Sullivan', '1983-07-04', '555-1079', 'peter.sullivan@email.com', '246 Jetty Rd', 'Jacksonville', 'FL', 'Premier Health Network', '2024-03-15 10:45:00'),
('Marie', 'Wallace', '1968-11-16', '555-1080', 'marie.wallace@email.com', '357 Quay Dr', 'Columbus', 'OH', 'Medicare', '2024-04-01 14:00:00'),
('Roy', 'Woods', '1992-04-27', '555-1081', 'roy.woods@email.com', '468 Inlet Ln', 'Fort Worth', 'TX', 'CareBridge Health', '2024-04-10 11:20:00'),
('Frances', 'Cole', '1980-08-08', '555-1082', 'frances.cole@email.com', '579 Cove Ct', 'Charlotte', 'NC', 'Wellness First Insurance', '2024-05-01 13:50:00'),
('Randy', 'West', '1974-12-20', '555-1083', 'randy.west@email.com', '791 Sound Way', 'Indianapolis', 'IN', 'LifeSecure Health', '2024-05-15 10:00:00'),
('Diana', 'Jordan', '1997-05-01', '555-1084', 'diana.jordan@email.com', '135 Reef Pl', 'San Francisco', 'CA', 'Guardian Health Plans', '2024-06-01 12:15:00'),
('Russell', 'Owens', '1985-09-12', '555-1085', 'russell.owens@email.com', '246 Tide Blvd', 'Seattle', 'WA', 'HealthGuard Insurance', '2024-06-10 15:30:00'),
('Gloria', 'Reynolds', '1971-02-23', '555-1086', 'gloria.reynolds@email.com', '357 Wave Ave', 'Denver', 'CO', 'WellCare Plus', '2024-07-01 09:30:00'),
('Henry', 'Fisher', '1999-06-04', '555-1087', 'henry.fisher@email.com', '468 Surf St', 'El Paso', 'TX', 'Premier Health Network', '2024-07-15 11:45:00'),
('Theresa', 'Ellis', '1988-10-15', '555-1088', 'theresa.ellis@email.com', '579 Foam Rd', 'Detroit', 'MI', 'Medicaid', '2024-08-01 14:10:00'),
('Arthur', 'Harrison', '1977-03-26', '555-1089', 'arthur.harrison@email.com', '791 Spray Dr', 'Memphis', 'TN', 'CareBridge Health', '2024-08-12 10:25:00'),
('Rebecca', 'Gibson', '1993-07-07', '555-1090', 'rebecca.gibson@email.com', '135 Splash Ln', 'Nashville', 'TN', 'Wellness First Insurance', '2024-09-01 13:40:00'),
('Albert', 'McDonald', '1981-11-18', '555-1091', 'albert.mcdonald@email.com', '246 Ripple Ct', 'Portland', 'OR', 'LifeSecure Health', '2024-09-10 11:55:00'),
('Katherine', 'Cruz', '1969-04-29', '555-1092', 'katherine.cruz@email.com', '357 Current Way', 'Las Vegas', 'NV', 'Guardian Health Plans', '2024-10-01 15:20:00'),
('Wayne', 'Marshall', '1995-08-10', '555-1093', 'wayne.marshall@email.com', '468 Flow Pl', 'Louisville', 'KY', 'HealthGuard Insurance', '2024-10-05 09:05:00'),
('Virginia', 'Ortiz', '1984-12-21', '555-1094', 'virginia.ortiz@email.com', '579 Cascade Blvd', 'Baltimore', 'MD', 'WellCare Plus', '2024-10-10 12:50:00'),
('Jack', 'Gomez', '1973-05-02', '555-1095', 'jack.gomez@email.com', '791 Rapids Ave', 'Milwaukee', 'WI', 'Premier Health Network', '2024-10-15 10:35:00'),
('Catherine', 'Murray', '1990-09-13', '555-1096', 'catherine.murray@email.com', '135 Falls St', 'Albuquerque', 'NM', 'Medicare', '2024-10-20 14:05:00'),
('Douglas', 'Freeman', '1978-01-24', '555-1097', 'douglas.freeman@email.com', '246 Torrent Rd', 'Tucson', 'AZ', 'Medicaid', '2024-10-22 11:40:00'),
('Joyce', 'Wells', '1996-06-05', '555-1098', 'joyce.wells@email.com', '357 Brook Dr', 'Fresno', 'CA', 'CareBridge Health', '2024-10-24 13:25:00'),
('Gary', 'Webb', '1982-10-16', '555-1099', 'gary.webb@email.com', '468 Fountain Ln', 'Sacramento', 'CA', 'Wellness First Insurance', '2024-10-26 09:50:00'),
('Alice', 'Simpson', '1975-03-27', '555-1100', 'alice.simpson@email.com', '579 Spring Ct', 'Kansas City', 'MO', 'LifeSecure Health', '2024-10-28 12:10:00');

-- Insert 150 Past Appointments (mix of completed, cancelled, no-shows)
-- Most recent 90 days of historical data
INSERT INTO appointments (patient_id, doctor_id, appointment_date, appointment_time, status, reason_for_visit, appointment_type, created_at, updated_at)
SELECT 
    (RANDOM() * 99 + 1)::INT as patient_id,
    (RANDOM() * 9 + 1)::INT as doctor_id,
    CURRENT_DATE - (RANDOM() * 90)::INT as appointment_date,
    (TIME '08:00:00' + (RANDOM() * 9 * INTERVAL '1 hour'))::TIME as appointment_time,
    CASE 
        WHEN RANDOM() < 0.70 THEN 'completed'
        WHEN RANDOM() < 0.85 THEN 'cancelled'
        ELSE 'no_show'
    END as status,
    CASE (RANDOM() * 15)::INT
        WHEN 0 THEN 'Annual physical examination'
        WHEN 1 THEN 'Flu symptoms and fever'
        WHEN 2 THEN 'Hypertension follow-up'
        WHEN 3 THEN 'Diabetes management'
        WHEN 4 THEN 'Chest pain evaluation'
        WHEN 5 THEN 'Sports injury - knee pain'
        WHEN 6 THEN 'Skin rash examination'
        WHEN 7 THEN 'Routine checkup'
        WHEN 8 THEN 'Migraine headaches'
        WHEN 9 THEN 'Back pain assessment'
        WHEN 10 THEN 'Respiratory infection'
        WHEN 11 THEN 'Allergic reaction'
        WHEN 12 THEN 'Cardiac assessment'
        WHEN 13 THEN 'Pediatric wellness check'
        ELSE 'General consultation'
    END as reason_for_visit,
    CASE 
        WHEN RANDOM() < 0.60 THEN 'routine'
        WHEN RANDOM() < 0.85 THEN 'follow_up'
        ELSE 'urgent'
    END as appointment_type,
    CURRENT_DATE - (RANDOM() * 95)::INT as created_at,
    CURRENT_DATE - (RANDOM() * 90)::INT as updated_at
FROM generate_series(1, 150);

-- Insert 20 Upcoming Appointments (scheduled/confirmed for next 30 days)
INSERT INTO appointments (patient_id, doctor_id, appointment_date, appointment_time, status, reason_for_visit, appointment_type, created_at, updated_at) VALUES
(1, 1, CURRENT_DATE + 1, '09:00:00', 'scheduled', 'Annual physical examination', 'routine', CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP - INTERVAL '2 days'),
(15, 2, CURRENT_DATE + 1, '10:00:00', 'confirmed', 'Diabetes management checkup', 'follow_up', CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_TIMESTAMP - INTERVAL '1 day'),
(23, 4, CURRENT_DATE + 2, '09:30:00', 'confirmed', 'Cardiac stress test', 'routine', CURRENT_TIMESTAMP - INTERVAL '5 days', CURRENT_TIMESTAMP - INTERVAL '2 days'),
(42, 6, CURRENT_DATE + 2, '11:00:00', 'scheduled', 'Pediatric wellness check', 'routine', CURRENT_TIMESTAMP - INTERVAL '1 day', CURRENT_TIMESTAMP - INTERVAL '1 day'),
(56, 3, CURRENT_DATE + 3, '14:00:00', 'confirmed', 'Hypertension follow-up', 'follow_up', CURRENT_TIMESTAMP - INTERVAL '4 days', CURRENT_TIMESTAMP - INTERVAL '1 day'),
(67, 8, CURRENT_DATE + 3, '15:30:00', 'scheduled', 'Knee pain evaluation', 'urgent', CURRENT_TIMESTAMP - INTERVAL '1 day', CURRENT_TIMESTAMP - INTERVAL '1 day'),
(78, 9, CURRENT_DATE + 5, '10:30:00', 'scheduled', 'Skin rash treatment', 'routine', CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP - INTERVAL '2 days'),
(89, 10, CURRENT_DATE + 5, '13:00:00', 'confirmed', 'Respiratory infection', 'urgent', CURRENT_TIMESTAMP - INTERVAL '1 day', CURRENT_TIMESTAMP),
(12, 1, CURRENT_DATE + 7, '08:30:00', 'scheduled', 'Routine checkup', 'routine', CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_TIMESTAMP - INTERVAL '3 days'),
(34, 5, CURRENT_DATE + 7, '14:30:00', 'scheduled', 'Cardiac consultation', 'routine', CURRENT_TIMESTAMP - INTERVAL '4 days', CURRENT_TIMESTAMP - INTERVAL '4 days'),
(45, 7, CURRENT_DATE + 10, '09:00:00', 'confirmed', 'Child vaccination', 'routine', CURRENT_TIMESTAMP - INTERVAL '6 days', CURRENT_TIMESTAMP - INTERVAL '2 days'),
(58, 2, CURRENT_DATE + 10, '11:30:00', 'scheduled', 'Blood pressure monitoring', 'follow_up', CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP - INTERVAL '2 days'),
(69, 3, CURRENT_DATE + 14, '10:00:00', 'scheduled', 'Annual wellness visit', 'annual', CURRENT_TIMESTAMP - INTERVAL '7 days', CURRENT_TIMESTAMP - INTERVAL '7 days'),
(81, 4, CURRENT_DATE + 14, '15:00:00', 'scheduled', 'Heart health screening', 'routine', CURRENT_TIMESTAMP - INTERVAL '5 days', CURRENT_TIMESTAMP - INTERVAL '5 days'),
(92, 6, CURRENT_DATE + 21, '09:30:00', 'scheduled', 'Growth and development check', 'routine', CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_TIMESTAMP - INTERVAL '3 days'),
(25, 8, CURRENT_DATE + 21, '13:30:00', 'scheduled', 'Sports physical', 'routine', CURRENT_TIMESTAMP - INTERVAL '4 days', CURRENT_TIMESTAMP - INTERVAL '4 days'),
(37, 9, CURRENT_DATE + 28, '11:00:00', 'scheduled', 'Acne treatment follow-up', 'follow_up', CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP - INTERVAL '2 days'),
(48, 10, CURRENT_DATE + 28, '14:00:00', 'scheduled', 'Chronic disease management', 'follow_up', CURRENT_TIMESTAMP - INTERVAL '5 days', CURRENT_TIMESTAMP - INTERVAL '5 days'),
(59, 1, CURRENT_DATE + 30, '08:00:00', 'scheduled', 'Pre-operative consultation', 'routine', CURRENT_TIMESTAMP - INTERVAL '6 days', CURRENT_TIMESTAMP - INTERVAL '6 days'),
(71, 2, CURRENT_DATE + 30, '16:00:00', 'scheduled', 'Medication review', 'follow_up', CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_TIMESTAMP - INTERVAL '3 days');

-- Insert 100 Visit Records (for completed appointments)
-- Generate visits for completed appointments with realistic data
INSERT INTO visits (appointment_id, patient_id, doctor_id, visit_date, visit_start_time, visit_end_time, diagnosis, treatment_notes, follow_up_required, prescription_given, total_charge)
SELECT 
    a.appointment_id,
    a.patient_id,
    a.doctor_id,
    a.appointment_date as visit_date,
    (a.appointment_date || ' ' || a.appointment_time::TEXT)::TIMESTAMP as visit_start_time,
    (a.appointment_date || ' ' || a.appointment_time::TEXT)::TIMESTAMP + INTERVAL '30 minutes' as visit_end_time,
    CASE (RANDOM() * 20)::INT
        WHEN 0 THEN 'Hypertension, controlled'
        WHEN 1 THEN 'Type 2 Diabetes Mellitus'
        WHEN 2 THEN 'Acute upper respiratory infection'
        WHEN 3 THEN 'Acute bronchitis'
        WHEN 4 THEN 'Essential hypertension'
        WHEN 5 THEN 'Acute pharyngitis'
        WHEN 6 THEN 'Allergic rhinitis'
        WHEN 7 THEN 'Contact dermatitis'
        WHEN 8 THEN 'Sprain of knee ligaments'
        WHEN 9 THEN 'Migraine without aura'
        WHEN 10 THEN 'Acute sinusitis'
        WHEN 11 THEN 'Gastroesophageal reflux disease'
        WHEN 12 THEN 'Osteoarthritis of knee'
        WHEN 13 THEN 'Anxiety disorder'
        WHEN 14 THEN 'Hyperlipidemia'
        WHEN 15 THEN 'Vitamin D deficiency'
        WHEN 16 THEN 'Chronic lower back pain'
        WHEN 17 THEN 'Atrial fibrillation'
        WHEN 18 THEN 'Asthma, mild persistent'
        WHEN 19 THEN 'Eczema'
        ELSE 'General wellness - no acute findings'
    END as diagnosis,
    CASE (RANDOM() * 10)::INT
        WHEN 0 THEN 'Patient counseled on lifestyle modifications. Continue current medication regimen.'
        WHEN 1 THEN 'Prescribed antibiotics for infection. Rest and fluids recommended.'
        WHEN 2 THEN 'Blood pressure within normal range. Continue monitoring at home.'
        WHEN 3 THEN 'Ordered lab work including CBC and metabolic panel. Follow up in 2 weeks.'
        WHEN 4 THEN 'Referred to specialist for further evaluation.'
        WHEN 5 THEN 'Started new medication. Patient educated on side effects and dosing.'
        WHEN 6 THEN 'Physical therapy recommended. Provided exercises and home care instructions.'
        WHEN 7 THEN 'All vital signs stable. Routine screening tests ordered.'
        WHEN 8 THEN 'Discussed treatment options with patient. Shared decision making approach.'
        ELSE 'Patient doing well. Continue current treatment plan. No changes needed.'
    END as treatment_notes,
    RANDOM() < 0.30 as follow_up_required,
    RANDOM() < 0.40 as prescription_given,
    (75 + RANDOM() * 275)::NUMERIC(10,2) as total_charge
FROM appointments a
WHERE a.status = 'completed'
LIMIT 100;

### Verify Data
 
SELECT 'patients' AS table_name, COUNT(*) AS row_count FROM healthcare.patients
UNION ALL SELECT 'doctors', COUNT(*) FROM healthcare.doctors
UNION ALL SELECT 'appointments', COUNT(*) FROM healthcare.appointments
UNION ALL SELECT 'visits', COUNT(*) FROM healthcare.visits
ORDER BY table_name;

## 6. Configure Postgres for CDC Replication

Run the following in DBeaver to enable logical replication:
 
-- Verify wal_level is set to logical (required for CDC)
SHOW wal_level;
-- Should return: logical

-- Create a publication for all tables in the healthcare schema
CREATE PUBLICATION healthcare_cdc_publication FOR TABLE
    healthcare.patients,
    healthcare.doctors,
    healthcare.appointments,
    healthcare.visits;

-- Verify the publication
SELECT * FROM pg_publication;
SELECT * FROM pg_publication_tables WHERE pubname = 'healthcare_cdc_publication';


select * from appointments a ;--170
select * from patients;--100
select * from visits;--100
select * from doctors;--10
SELECT 
  (SELECT COUNT(*) FROM healthcare.patients) as patients,
  (SELECT COUNT(*) FROM healthcare.doctors) as doctors,
  (SELECT COUNT(*) FROM healthcare.appointments) as appointments,
  (SELECT COUNT(*) FROM healthcare.visits) as visits
  

    -- Run in DBeaver/psql against your Postgres instance after connector connects:
SELECT client_addr, usename, application_name 
FROM pg_stat_activity 
WHERE usename = 'snowflake_admin';
  
  SELECT schemaname, tablename FROM pg_publication_tables WHERE pubname = 'healthcare_cdc_publication';
  
  
  SELECT
    current_setting('wal_level') AS wal_level,
    current_setting('max_replication_slots') AS max_replication_slots,
    current_setting('max_wal_senders') AS max_wal_senders,
    (SELECT count(*) FROM pg_publication) AS publication_count,
    (SELECT count(*) FROM pg_replication_slots) AS active_slots;
  
 --SELECT rolname, rolsuper, rolreplication FROM pg_roles WHERE rolname = '$PGUSER';
  SELECT rolname, rolsuper, rolreplication FROM pg_roles WHERE rolname = 'snowflake_admin';