# Supply Chain Command Center

Governed Supply Chain Analytics platform built on Snowflake with ontology-driven semantic layer, Cortex Agent for natural language Q&A, and a Streamlit dashboard.

## Architecture

```
SC_RAW  →  SC_CURATED  →  SC_ONT  →  SC_SEM  →  SC_APP
(16 tables)  (11 views)   (19 views)  (7 views)  (Streamlit + Agent + MCP)
                XREF                    KPI Registry
```

**Layers:**
- **SC_RAW** — Raw ingestion (ERP, Supplier, Freight, IoT, Finance)
- **SC_CURATED** — Conformed dimensions, facts, identity resolution (XREF)
- **SC_ONT** — Ontology entities, relationships, hierarchies, KPI registry (24 KPIs)
- **SC_SEM** — Governed semantic views for analytics (7 views + KPI summary)
- **SC_APP** — Streamlit app, Cortex Agent, MCP server
- **SC_GOV** — RBAC, governance tables, audit logs
- **SC_STAGES** — Internal file stages per source system

## Setup (run scripts in order)

| Script | Description |
|--------|-------------|
| `00_prerequisites.sql` | Warehouse, secret, API integration, Git repo (edit placeholders first) |
| `01_database_and_schemas.sql` | Database + 7 schemas |
| `02_file_formats_and_stages.sql` | File formats (CSV, JSON, Parquet) + stages |
| `03_raw_tables.sql` | 16 raw tables |
| `04_put_data_files.sql` | Upload data files to stages (run from SnowSQL) |
| `05_copy_into_raw.sql` | COPY INTO all 16 raw tables |
| `06_xref_identity_resolution.sql` | XREF tables (supplier, part, plant) |
| `07_curated_views.sql` | 11 secure curated views (dims + facts) |
| `08_ontology_views.sql` | 19 ontology views (entities, relationships, hierarchies) |
| `09_kpi_registry.sql` | KPI registry table + 24 KPI definitions |
| `10_semantic_views.sql` | 7 semantic views (delivery, fulfillment, inventory, etc.) |
| `11_governance_tables.sql` | Governance tables (metadata, audit, source registry) |
| `12_rbac.sql` | Role hierarchy + grants |
| `13_mcp_stream_task_streamlit.sql` | MCP server, stream, task, Streamlit app |
| `14_cortex_agent.sql` | Cortex Agent for natural language Q&A |
| `99_validation.sql` | End-to-end validation queries |

## Prerequisites

- Snowflake account with ACCOUNTADMIN access
- Warehouse (COMPUTE_WH or equivalent)
- GitHub account with a PAT for private repo access

## Important: Credentials

Script `00_prerequisites.sql` contains placeholder values for credentials. **Before running:**

1. Replace `<YOUR_GITHUB_USERNAME>` with your GitHub username
2. Replace `<YOUR_GITHUB_PERSONAL_ACCESS_TOKEN>` with your GitHub PAT
3. Replace `<YOUR_REPO_NAME>` with your repository name
4. **Never commit actual credentials to Git**

## Key Features

- **24 governed KPIs** (7 Tier-1, 17 Tier-2) across Delivery, Planning, Procurement, Quality, Cost, Operations
- **Identity resolution** via XREF tables (Supplier, Part, Plant)
- **Semantic layer** with 7 secure views for governed analytics
- **Cortex Agent** for natural language questions over supply chain data
- **MCP Server** for tool-based AI integration
- **Streamlit dashboard** with 7 pages (KPIs, Delivery, Fulfillment, Inventory, Procurement, Cost, SQL Explorer)
- **Incremental pipeline** (Stream + Task) for near-real-time shipment event processing
- **RBAC** with 4 roles (Admin, Developer, Analyst, Operator)

## Streamlit App

The `streamlit_app.py` provides a multi-page dashboard:
- **KPI Dashboard** — Tier-1 KPIs + full registry
- **Delivery & Logistics** — OTD by carrier and region
- **Fulfillment** — Fill rate by material group and plant
- **Inventory** — Position by plant, top materials by value
- **Procurement & Quality** — Supplier performance, defect PPM
- **Cost Analytics** — Cost breakdown by type and supplier
- **SQL Explorer** — Run custom queries against the semantic layer
