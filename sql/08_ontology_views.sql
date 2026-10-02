-- =============================================================================
-- PHASE 8: Ontology Layer (19 views)
-- =============================================================================

USE SCHEMA SUPPLY_CHAIN_HUB.SC_ONT;

-- Entity Views (10)
CREATE OR REPLACE SECURE VIEW ONT_SUPPLIER AS
SELECT supplier_key, erp_vendor_code, suppliernet_uuid, company_name, country, region,
  supplier_group, quality_rating, currency_code, payment_terms_days, is_active, onboarded_date,
  _load_batch_id, _source_file
FROM SUPPLY_CHAIN_HUB.SC_CURATED.DIM_SUPPLIER;

CREATE OR REPLACE SECURE VIEW ONT_PART AS
SELECT part_key, erp_material_nbr, suppliernet_part_number, material_desc, material_type,
  material_group, base_uom, gross_weight_kg, standard_cost_usd, _load_batch_id, _source_file
FROM SUPPLY_CHAIN_HUB.SC_CURATED.DIM_PART;

CREATE OR REPLACE SECURE VIEW ONT_PLANT AS
SELECT plant_key, plant_code, plant_name, freightlink_facility_name, country_code, region,
  city, plant_type, _load_batch_id, _source_file
FROM SUPPLY_CHAIN_HUB.SC_CURATED.DIM_PLANT;

CREATE OR REPLACE SECURE VIEW ONT_CUSTOMER AS
SELECT customer_key, cust_nbr FROM SUPPLY_CHAIN_HUB.SC_CURATED.DIM_CUSTOMER;

CREATE OR REPLACE SECURE VIEW ONT_CARRIER AS
SELECT carrier_key, carrier_name, carrier_type, country_base, region_coverage,
  reliability_score, _load_batch_id, _source_file
FROM SUPPLY_CHAIN_HUB.SC_CURATED.DIM_CARRIER;

CREATE OR REPLACE SECURE VIEW ONT_SALES_ORDER AS
SELECT order_key, plant_code, customer_key, order_date, promised_date, order_status,
  order_total_usd, sales_org, dist_channel, is_cancelled, is_closed,
  _load_batch_id, _source_file, _source_row_number
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SALES_ORDERS;

CREATE OR REPLACE SECURE VIEW ONT_ORDER_LINE AS
SELECT order_key, line_nbr, part_key, erp_material_nbr, quantity_ordered, quantity_delivered,
  uom_canonical, unit_price_usd, line_status, promised_date, is_full_fill, fill_ratio,
  is_cancelled, is_delivered, _load_batch_id, _source_file, _source_row_number
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_ORDER_LINES;

CREATE OR REPLACE SECURE VIEW ONT_SHIPMENT AS
SELECT shipment_key, order_key, carrier_key, plant_key, origin_facility, destination,
  ship_date, promised_delivery_date, actual_delivery_date, weight_kgs, pieces, status,
  damage_flag, is_delivered, is_on_time, is_damaged, days_late,
  _load_batch_id, _source_file, _source_row_number
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SHIPMENTS;

CREATE OR REPLACE SECURE VIEW ONT_INVENTORY_POSITION AS
SELECT plant_code, part_key, erp_material_nbr, snapshot_date, qty_on_hand, qty_in_transit,
  qty_reserved, qty_available, uom, valuation_usd,
  _load_batch_id, _source_file, _source_row_number
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_INVENTORY;

CREATE OR REPLACE SECURE VIEW ONT_PURCHASE_RECEIPT AS
SELECT receipt_id, po_id, supplier_key, part_key, suppliernet_supplier_id, suppliernet_part_number,
  quantity_ordered, quantity_received, uom_canonical, unit_price, currency_code,
  order_date, expected_delivery_date, receipt_date, quality_check_passed, defect_count,
  receiving_plant_code, batch_number, is_on_time, is_complete, fill_ratio,
  _load_batch_id, _source_file, _source_row_number
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_PURCHASE_RECEIPTS;

-- Relationship Views (6)
CREATE OR REPLACE SECURE VIEW REL_SUPPLIER_PART AS
SELECT DISTINCT supplier_key, part_key
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_PURCHASE_RECEIPTS
WHERE supplier_key IS NOT NULL AND part_key IS NOT NULL;

CREATE OR REPLACE SECURE VIEW REL_PART_PLANT AS
SELECT DISTINCT part_key, plant_code
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_INVENTORY WHERE part_key IS NOT NULL;

CREATE OR REPLACE SECURE VIEW REL_PLANT_ORDER AS
SELECT DISTINCT order_key, plant_code FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SALES_ORDERS;

CREATE OR REPLACE SECURE VIEW REL_ORDER_SHIPMENT AS
SELECT DISTINCT order_key, shipment_key FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SHIPMENTS;

CREATE OR REPLACE SECURE VIEW REL_SHIPMENT_CUSTOMER AS
SELECT DISTINCT s.shipment_key, o.customer_key
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SHIPMENTS s
JOIN SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SALES_ORDERS o ON s.order_key = o.order_key;

CREATE OR REPLACE SECURE VIEW REL_SHIPMENT_CARRIER AS
SELECT DISTINCT shipment_key, carrier_key FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SHIPMENTS;

-- Hierarchy Views (3)
CREATE OR REPLACE SECURE VIEW HIER_SUPPLIER_REGION AS
SELECT supplier_key, company_name, supplier_group, region FROM SUPPLY_CHAIN_HUB.SC_CURATED.DIM_SUPPLIER;

CREATE OR REPLACE SECURE VIEW HIER_PLANT_REGION AS
SELECT plant_key, plant_code, plant_name, country_code, region FROM SUPPLY_CHAIN_HUB.SC_CURATED.DIM_PLANT;

CREATE OR REPLACE SECURE VIEW HIER_PART_CATEGORY AS
SELECT part_key, erp_material_nbr, material_desc, material_group, material_type
FROM SUPPLY_CHAIN_HUB.SC_CURATED.DIM_PART;
