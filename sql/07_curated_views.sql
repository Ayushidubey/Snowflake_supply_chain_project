-- =============================================================================
-- PHASE 7: Curated Views (11 secure views)
-- =============================================================================

USE SCHEMA SUPPLY_CHAIN_HUB.SC_CURATED;

CREATE OR REPLACE SECURE VIEW DIM_SUPPLIER AS
SELECT x.canonical_supplier_id AS supplier_key, x.erp_vendor_code, x.suppliernet_uuid, x.company_name,
  s.RAW_PAYLOAD:country::VARCHAR AS country, s.RAW_PAYLOAD:region::VARCHAR AS region,
  s.RAW_PAYLOAD:supplier_group::VARCHAR AS supplier_group, s.RAW_PAYLOAD:quality_rating::FLOAT AS quality_rating,
  s.RAW_PAYLOAD:currency_code::VARCHAR AS currency_code, s.RAW_PAYLOAD:payment_terms_days::INT AS payment_terms_days,
  s.RAW_PAYLOAD:is_active::BOOLEAN AS is_active, TRY_TO_TIMESTAMP(s.RAW_PAYLOAD:onboarded_date::VARCHAR) AS onboarded_date,
  s._LOAD_BATCH_ID, s._SOURCE_FILE
FROM SUPPLY_CHAIN_HUB.SC_RAW.SUP_SUPPLIERS s
JOIN SUPPLY_CHAIN_HUB.SC_CURATED.XREF_SUPPLIER x ON s.RAW_PAYLOAD:supplier_id::VARCHAR = x.suppliernet_uuid;

CREATE OR REPLACE SECURE VIEW DIM_PART AS
SELECT x.canonical_part_id AS part_key, m.MATERIAL_NBR AS erp_material_nbr, x.suppliernet_part_number,
  m.MATERIAL_DESC AS material_desc, m.MATERIAL_TYPE AS material_type, m.MATERIAL_GROUP AS material_group,
  m.BASE_UOM AS base_uom, m.GROSS_WEIGHT AS gross_weight_kg, m.STANDARD_COST AS standard_cost_usd,
  m._LOAD_BATCH_ID, m._SOURCE_FILE
FROM SUPPLY_CHAIN_HUB.SC_RAW.ERP_MATERIAL_MASTER m
JOIN SUPPLY_CHAIN_HUB.SC_CURATED.XREF_PART x ON m.MATERIAL_NBR = x.erp_material_nbr;

CREATE OR REPLACE SECURE VIEW DIM_PLANT AS
SELECT x.canonical_plant_id AS plant_key, p.PLANT_CODE AS plant_code, p.PLANT_NAME AS plant_name,
  x.freightlink_facility_name, p.COUNTRY_CODE AS country_code, p.REGION AS region,
  p.CITY AS city, p.PLANT_TYPE AS plant_type, p._LOAD_BATCH_ID, p._SOURCE_FILE
FROM SUPPLY_CHAIN_HUB.SC_RAW.ERP_PLANT_MASTER p
JOIN SUPPLY_CHAIN_HUB.SC_CURATED.XREF_PLANT x ON p.PLANT_CODE = x.erp_plant_code;

CREATE OR REPLACE SECURE VIEW DIM_CUSTOMER AS
SELECT DISTINCT CUST_NBR AS customer_key, CUST_NBR AS cust_nbr
FROM SUPPLY_CHAIN_HUB.SC_RAW.ERP_SALES_ORDERS;

CREATE OR REPLACE SECURE VIEW DIM_CARRIER AS
SELECT CARRIER_ID AS carrier_key, CARRIER_NAME AS carrier_name, CARRIER_TYPE AS carrier_type,
  COUNTRY_BASE AS country_base, REGION_COVERAGE AS region_coverage, RELIABILITY_SCORE AS reliability_score,
  _LOAD_BATCH_ID, _SOURCE_FILE
FROM SUPPLY_CHAIN_HUB.SC_RAW.TMS_CARRIER_MASTER;

CREATE OR REPLACE SECURE VIEW FACT_SALES_ORDERS AS
SELECT ORDER_NBR AS order_key, PLANT_CODE AS plant_code, CUST_NBR AS customer_key,
  TO_DATE(TO_CHAR(ORDER_DATE), 'YYYYMMDD') AS order_date,
  TO_DATE(TO_CHAR(PROMISED_DATE), 'YYYYMMDD') AS promised_date,
  ORDER_STATUS AS order_status, ORDER_TOTAL_USD AS order_total_usd,
  SALES_ORG AS sales_org, DIST_CHANNEL AS dist_channel,
  (ORDER_STATUS = 'CN') AS is_cancelled, (ORDER_STATUS = 'CL') AS is_closed,
  _LOAD_BATCH_ID, _SOURCE_FILE, _SOURCE_ROW_NUMBER
FROM SUPPLY_CHAIN_HUB.SC_RAW.ERP_SALES_ORDERS;

