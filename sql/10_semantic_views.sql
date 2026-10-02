-- =============================================================================
-- PHASE 10: Semantic Layer (7 views)
-- =============================================================================

USE SCHEMA SUPPLY_CHAIN_HUB.SC_SEM;

CREATE OR REPLACE SECURE VIEW SEM_DELIVERY AS
SELECT
  s.shipment_key, s.order_key, s.carrier_key,
  c.carrier_name, s.plant_key, p.plant_name, p.plant_code,
  p.region AS plant_region, p.country_code,
  s.origin_facility, s.destination, s.ship_date,
  s.promised_delivery_date, s.actual_delivery_date,
  s.weight_kgs, s.pieces, s.status,
  s.is_delivered, s.is_on_time, s.is_damaged, s.days_late,
  DATEDIFF('day', s.ship_date, s.actual_delivery_date) AS transit_days
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SHIPMENTS s
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.DIM_CARRIER c ON s.carrier_key = c.carrier_key
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.DIM_PLANT p ON s.plant_key = p.plant_key;

CREATE OR REPLACE SECURE VIEW SEM_FULFILLMENT AS
SELECT
  ol.order_key, ol.line_nbr, ol.part_key, dp.material_desc, dp.material_group,
  ol.erp_material_nbr, ol.quantity_ordered, ol.quantity_delivered,
  ol.uom_canonical, ol.unit_price_usd, ol.line_status, ol.promised_date,
  ol.is_full_fill, ol.fill_ratio, ol.is_cancelled, ol.is_delivered,
  so.plant_code, so.customer_key, so.order_date, so.order_status,
  so.order_total_usd, pl.plant_name, pl.region AS plant_region
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_ORDER_LINES ol
JOIN SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SALES_ORDERS so ON ol.order_key = so.order_key
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.DIM_PART dp ON ol.part_key = dp.part_key
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.DIM_PLANT pl ON so.plant_code = pl.plant_code;

CREATE OR REPLACE SECURE VIEW SEM_INVENTORY AS
SELECT
  inv.plant_code, pl.plant_name, pl.region AS plant_region, pl.country_code,
  inv.part_key, inv.erp_material_nbr, dp.material_desc, dp.material_group,
  dp.material_type, dp.standard_cost_usd, inv.snapshot_date,
  inv.qty_on_hand, inv.qty_in_transit, inv.qty_reserved, inv.qty_available,
  inv.uom, inv.valuation_usd
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_INVENTORY inv
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.DIM_PLANT pl ON inv.plant_code = pl.plant_code
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.DIM_PART dp ON inv.part_key = dp.part_key;

CREATE OR REPLACE SECURE VIEW SEM_PROCUREMENT AS
SELECT
  pr.receipt_id, pr.po_id, pr.supplier_key,
  ds.company_name AS supplier_name, ds.supplier_group,
  ds.country AS supplier_country, ds.region AS supplier_region,
  ds.quality_rating AS supplier_quality_rating,
  pr.part_key, dp.material_desc, dp.material_group, dp.standard_cost_usd,
  pr.quantity_ordered, pr.quantity_received, pr.uom_canonical,
  pr.unit_price, pr.currency_code, pr.order_date, pr.expected_delivery_date,
  pr.receipt_date, pr.quality_check_passed, pr.defect_count,
  pr.receiving_plant_code, pr.batch_number,
  pr.is_on_time, pr.is_complete, pr.fill_ratio,
  DATEDIFF('day', pr.order_date, pr.receipt_date) AS lead_time_days
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_PURCHASE_RECEIPTS pr
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.DIM_SUPPLIER ds ON pr.supplier_key = ds.supplier_key
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.DIM_PART dp ON pr.part_key = dp.part_key;

CREATE OR REPLACE SECURE VIEW SEM_COST AS
SELECT
  ca.ALLOCATION_ID, ca.VENDOR_CODE,
  ds.company_name AS supplier_name, ca.COST_CENTER_ID,
  ca.MATERIAL_NBR, dp.material_desc, ca.COST_TYPE,
  ca.AMOUNT, ca.FROM_CURRENCY, ca.TO_CURRENCY, ca.EXCHANGE_RATE,
  ca.AMOUNT_USD, ca.EFFECTIVE_DATE, ca.SHIPMENT_REF,
  sh.weight_kgs AS shipment_weight_kgs, sh.pieces AS shipment_pieces,
  sh.carrier_key, sh.plant_key
FROM SUPPLY_CHAIN_HUB.SC_RAW.FIN_COST_ALLOCATIONS ca
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.XREF_SUPPLIER xs ON ca.VENDOR_CODE = xs.erp_vendor_code
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.DIM_SUPPLIER ds ON xs.canonical_supplier_id = ds.supplier_key
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.DIM_PART dp ON ca.MATERIAL_NBR = dp.erp_material_nbr
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SHIPMENTS sh ON ca.SHIPMENT_REF = sh.shipment_key;

