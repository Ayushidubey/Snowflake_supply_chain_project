-- =============================================================================
-- PHASE 1: Database and Schemas
-- Supply Chain Command Center - Hackathon Project
-- =============================================================================

CREATE OR REPLACE DATABASE SUPPLY_CHAIN_HUB
  COMMENT='Supply Chain Ontology and Governed Conversational Analytics - Hackathon Project';

USE DATABASE SUPPLY_CHAIN_HUB;

CREATE OR REPLACE SCHEMA SC_RAW
  COMMENT='Raw ingestion layer - preserves original source schemas and formats';

CREATE OR REPLACE SCHEMA SC_CURATED
  COMMENT='Curated layer - conformed dimensions, facts, identity resolution';

CREATE OR REPLACE SCHEMA SC_ONT
  COMMENT='Ontology layer - canonical entities, relationships, hierarchies, KPI registry';

CREATE OR REPLACE SCHEMA SC_SEM
  COMMENT='Semantic layer - governed semantic views for conversational analytics';

CREATE OR REPLACE SCHEMA SC_APP
  COMMENT='Application layer - Streamlit app, UDFs, procedures';

CREATE OR REPLACE SCHEMA SC_GOV
  COMMENT='Governance layer - RBAC, policies, audit logs, test harness';

CREATE OR REPLACE SCHEMA SC_STAGES
  COMMENT='Internal file stages - one per source vendor system';