CREATE OR REPLACE SECURE VIEW FACT_ORDER_LINES AS
SELECT ol.ORDER_NBR AS order_key, ol.LINE_NBR AS line_nbr, x.canonical_part_id AS part_key,
  ol.MATERIAL_NBR AS erp_material_nbr, ol.QUANTITY_ORDERED AS quantity_ordered,
  ol.QUANTITY_DELIVERED AS quantity_delivered, ol.UOM AS uom_source, ol.UOM AS uom_canonical,
  ol.UNIT_PRICE_USD AS unit_price_usd, ol.LINE_STATUS AS line_status,
  TO_DATE(TO_CHAR(ol.PROMISED_DATE), 'YYYYMMDD') AS promised_date,
  (ol.QUANTITY_DELIVERED >= ol.QUANTITY_ORDERED AND ol.LINE_STATUS = 'DL') AS is_full_fill,
  CASE WHEN ol.QUANTITY_ORDERED > 0 THEN ol.QUANTITY_DELIVERED / ol.QUANTITY_ORDERED ELSE NULL END AS fill_ratio,
  (ol.LINE_STATUS = 'CN') AS is_cancelled, (ol.LINE_STATUS = 'DL') AS is_delivered,
  ol._LOAD_BATCH_ID, ol._SOURCE_FILE, ol._SOURCE_ROW_NUMBER
FROM SUPPLY_CHAIN_HUB.SC_RAW.ERP_ORDER_LINES ol
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.XREF_PART x ON ol.MATERIAL_NBR = x.erp_material_nbr;

CREATE OR REPLACE SECURE VIEW FACT_SHIPMENTS AS
SELECT s.SHIPMENT_ID AS shipment_key, s.ORDER_REF AS order_key, s.CARRIER_ID AS carrier_key,
  x.canonical_plant_id AS plant_key, s.ORIGIN_FACILITY AS origin_facility, s.DESTINATION AS destination,
  TRY_TO_DATE(s.SHIP_DATE, 'MM/DD/YYYY') AS ship_date,
  TRY_TO_DATE(s.PROMISED_DELIVERY, 'MM/DD/YYYY') AS promised_delivery_date,
  TRY_TO_DATE(NULLIF(s.ACTUAL_DELIVERY, ''), 'MM/DD/YYYY') AS actual_delivery_date,
  s.WEIGHT_KGS AS weight_kgs, s.PIECES AS pieces, s.STATUS AS status, s.DAMAGE_FLAG AS damage_flag,
  (s.STATUS = 'DELIVERED') AS is_delivered,
  CASE WHEN s.STATUS = 'DELIVERED' AND NULLIF(s.ACTUAL_DELIVERY, '') IS NOT NULL
    THEN TRY_TO_DATE(s.ACTUAL_DELIVERY, 'MM/DD/YYYY') <= TRY_TO_DATE(s.PROMISED_DELIVERY, 'MM/DD/YYYY')
    ELSE NULL END AS is_on_time,
  (s.DAMAGE_FLAG = 'Y') AS is_damaged,
  CASE WHEN s.STATUS = 'DELIVERED' AND NULLIF(s.ACTUAL_DELIVERY, '') IS NOT NULL
    THEN DATEDIFF('day', TRY_TO_DATE(s.PROMISED_DELIVERY, 'MM/DD/YYYY'), TRY_TO_DATE(s.ACTUAL_DELIVERY, 'MM/DD/YYYY'))
    ELSE NULL END AS days_late,
  s._LOAD_BATCH_ID, s._SOURCE_FILE, s._SOURCE_ROW_NUMBER
FROM SUPPLY_CHAIN_HUB.SC_RAW.TMS_SHIPMENTS_MASTER s
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.XREF_PLANT x ON s.ORIGIN_FACILITY = x.freightlink_facility_name;

CREATE OR REPLACE SECURE VIEW FACT_SHIPMENT_EVENTS AS
SELECT RAW_PAYLOAD:event_id::VARCHAR AS event_id, RAW_PAYLOAD:shipment_id::VARCHAR AS shipment_key,
  RAW_PAYLOAD:event_type::VARCHAR AS event_type,
  TO_TIMESTAMP(RAW_PAYLOAD:event_timestamp::INT) AS event_timestamp,
  RAW_PAYLOAD:location::VARCHAR AS location, RAW_PAYLOAD:carrier_id::VARCHAR AS carrier_key,
  RAW_PAYLOAD:notes::VARCHAR AS notes,
  CASE WHEN ROW_NUMBER() OVER (PARTITION BY RAW_PAYLOAD:event_id::VARCHAR ORDER BY _SOURCE_ROW_NUMBER ASC) > 1
    THEN TRUE ELSE FALSE END AS is_duplicate_event,
  RAW_PAYLOAD:event_id::VARCHAR AS duplicate_group_id,
  ROW_NUMBER() OVER (PARTITION BY RAW_PAYLOAD:event_id::VARCHAR ORDER BY _SOURCE_ROW_NUMBER ASC) AS event_sequence,
  _LOAD_BATCH_ID, _SOURCE_FILE, _SOURCE_ROW_NUMBER
