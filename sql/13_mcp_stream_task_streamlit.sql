-- =============================================================================
-- PHASE 14: MCP Server
-- =============================================================================

CREATE OR REPLACE MCP SERVER SUPPLY_CHAIN_HUB.SC_APP.SC_SUPPLY_CHAIN_MCP FROM SPECIFICATION $$
tools:
  - name: "supply_chain_analyst"
    type: "CORTEX_ANALYST_MESSAGE"
    identifier: "SUPPLY_CHAIN_HUB.SC_STAGES.STG_SEMANTIC_MODELS/supply_chain_hub.yaml"
    description: "Governed supply chain analytics. Ask about OTD, Fill Rate, OTIF, Perfect Order Rate, DOI, Supplier On-Time, Landed Cost, and more."
    title: "Supply Chain Analyst"
$$;

GRANT USAGE ON MCP SERVER SUPPLY_CHAIN_HUB.SC_APP.SC_SUPPLY_CHAIN_MCP TO ROLE SC_HACKATHON_ANALYST;

-- =============================================================================
-- PHASE 15: Stream + Task (Incremental Pipeline)
-- =============================================================================

USE SCHEMA SUPPLY_CHAIN_HUB.SC_RAW;

ALTER TABLE TMS_SHIPMENT_EVENTS SET CHANGE_TRACKING = TRUE;

CREATE OR REPLACE STREAM STREAM_SHIPMENT_EVENTS
  ON TABLE TMS_SHIPMENT_EVENTS
  APPEND_ONLY = TRUE
  COMMENT = 'Captures new shipment tracking events for near-real-time incremental processing';

CREATE OR REPLACE TABLE SHIPMENT_EVENTS_INCREMENTAL (
  EVENT_ID VARCHAR(50), SHIPMENT_ID VARCHAR(15), EVENT_TYPE VARCHAR(50),
  EVENT_TIMESTAMP TIMESTAMP_NTZ, LOCATION VARCHAR(200), CARRIER_ID VARCHAR(10),
  NOTES VARCHAR(500), ORDER_REF VARCHAR(10), ORIGIN_FACILITY VARCHAR(100),
  DESTINATION VARCHAR(200), SHIPMENT_STATUS VARCHAR(20),
  PROCESSED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  PROCESSING_BATCH VARCHAR(50), _SOURCE_ROW_NUMBER NUMBER(38,0)
) COMMENT='Incrementally processed shipment events enriched with shipment context.';

CREATE OR REPLACE TASK TASK_PROCESS_SHIPMENT_EVENTS
  WAREHOUSE = 'COMPUTE_WH'
  SCHEDULE = '1 MINUTE'
  COMMENT = 'Processes new shipment events from stream into enriched incremental table.'
  WHEN SYSTEM$STREAM_HAS_DATA('SUPPLY_CHAIN_HUB.SC_RAW.STREAM_SHIPMENT_EVENTS')
AS
INSERT INTO SUPPLY_CHAIN_HUB.SC_RAW.SHIPMENT_EVENTS_INCREMENTAL
  (EVENT_ID, SHIPMENT_ID, EVENT_TYPE, EVENT_TIMESTAMP, LOCATION, CARRIER_ID, NOTES,
   ORDER_REF, ORIGIN_FACILITY, DESTINATION, SHIPMENT_STATUS,
   PROCESSED_AT, PROCESSING_BATCH, _SOURCE_ROW_NUMBER)
SELECT
  s.RAW_PAYLOAD:event_id::VARCHAR,
  s.RAW_PAYLOAD:shipment_id::VARCHAR,
  s.RAW_PAYLOAD:event_type::VARCHAR,
  TRY_TO_TIMESTAMP(s.RAW_PAYLOAD:event_timestamp::VARCHAR),
  s.RAW_PAYLOAD:location::VARCHAR,
  s.RAW_PAYLOAD:carrier_id::VARCHAR,
  s.RAW_PAYLOAD:notes::VARCHAR,
  m.ORDER_REF, m.ORIGIN_FACILITY, m.DESTINATION, m.STATUS,
  CURRENT_TIMESTAMP(),
  'task-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD-HH24MISS'),
  s._SOURCE_ROW_NUMBER
FROM SUPPLY_CHAIN_HUB.SC_RAW.STREAM_SHIPMENT_EVENTS s
LEFT JOIN SUPPLY_CHAIN_HUB.SC_RAW.TMS_SHIPMENTS_MASTER m
  ON s.RAW_PAYLOAD:shipment_id::VARCHAR = m.SHIPMENT_ID;

-- To test: Resume, insert test event, wait 60s, check, then suspend
-- ALTER TASK TASK_PROCESS_SHIPMENT_EVENTS RESUME;
-- ALTER TASK TASK_PROCESS_SHIPMENT_EVENTS SUSPEND;

-- =============================================================================
-- PHASE 13: Cortex Analyst YAML Upload (run from SnowSQL)
-- =============================================================================
-- PUT 'file://<PACKAGE_DIR>/models/supply_chain_hub.yaml'
--   @SUPPLY_CHAIN_HUB.SC_STAGES.STG_SEMANTIC_MODELS/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- =============================================================================
-- PHASE 16: Streamlit App (run from SnowSQL)
-- =============================================================================
-- PUT 'file://<PACKAGE_DIR>/app/streamlit_app.py'
--   @SUPPLY_CHAIN_HUB.SC_APP.STG_STREAMLIT/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

CREATE OR REPLACE STREAMLIT SUPPLY_CHAIN_HUB.SC_APP.SUPPLY_CHAIN_COMMAND_CENTER
  ROOT_LOCATION = '@SUPPLY_CHAIN_HUB.SC_APP.STG_STREAMLIT'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = 'COMPUTE_WH'
  COMMENT = 'Supply Chain Command Center - Governed KPI Dashboard with Cortex Analyst NL interface';
