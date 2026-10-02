-- =============================================================================
-- PHASE 14: Cortex Agent
-- Creates a Cortex Agent backed by all semantic views for natural language Q&A
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE AGENT SUPPLY_CHAIN_HUB.SC_APP.SC_SUPPLY_CHAIN_AGENT
  COMMENT = 'Supply Chain conversational agent - answers natural language questions using governed semantic views'
  FROM SPECIFICATION $$
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: supply_chain_kpi_analyst
      description: "Answers questions about supply chain KPIs including OTD, Fill Rate, OTIF, Perfect Order Rate, DOI, Supplier On-Time, and Landed Cost."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: delivery_analyst
      description: "Answers questions about delivery and logistics: shipments, carriers, on-time delivery, damage rates, transit times."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: fulfillment_analyst
      description: "Answers questions about order fulfillment: fill rates, order lines, cancellations by material group and plant."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: inventory_analyst
      description: "Answers questions about inventory positions: on-hand quantities, valuation, availability by plant and material."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: procurement_analyst
      description: "Answers questions about procurement: supplier on-time rates, lead times, purchase receipts."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: quality_analyst
      description: "Answers questions about quality: defect PPM, quality check pass rates, supplier quality performance."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: cost_analyst
      description: "Answers questions about costs: cost breakdowns by type, supplier costs, landed cost analysis."
tool_resources:
  supply_chain_kpi_analyst:
    semantic_view: SUPPLY_CHAIN_HUB.SC_SEM.SEM_KPI_SUMMARY
  delivery_analyst:
    semantic_view: SUPPLY_CHAIN_HUB.SC_SEM.SEM_DELIVERY
  fulfillment_analyst:
    semantic_view: SUPPLY_CHAIN_HUB.SC_SEM.SEM_FULFILLMENT
  inventory_analyst:
    semantic_view: SUPPLY_CHAIN_HUB.SC_SEM.SEM_INVENTORY
  procurement_analyst:
    semantic_view: SUPPLY_CHAIN_HUB.SC_SEM.SEM_PROCUREMENT
  quality_analyst:
    semantic_view: SUPPLY_CHAIN_HUB.SC_SEM.SEM_QUALITY
  cost_analyst:
    semantic_view: SUPPLY_CHAIN_HUB.SC_SEM.SEM_COST
  $$;

-- Grant agent usage to analyst role
GRANT USAGE ON AGENT SUPPLY_CHAIN_HUB.SC_APP.SC_SUPPLY_CHAIN_AGENT
  TO ROLE SC_HACKATHON_ANALYST;

-- =============================================================================
-- Test the agent (uncomment to run)
-- =============================================================================
-- SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
--   'SUPPLY_CHAIN_HUB.SC_APP.SC_SUPPLY_CHAIN_AGENT',
--   'What is our on-time delivery percentage?'
-- );