FROM SUPPLY_CHAIN_HUB.SC_RAW.TMS_SHIPMENT_EVENTS;

CREATE OR REPLACE SECURE VIEW FACT_INVENTORY AS
SELECT inv.PLANT_CODE AS plant_code, x.canonical_part_id AS part_key,
  inv.MATERIAL_NBR AS erp_material_nbr,
  TO_DATE(TO_CHAR(inv.SNAPSHOT_DATE), 'YYYYMMDD') AS snapshot_date,
  inv.QTY_ON_HAND AS qty_on_hand, inv.QTY_IN_TRANSIT AS qty_in_transit,
  inv.QTY_RESERVED AS qty_reserved, (inv.QTY_ON_HAND - inv.QTY_RESERVED) AS qty_available,
  inv.UOM AS uom, inv.VALUATION_USD AS valuation_usd,
  inv._LOAD_BATCH_ID, inv._SOURCE_FILE, inv._SOURCE_ROW_NUMBER
FROM SUPPLY_CHAIN_HUB.SC_RAW.ERP_INVENTORY_SNAPSHOTS inv
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.XREF_PART x ON inv.MATERIAL_NBR = x.erp_material_nbr;

CREATE OR REPLACE SECURE VIEW FACT_PURCHASE_RECEIPTS AS
SELECT r.RAW_PAYLOAD:receipt_id::VARCHAR AS receipt_id, r.RAW_PAYLOAD:po_id::VARCHAR AS po_id,
  xs.canonical_supplier_id AS supplier_key, xp.canonical_part_id AS part_key,
  r.RAW_PAYLOAD:supplier_id::VARCHAR AS suppliernet_supplier_id,
  r.RAW_PAYLOAD:part_number::VARCHAR AS suppliernet_part_number,
  po.RAW_PAYLOAD:quantity_ordered::INT AS quantity_ordered,
  r.RAW_PAYLOAD:quantity_received::INT AS quantity_received,
  r.RAW_PAYLOAD:unit::VARCHAR AS uom_source,
  CASE r.RAW_PAYLOAD:unit::VARCHAR WHEN 'each' THEN 'EA' WHEN 'kilogram' THEN 'KG' WHEN 'liter' THEN 'L'
    ELSE r.RAW_PAYLOAD:unit::VARCHAR END AS uom_canonical,
  po.RAW_PAYLOAD:unit_price::FLOAT AS unit_price, po.RAW_PAYLOAD:currency_code::VARCHAR AS currency_code,
  TRY_TO_TIMESTAMP(po.RAW_PAYLOAD:order_date::VARCHAR) AS order_date,
  TRY_TO_TIMESTAMP(po.RAW_PAYLOAD:expected_delivery_date::VARCHAR) AS expected_delivery_date,
  TRY_TO_TIMESTAMP(r.RAW_PAYLOAD:receipt_date::VARCHAR) AS receipt_date,
  r.RAW_PAYLOAD:quality_check_passed::BOOLEAN AS quality_check_passed,
  r.RAW_PAYLOAD:defect_count::INT AS defect_count,
  r.RAW_PAYLOAD:receiving_plant::VARCHAR AS receiving_plant_code,
  r.RAW_PAYLOAD:batch_number::VARCHAR AS batch_number,
  CASE WHEN TRY_TO_TIMESTAMP(r.RAW_PAYLOAD:receipt_date::VARCHAR) <= TRY_TO_TIMESTAMP(po.RAW_PAYLOAD:expected_delivery_date::VARCHAR)
    THEN TRUE ELSE FALSE END AS is_on_time,
  CASE WHEN r.RAW_PAYLOAD:quantity_received::INT >= po.RAW_PAYLOAD:quantity_ordered::INT
    THEN TRUE ELSE FALSE END AS is_complete,
  CASE WHEN po.RAW_PAYLOAD:quantity_ordered::INT > 0
    THEN r.RAW_PAYLOAD:quantity_received::FLOAT / po.RAW_PAYLOAD:quantity_ordered::FLOAT ELSE NULL END AS fill_ratio,
  r._LOAD_BATCH_ID, r._SOURCE_FILE, r._SOURCE_ROW_NUMBER
FROM SUPPLY_CHAIN_HUB.SC_RAW.SUP_RECEIPTS r
LEFT JOIN SUPPLY_CHAIN_HUB.SC_RAW.SUP_PURCHASE_ORDERS po ON r.RAW_PAYLOAD:po_id::VARCHAR = po.RAW_PAYLOAD:po_id::VARCHAR
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.XREF_SUPPLIER xs ON r.RAW_PAYLOAD:supplier_id::VARCHAR = xs.suppliernet_uuid
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.XREF_PART xp ON r.RAW_PAYLOAD:part_number::VARCHAR = xp.suppliernet_part_number;
