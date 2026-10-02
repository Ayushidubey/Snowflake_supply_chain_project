-- =============================================================================
-- PHASE 9: KPI Registry (24 KPIs)
-- =============================================================================

USE SCHEMA SUPPLY_CHAIN_HUB.SC_ONT;

CREATE OR REPLACE TABLE KPI_REGISTRY (
  KPI_ID VARCHAR(20) NOT NULL,
  KPI_NAME VARCHAR(100) NOT NULL,
  DOMAIN VARCHAR(30) NOT NULL,
  TIER NUMBER(38,0) NOT NULL,
  BUSINESS_DEFINITION VARCHAR(2000) NOT NULL,
  FORMULA_SQL VARCHAR(4000),
  NUMERATOR_DESC VARCHAR(500),
  DENOMINATOR_DESC VARCHAR(500),
  GRAIN VARCHAR(100) NOT NULL,
  UNIT VARCHAR(20) NOT NULL,
  OWNER_PERSONA VARCHAR(30) NOT NULL,
  ALLOWED_DIMENSIONS VARIANT,
  ALLOWED_FILTERS VARIANT,
  SOURCE_ENTITIES VARIANT,
  SEMANTIC_VIEW_REF VARCHAR(200),
  REFRESH_SLA_MINUTES NUMBER(38,0),
  VERSION VARCHAR(10) NOT NULL DEFAULT '1.0.0',
  STATUS VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
  EFFECTIVE_FROM TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
  CREATED_BY VARCHAR(50) DEFAULT CURRENT_USER(),
  LAST_VALIDATED_AT TIMESTAMP_NTZ(9),
  CONSTRAINT CHK_TIER CHECK (TIER IN (1, 2)),
  CONSTRAINT CHK_STATUS CHECK (STATUS IN ('ACTIVE', 'DRAFT', 'DEPRECATED')),
  CONSTRAINT PK_KPI PRIMARY KEY (KPI_ID)
) COMMENT='Governed KPI registry - canonical definitions for all supply chain metrics';

-- Tier-1 KPIs (7)
INSERT INTO KPI_REGISTRY (KPI_ID,KPI_NAME,DOMAIN,TIER,BUSINESS_DEFINITION,FORMULA_SQL,NUMERATOR_DESC,DENOMINATOR_DESC,GRAIN,UNIT,OWNER_PERSONA,ALLOWED_DIMENSIONS,ALLOWED_FILTERS,SOURCE_ENTITIES,REFRESH_SLA_MINUTES)
SELECT 'KPI-OTD-001','On-Time Delivery %','Delivery',1,'Percentage of delivered shipments where actual delivery date is on or before promised delivery date','SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END)::FLOAT / NULLIF(SUM(CASE WHEN is_delivered THEN 1 ELSE 0 END),0) * 100','Shipments delivered on or before promised date','All delivered shipments','Shipment','%','Logistics',PARSE_JSON('["region","plant","carrier","period"]'),PARSE_JSON('["date_range","region","plant","carrier"]'),PARSE_JSON('["ONT_SHIPMENT"]'),60
UNION ALL SELECT 'KPI-FR-001','Fill Rate %','Planning',1,'Percentage of delivered order lines where quantity delivered >= quantity ordered','SUM(CASE WHEN is_full_fill THEN 1 ELSE 0 END)::FLOAT / NULLIF(SUM(CASE WHEN is_delivered THEN 1 ELSE 0 END),0) * 100','Lines shipped complete','All delivered order lines','Order Line','%','Planning',PARSE_JSON('["region","plant","part","period"]'),PARSE_JSON('["date_range","region","plant"]'),PARSE_JSON('["ONT_ORDER_LINE"]'),60
UNION ALL SELECT 'KPI-OTIF-001','OTIF %','Delivery',1,'Percentage of orders where ALL lines in-full AND ALL shipments on-time','COUNT(orders_full_and_on_time) / COUNT(eligible) * 100','Orders meeting both in-full and on-time','All eligible closed orders','Order','%','Logistics',PARSE_JSON('["region","plant","customer","period"]'),PARSE_JSON('["date_range","region","plant"]'),PARSE_JSON('["ONT_SALES_ORDER","ONT_ORDER_LINE","ONT_SHIPMENT"]'),60
UNION ALL SELECT 'KPI-POR-001','Perfect Order Rate %','Delivery',1,'Percentage of orders on-time, in-full, undamaged','COUNT(perfect_orders) / COUNT(eligible) * 100','Orders on-time AND full AND undamaged','All eligible closed orders','Order','%','Logistics',PARSE_JSON('["region","plant","carrier","customer","period"]'),PARSE_JSON('["date_range","region","plant","carrier"]'),PARSE_JSON('["ONT_SALES_ORDER","ONT_ORDER_LINE","ONT_SHIPMENT"]'),60
UNION ALL SELECT 'KPI-DOI-001','Days of Inventory','Planning',1,'Average days current on-hand inventory would last given average daily demand','AVG(qty_on_hand) / NULLIF(AVG_DAILY_DEMAND,0)','Average on-hand quantity','Average daily demand','Plant x Part','Days','Planning',PARSE_JSON('["plant","part","material_group","period"]'),PARSE_JSON('["date_range","plant","material_group"]'),PARSE_JSON('["ONT_INVENTORY_POSITION","ONT_ORDER_LINE"]'),1440
UNION ALL SELECT 'KPI-SOT-001','Supplier On-Time %','Procurement',1,'Percentage of receipts where receipt date <= PO expected delivery date','SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*),0) * 100','Receipts on or before expected date','All receipts','Receipt','%','Procurement',PARSE_JSON('["supplier","supplier_group","part","region","period"]'),PARSE_JSON('["date_range","supplier","region"]'),PARSE_JSON('["ONT_PURCHASE_RECEIPT"]'),60
UNION ALL SELECT 'KPI-LC-001','Landed Cost per Unit','Cost',1,'Total cost (product+freight+duty+handling) divided by units shipped in USD','SUM(amount_usd) / NULLIF(SUM(pieces),0)','Sum of all cost types in USD','Total pieces shipped','Shipment','$/unit','Procurement',PARSE_JSON('["supplier","plant","carrier","period"]'),PARSE_JSON('["date_range","supplier","plant"]'),PARSE_JSON('["ONT_SHIPMENT","FIN_COST_ALLOCATIONS"]'),1440;

