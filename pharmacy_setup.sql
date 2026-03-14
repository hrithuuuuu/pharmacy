-- ============================================================
-- PHARMACY PORTAL - STANDALONE SUPABASE DEMO SETUP
-- ============================================================
-- Run this in your Supabase SQL Editor to set up the 
-- tables and demo data required for the Pharmacy Portal.
-- ============================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLE CREATION
-- ============================================================

-- PHARMACIES
CREATE TABLE IF NOT EXISTS pharmacies (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  license_no TEXT UNIQUE NOT NULL,
  phone TEXT,
  email TEXT
);

-- CITIZENS (Patients)
CREATE TABLE IF NOT EXISTS citizens (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  mobile TEXT UNIQUE,
  email TEXT,
  city TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- MEDICINES (Master Catalogue)
CREATE TABLE IF NOT EXISTS medicines (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  generic_name TEXT,
  category TEXT,
  brand TEXT,
  manufacturer TEXT,
  price_mrp NUMERIC(10,2),
  requires_prescription BOOLEAN DEFAULT FALSE,
  reorder_level INTEGER DEFAULT 20,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- SUPPLIERS
CREATE TABLE IF NOT EXISTS suppliers (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  pharmacy_id UUID REFERENCES pharmacies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  contact_person TEXT,
  phone TEXT,
  email TEXT
);

-- INVENTORY
CREATE TABLE IF NOT EXISTS inventory (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  pharmacy_id UUID REFERENCES pharmacies(id) ON DELETE CASCADE,
  medicine_id UUID REFERENCES medicines(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  batch_no TEXT,
  expiry_date DATE,
  selling_price NUMERIC(10,2),
  reorder_level INTEGER DEFAULT 20,
  reorder_quantity INTEGER DEFAULT 50,
  supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
  last_updated TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (pharmacy_id, medicine_id)
);

-- SALES TRANSACTIONS
CREATE TABLE IF NOT EXISTS sales_transactions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  pharmacy_id UUID REFERENCES pharmacies(id) ON DELETE SET NULL,
  medicine_id UUID REFERENCES medicines(id) ON DELETE SET NULL,
  medicine_name TEXT,
  quantity_sold INTEGER NOT NULL CHECK (quantity_sold > 0),
  selling_price NUMERIC(10,2),
  total_amount NUMERIC(10,2),
  customer_gender TEXT,
  prescribed BOOLEAN DEFAULT FALSE,
  sold_at TIMESTAMPTZ DEFAULT NOW()
);

-- REMINDERS
CREATE TABLE IF NOT EXISTS reminders (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  pharmacy_id UUID REFERENCES pharmacies(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES citizens(id) ON DELETE CASCADE,
  medicine_id UUID REFERENCES medicines(id) ON DELETE CASCADE,
  last_purchase_date DATE,
  supply_days INTEGER DEFAULT 30,
  next_refill_date DATE,
  reminder_sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- FRAUD MEDICINES (Gov Maintained List)
CREATE TABLE IF NOT EXISTS fraud_medicines (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  medicine_name TEXT NOT NULL,
  brand TEXT,
  reason TEXT NOT NULL,
  active BOOLEAN DEFAULT TRUE
);

-- FRAUD ALERTS (Generated on POS scan)
CREATE TABLE IF NOT EXISTS fraud_alerts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  pharmacy_id UUID REFERENCES pharmacies(id),
  pharmacy_name TEXT,
  medicine_name TEXT NOT NULL,
  fraud_medicine_id UUID REFERENCES fraud_medicines(id),
  transaction_id UUID REFERENCES sales_transactions(id),
  quantity_sold INTEGER,
  detected_at TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT
);

-- ============================================================
-- DEMO DATA SEEDING
-- ============================================================

-- 1. Insert Demo Pharmacy (Must match JS: KL-EKM-002)
INSERT INTO pharmacies (name, license_no, phone, email)
VALUES ('Ananthapuri Medical — Kakkanad', 'KL-EKM-002', '0484-3456789', 'ananthapuri@demo.in')
ON CONFLICT (license_no) DO NOTHING;

-- 2. Insert Demo Citizens (Patients)
INSERT INTO citizens (name, mobile, email, city)
VALUES 
  ('Ramesh Iyer', '9876501234', 'ramesh@email.com', 'Ernakulam'),
  ('Priya Nair', '9876502345', 'priya@email.com', 'Ernakulam'),
  ('Arun Krishnan', '9876503456', 'arun@email.com', 'Kochi')
ON CONFLICT (mobile) DO NOTHING;

-- 3. Insert Demo Medicines
INSERT INTO medicines (name, generic_name, category, price_mrp, requires_prescription)
VALUES
  ('Dolo 650mg', 'Paracetamol', 'Analgesic', 32.00, FALSE),
  ('Azithromycin 500mg', 'Azithromycin', 'Antibiotic', 55.00, TRUE),
  ('Metformin 500mg', 'Metformin HCl', 'Antidiabetic', 28.00, TRUE),
  ('Cetirizine 10mg', 'Cetirizine HCl', 'Antihistamine', 12.00, FALSE),
  ('Amlodipine 5mg', 'Amlodipine', 'Cardiovascular', 22.00, TRUE)
ON CONFLICT DO NOTHING;

-- 4. Set up Inventory for the Demo Pharmacy
WITH ph AS (SELECT id FROM pharmacies WHERE license_no='KL-EKM-002'),
     m1 AS (SELECT id FROM medicines WHERE name='Dolo 650mg'),
     m2 AS (SELECT id FROM medicines WHERE name='Azithromycin 500mg'),
     m3 AS (SELECT id FROM medicines WHERE name='Metformin 500mg'),
     m4 AS (SELECT id FROM medicines WHERE name='Cetirizine 10mg'),
     m5 AS (SELECT id FROM medicines WHERE name='Amlodipine 5mg')
INSERT INTO inventory (pharmacy_id, medicine_id, quantity, batch_no, expiry_date, selling_price, reorder_level, reorder_quantity)
SELECT ph.id, m1.id, 250, 'B-DOLO-001', CURRENT_DATE + INTERVAL '1 year', 30.00, 50, 200 FROM ph, m1 UNION ALL
SELECT ph.id, m2.id, 45, 'B-AZI-002', CURRENT_DATE + INTERVAL '6 months', 55.00, 50, 100 FROM ph, m2 UNION ALL
SELECT ph.id, m3.id, 120, 'B-MET-003', CURRENT_DATE + INTERVAL '2 years', 28.00, 50, 150 FROM ph, m3 UNION ALL
SELECT ph.id, m4.id, 400, 'B-CET-004', CURRENT_DATE + INTERVAL '1 year', 12.00, 100, 300 FROM ph, m4 UNION ALL
SELECT ph.id, m5.id, 15, 'B-AML-005', CURRENT_DATE + INTERVAL '14 days', 22.00, 30, 100 FROM ph, m5
ON CONFLICT (pharmacy_id, medicine_id) DO UPDATE SET quantity = EXCLUDED.quantity;

-- 5. Insert Demo sales to show in dashboard
WITH ph AS (SELECT id FROM pharmacies WHERE license_no='KL-EKM-002'),
     m1 AS (SELECT id FROM medicines WHERE name='Dolo 650mg'),
     m2 AS (SELECT id FROM medicines WHERE name='Cetirizine 10mg')
INSERT INTO sales_transactions (pharmacy_id, medicine_id, medicine_name, quantity_sold, selling_price, total_amount, sold_at)
SELECT ph.id, m1.id, 'Dolo 650mg', 10, 30.00, 300.00, NOW() - INTERVAL '2 hours' FROM ph, m1 UNION ALL
SELECT ph.id, m2.id, 'Cetirizine 10mg', 5, 12.00, 60.00, NOW() - INTERVAL '45 minutes' FROM ph, m2;

-- 6. Insert Fraud Medicine (For POS Demo Alert)
INSERT INTO fraud_medicines (medicine_name, brand, reason, active)
VALUES 
  ('Fake Paracip 500', 'Paracip', 'Counterfeit batch detected. No valid license.', TRUE),
  ('MaxFlu Syrup', 'MaxFlu', 'CDSCO recall order #2026-012.', TRUE)
ON CONFLICT DO NOTHING;

-- 7. Insert a dummy inventory item for the fraud medicine so it can be scanned in POS
WITH ph AS (SELECT id FROM pharmacies WHERE license_no='KL-EKM-002')
INSERT INTO inventory (pharmacy_id, medicine_id, quantity, batch_no, expiry_date, selling_price, reorder_level)
SELECT ph.id, NULL, 50, 'FRAUD-B1', CURRENT_DATE + INTERVAL '1 year', 20.00, 10 FROM ph;

-- To make the fraud item visible in the POS dropdown without a master medicine_id:
-- Wait, the POS fetches from 'inventory' joined with 'medicines'. 
-- Let's add the fraud medicine to the master list too so the Join works:
INSERT INTO medicines (name, generic_name, category, price_mrp) 
VALUES ('Fake Paracip 500', 'Paracetamol', 'Analgesic', 20.00) ON CONFLICT DO NOTHING;

WITH ph AS (SELECT id FROM pharmacies WHERE license_no='KL-EKM-002'),
     mF AS (SELECT id FROM medicines WHERE name='Fake Paracip 500')
INSERT INTO inventory (pharmacy_id, medicine_id, quantity, batch_no, expiry_date, selling_price)
SELECT ph.id, mF.id, 50, 'BAD-BATCH-01', CURRENT_DATE + INTERVAL '1 year', 20.00 FROM ph, mF
ON CONFLICT (pharmacy_id, medicine_id) DO UPDATE SET quantity = EXCLUDED.quantity;

-- ============================================================
-- NOTE: Please ensure RLS (Row Level Security) is either DISABLED 
-- for testing, or you have policies allowing SELECT, INSERT, 
-- UPDATE, and DELETE.
-- ============================================================