CREATE OR REPLACE SECURE VIEW SEM_QUALITY AS
SELECT
  pr.receipt_id, pr.po_id, pr.supplier_key,
  ds.company_name AS supplier_name, ds.supplier_group,
  pr.part_key, dp.material_desc, dp.material_group,
  pr.quantity_received, pr.quality_check_passed, pr.defect_count,
  pr.receiving_plant_code, pr.receipt_date, pr.is_on_time, pr.is_complete,
  CASE WHEN pr.quantity_received > 0 THEN pr.defect_count::FLOAT / pr.quantity_received * 1000000 ELSE 0 END AS defect_ppm
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_PURCHASE_RECEIPTS pr
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.DIM_SUPPLIER ds ON pr.supplier_key = ds.supplier_key
LEFT JOIN SUPPLY_CHAIN_HUB.SC_CURATED.DIM_PART dp ON pr.part_key = dp.part_key;

CREATE OR REPLACE SECURE VIEW SEM_KPI_SUMMARY AS
-- OTD
SELECT 'KPI-OTD-001' AS KPI_ID, 'On-Time Delivery %' AS KPI_NAME,
  SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END)::FLOAT / NULLIF(SUM(CASE WHEN is_delivered THEN 1 ELSE 0 END), 0) * 100 AS KPI_VALUE,
  '%' AS UNIT
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SHIPMENTS
UNION ALL
-- Fill Rate
SELECT 'KPI-FR-001', 'Fill Rate %',
  SUM(CASE WHEN is_full_fill THEN 1 ELSE 0 END)::FLOAT / NULLIF(SUM(CASE WHEN is_delivered THEN 1 ELSE 0 END), 0) * 100, '%'
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_ORDER_LINES
UNION ALL
-- OTIF
SELECT 'KPI-OTIF-001', 'OTIF %',
  SUM(CASE WHEN all_lines_full AND all_shipments_on_time THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*), 0) * 100, '%'
FROM (
  SELECT o.order_key,
    MIN(CASE WHEN ol.is_full_fill THEN 1 ELSE 0 END) = 1 AS all_lines_full,
    MIN(CASE WHEN s.is_on_time THEN 1 ELSE 0 END) = 1 AS all_shipments_on_time
  FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SALES_ORDERS o
  JOIN SUPPLY_CHAIN_HUB.SC_CURATED.FACT_ORDER_LINES ol ON o.order_key = ol.order_key
  JOIN SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SHIPMENTS s ON o.order_key = s.order_key
  WHERE o.is_closed AND ol.is_delivered AND s.is_delivered
  GROUP BY o.order_key
)
UNION ALL
-- Perfect Order Rate
SELECT 'KPI-POR-001', 'Perfect Order Rate %',
  SUM(CASE WHEN all_lines_full AND all_shipments_on_time AND no_damage THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*), 0) * 100, '%'
FROM (
  SELECT o.order_key,
    MIN(CASE WHEN ol.is_full_fill THEN 1 ELSE 0 END) = 1 AS all_lines_full,
    MIN(CASE WHEN s.is_on_time THEN 1 ELSE 0 END) = 1 AS all_shipments_on_time,
    MAX(CASE WHEN s.is_damaged THEN 1 ELSE 0 END) = 0 AS no_damage
  FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SALES_ORDERS o
  JOIN SUPPLY_CHAIN_HUB.SC_CURATED.FACT_ORDER_LINES ol ON o.order_key = ol.order_key
  JOIN SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SHIPMENTS s ON o.order_key = s.order_key
  WHERE o.is_closed AND ol.is_delivered AND s.is_delivered
  GROUP BY o.order_key
)
UNION ALL
-- DOI
SELECT 'KPI-DOI-001', 'Days of Inventory', AVG(doi), 'Days'
FROM (
  SELECT inv.erp_material_nbr, inv.plant_code,
    AVG(inv.qty_on_hand) AS avg_on_hand,
    AVG(inv.qty_on_hand) / NULLIF(demand.avg_daily_demand, 0) AS doi
  FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_INVENTORY inv
  JOIN (
    SELECT ol.erp_material_nbr,
      SUM(ol.quantity_ordered) / NULLIF(DATEDIFF('day', MIN(so.order_date), MAX(so.order_date)), 0) AS avg_daily_demand
    FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_ORDER_LINES ol
    JOIN SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SALES_ORDERS so ON ol.order_key = so.order_key
    GROUP BY ol.erp_material_nbr
  ) demand ON inv.erp_material_nbr = demand.erp_material_nbr
  GROUP BY inv.erp_material_nbr, inv.plant_code, demand.avg_daily_demand
)
UNION ALL
-- Supplier On-Time
SELECT 'KPI-SOT-001', 'Supplier On-Time %',
  SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*), 0) * 100, '%'
FROM SUPPLY_CHAIN_HUB.SC_CURATED.FACT_PURCHASE_RECEIPTS
UNION ALL
-- Landed Cost
SELECT 'KPI-LC-001', 'Landed Cost per Unit',
  SUM(ca.AMOUNT_USD) / NULLIF(SUM(s.pieces), 0), '$/unit'
FROM SUPPLY_CHAIN_HUB.SC_RAW.FIN_COST_ALLOCATIONS ca
JOIN SUPPLY_CHAIN_HUB.SC_CURATED.FACT_SHIPMENTS s ON ca.SHIPMENT_REF = s.shipment_key;

-- VALIDATE (after data is loaded):
-- SELECT KPI_ID, KPI_NAME, ROUND(KPI_VALUE, 2) AS KPI_VALUE, UNIT
-- FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_KPI_SUMMARY ORDER BY KPI_ID;