-- Tier-2 KPIs (17)
INSERT INTO KPI_REGISTRY (KPI_ID,KPI_NAME,DOMAIN,TIER,BUSINESS_DEFINITION,FORMULA_SQL,NUMERATOR_DESC,DENOMINATOR_DESC,GRAIN,UNIT,OWNER_PERSONA,ALLOWED_DIMENSIONS,ALLOWED_FILTERS,SOURCE_ENTITIES,REFRESH_SLA_MINUTES)
SELECT 'KPI-CD-001','Carrier Damage Rate %','Logistics',2,'Percentage of shipments by carrier that have damage flag','SUM(CASE WHEN is_damaged THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*),0)*100','Damaged shipments','All shipments by carrier','Carrier','%','Logistics',PARSE_JSON('["carrier","region","period"]'),PARSE_JSON('["date_range","carrier"]'),PARSE_JSON('["ONT_SHIPMENT"]'),60
UNION ALL SELECT 'KPI-TT-001','Transit Time','Logistics',2,'Average days between ship date and actual delivery date','AVG(DATEDIFF(day,ship_date,actual_delivery_date))','Sum of transit days','Count of delivered shipments','Shipment','Days','Logistics',PARSE_JSON('["carrier","plant","region","period"]'),PARSE_JSON('["date_range","carrier","region"]'),PARSE_JSON('["ONT_SHIPMENT"]'),60
UNION ALL SELECT 'KPI-FC-001','Freight Cost per kg','Logistics',2,'Average freight cost per kilogram shipped','SUM(freight_cost_usd)/NULLIF(SUM(weight_kgs),0)','Total freight cost','Total weight shipped','Shipment','$/kg','Logistics',PARSE_JSON('["carrier","plant","region","period"]'),PARSE_JSON('["date_range","carrier","region"]'),PARSE_JSON('["ONT_SHIPMENT","FIN_COST_ALLOCATIONS"]'),1440
UNION ALL SELECT 'KPI-OCT-001','Order Cycle Time','Delivery',2,'Average days from order placement to actual delivery','AVG(DATEDIFF(day,order_date,actual_delivery_date))','Sum of cycle days','Count of completed orders','Order','Days','Logistics',PARSE_JSON('["plant","region","period"]'),PARSE_JSON('["date_range","plant","region"]'),PARSE_JSON('["ONT_SALES_ORDER","ONT_SHIPMENT"]'),60
UNION ALL SELECT 'KPI-BO-001','Backorder Rate %','Planning',2,'Percentage of order lines currently open/unfulfilled','COUNT(open_lines)/COUNT(all_lines)*100','Open order lines','All order lines','Order Line','%','Planning',PARSE_JSON('["plant","part","period"]'),PARSE_JSON('["date_range","plant"]'),PARSE_JSON('["ONT_ORDER_LINE"]'),60
UNION ALL SELECT 'KPI-SO-001','Stockout Rate %','Planning',2,'Percentage of plant-part-days where on-hand inventory is zero','COUNT(zero_stock_days)/COUNT(all_days)*100','Days with zero on-hand','All tracked days','Plant x Part','%','Planning',PARSE_JSON('["plant","part","period"]'),PARSE_JSON('["date_range","plant"]'),PARSE_JSON('["ONT_INVENTORY_POSITION"]'),1440
UNION ALL SELECT 'KPI-IT-001','Inventory Turnover','Planning',2,'Ratio of cost of goods sold to average inventory value','SUM(cogs)/NULLIF(AVG(valuation_usd),0)','Cost of goods sold','Average inventory value','Plant x Part','Ratio','Planning',PARSE_JSON('["plant","part","period"]'),PARSE_JSON('["date_range","plant"]'),PARSE_JSON('["ONT_INVENTORY_POSITION"]'),1440
UNION ALL SELECT 'KPI-QD-001','Quality Defect Rate','Quality',2,'Defect count per 1M units received (PPM)','SUM(defect_count)/NULLIF(SUM(quantity_received),0)*1000000','Total defects found','Total units received','Supplier x Part','PPM','Quality',PARSE_JSON('["supplier","part","plant","period"]'),PARSE_JSON('["date_range","supplier","plant"]'),PARSE_JSON('["ONT_PURCHASE_RECEIPT"]'),60
UNION ALL SELECT 'KPI-QI-001','Quality Inspection Pass Rate','Quality',2,'Percentage of receipts passing quality check','SUM(CASE WHEN quality_check_passed THEN 1 ELSE 0 END)::FLOAT/NULLIF(COUNT(*),0)*100','Receipts passing QC','All receipts inspected','Receipt','%','Quality',PARSE_JSON('["supplier","part","plant","period"]'),PARSE_JSON('["date_range","supplier","plant"]'),PARSE_JSON('["ONT_PURCHASE_RECEIPT"]'),60
UNION ALL SELECT 'KPI-PPV-001','Purchase Price Variance','Procurement',2,'Percentage deviation of actual purchase price vs standard cost','AVG((unit_price-standard_cost_usd)/NULLIF(standard_cost_usd,0)*100)','Actual-standard delta','Standard cost baseline','Part x Supplier','%','Procurement',PARSE_JSON('["supplier","part","period"]'),PARSE_JSON('["date_range","supplier"]'),PARSE_JSON('["ONT_PURCHASE_RECEIPT","ONT_PART"]'),1440
UNION ALL SELECT 'KPI-SLT-001','Supplier Lead Time','Procurement',2,'Average days from PO creation to receipt','AVG(DATEDIFF(day,order_date,receipt_date))','Total lead time days','Count of receipts','Supplier','Days','Procurement',PARSE_JSON('["supplier","part","region","period"]'),PARSE_JSON('["date_range","supplier","region"]'),PARSE_JSON('["ONT_PURCHASE_RECEIPT"]'),60
UNION ALL SELECT 'KPI-CU-001','Capacity Utilization','Operations',2,'Average sensor reading as percentage of plant capacity','AVG(sensor_value/max_capacity)*100','Sum of sensor readings','Theoretical max capacity','Plant x Line','%','Operations',PARSE_JSON('["plant","line","period"]'),PARSE_JSON('["date_range","plant"]'),PARSE_JSON('["IOT_SENSOR_READINGS"]'),15
UNION ALL SELECT 'KPI-DR-001','Duty Rate Impact','Cost',2,'Average effective duty rate across shipments','AVG(duty_rate_pct)','Sum of duty amounts','Total dutiable value','Origin-Destination','%','Finance',PARSE_JSON('["origin","destination","period"]'),PARSE_JSON('["date_range","origin","destination"]'),PARSE_JSON('["FIN_TARIFFS"]'),1440
UNION ALL SELECT 'KPI-FX-001','FX Impact','Cost',2,'Standard deviation of exchange rate fluctuation','STDDEV(exchange_rate)','Rate variance','Rate count','Currency Pair','Sigma','Finance',PARSE_JSON('["currency_pair","period"]'),PARSE_JSON('["date_range","currency"]'),PARSE_JSON('["FIN_EXCHANGE_RATES"]'),1440
UNION ALL SELECT 'KPI-OC-001','Order Cancellation Rate','Delivery',2,'Percentage of orders cancelled before fulfillment','SUM(CASE WHEN is_cancelled THEN 1 ELSE 0 END)::FLOAT/NULLIF(COUNT(*),0)*100','Cancelled orders','All orders','Order','%','Sales',PARSE_JSON('["plant","customer","period"]'),PARSE_JSON('["date_range","plant","customer"]'),PARSE_JSON('["ONT_SALES_ORDER"]'),60
UNION ALL SELECT 'KPI-RR-001','Carrier Reliability Score','Logistics',2,'Average carrier reliability score weighted by shipment volume','SUM(reliability_score*shipment_count)/NULLIF(SUM(shipment_count),0)','Weighted reliability sum','Total shipments','Carrier','Score','Logistics',PARSE_JSON('["carrier","region","period"]'),PARSE_JSON('["date_range","carrier"]'),PARSE_JSON('["ONT_CARRIER","ONT_SHIPMENT"]'),60
UNION ALL SELECT 'KPI-IV-001','Inventory Value at Risk','Planning',2,'Total valuation USD of items with zero available quantity','SUM(CASE WHEN qty_available<=0 THEN valuation_usd ELSE 0 END)','Value of zero-available stock','N/A','Plant','$','Planning',PARSE_JSON('["plant","material_group","period"]'),PARSE_JSON('["date_range","plant"]'),PARSE_JSON('["ONT_INVENTORY_POSITION"]'),1440;

-- VALIDATE: 24 total (7 Tier-1, 17 Tier-2)
SELECT TIER, COUNT(*) AS CNT FROM KPI_REGISTRY GROUP BY TIER ORDER BY TIER;
