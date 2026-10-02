-- =============================================================================
-- PHASE 4: Upload Data Files (PUT)
-- Run from SnowSQL or Snowflake client with access to local filesystem
-- Replace <DATA_DIR> with your actual path to the data directory
-- =============================================================================

-- SET DATA_DIR = 'C:\Users\adubey01\AppData\Local\Temp\...\data';

USE SCHEMA SUPPLY_CHAIN_HUB.SC_STAGES;

PUT 'file://<DATA_DIR>/ERP/erp_sales_orders.csv'       @STG_ERP/orders/           AUTO_COMPRESS=TRUE  OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/ERP/erp_order_lines.csv'         @STG_ERP/order_lines/      AUTO_COMPRESS=TRUE  OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/ERP/erp_inventory_snapshots.parquet' @STG_ERP/inventory/    AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/ERP/erp_material_master.csv'     @STG_ERP/materials/        AUTO_COMPRESS=TRUE  OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/ERP/erp_plant_master.csv'        @STG_ERP/plants/           AUTO_COMPRESS=TRUE  OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/SUPPLIER/sup_suppliers.json'     @STG_SUPPLIER/suppliers/   AUTO_COMPRESS=TRUE  OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/SUPPLIER/sup_purchase_orders.json' @STG_SUPPLIER/purchase_orders/ AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/SUPPLIER/sup_receipts.json'      @STG_SUPPLIER/receipts/    AUTO_COMPRESS=TRUE  OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/FREIGHT/tms_shipments_master.csv' @STG_FREIGHT/shipments_master/ AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/FREIGHT/tms_carrier_master.csv'  @STG_FREIGHT/carrier_master/ AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/FREIGHT/tms_shipment_events.json' @STG_FREIGHT/events/      AUTO_COMPRESS=TRUE  OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/PLANT/iot_sensor_readings.json'  @STG_PLANT/sensor_readings/ AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/PLANT/iot_quality_events.json'   @STG_PLANT/quality_events/ AUTO_COMPRESS=TRUE  OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/FINANCE/fin_cost_allocations.csv' @STG_FINANCE/cost_allocations/ AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/FINANCE/fin_exchange_rates.csv'  @STG_FINANCE/exchange_rates/ AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/FINANCE/fin_tariffs.csv'         @STG_FINANCE/tariffs/      AUTO_COMPRESS=TRUE  OVERWRITE=TRUE;
PUT 'file://<DATA_DIR>/_xref_identity_map.json'         @STG_ERP/xref/             AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
