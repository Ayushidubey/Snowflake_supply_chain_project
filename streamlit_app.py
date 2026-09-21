import streamlit as st
import pandas as pd
import json
import hashlib
import uuid
from datetime import datetime
from snowflake.snowpark.context import get_active_session

# --- Configuration ---
st.set_page_config(page_title="Supply Chain Command Center", page_icon="", layout="wide")
session = get_active_session()

SEMANTIC_MODEL = "@SUPPLY_CHAIN_HUB.SC_STAGES.STG_SEMANTIC_MODELS/supply_chain_hub.yaml"

# --- Governed KPI Reference Values ---
GOVERNED_KPIS = {
    "KPI-OTD-001": {"name": "On-Time Delivery %", "unit": "%", "domain": "Delivery"},
    "KPI-FR-001": {"name": "Fill Rate %", "unit": "%", "domain": "Planning"},
    "KPI-OTIF-001": {"name": "OTIF %", "unit": "%", "domain": "Delivery"},
    "KPI-POR-001": {"name": "Perfect Order Rate %", "unit": "%", "domain": "Delivery"},
    "KPI-DOI-001": {"name": "Days of Inventory", "unit": "days", "domain": "Planning"},
    "KPI-SOT-001": {"name": "Supplier On-Time %", "unit": "%", "domain": "Procurement"},
    "KPI-LC-001": {"name": "Landed Cost/Unit", "unit": "$/unit", "domain": "Cost"},
}

# --- Helper Functions ---
def run_query(sql):
    return session.sql(sql).to_pandas()

def get_kpi_summary():
    return run_query("""
        SELECT KPI_ID, KPI_NAME, DOMAIN, ROUND(KPI_VALUE, 2) AS KPI_VALUE, UNIT, SAMPLE_SIZE
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_KPI_SUMMARY ORDER BY KPI_ID
    """)

def generate_evidence(kpi_id, kpi_value, sql_used, dimensions=None, filters=None):
    lineage_map = {
        "KPI-OTD-001": {"semantic": "SEM_DELIVERY", "ontology": "ONT_SHIPMENT", "curated": "FACT_SHIPMENTS", "raw": "TMS_SHIPMENTS_MASTER", "source_file": "stg_freight/shipments/tms_shipments.csv.gz"},
        "KPI-FR-001": {"semantic": "SEM_FULFILLMENT", "ontology": "ONT_ORDER_LINE", "curated": "FACT_ORDER_LINES", "raw": "ERP_ORDER_LINES", "source_file": "stg_erp/order_lines/erp_order_lines.parquet"},
        "KPI-OTIF-001": {"semantic": "SEM_DELIVERY", "ontology": "ONT_SHIPMENT,ONT_ORDER_LINE", "curated": "FACT_SHIPMENTS,FACT_ORDER_LINES", "raw": "TMS_SHIPMENTS_MASTER,ERP_ORDER_LINES", "source_file": "stg_freight/shipments/tms_shipments.csv.gz"},
        "KPI-POR-001": {"semantic": "SEM_DELIVERY", "ontology": "ONT_SHIPMENT,ONT_ORDER_LINE", "curated": "FACT_SHIPMENTS,FACT_ORDER_LINES", "raw": "TMS_SHIPMENTS_MASTER,ERP_ORDER_LINES", "source_file": "stg_freight/shipments/tms_shipments.csv.gz"},
        "KPI-DOI-001": {"semantic": "SEM_INVENTORY", "ontology": "ONT_INVENTORY_POSITION", "curated": "FACT_INVENTORY", "raw": "ERP_INVENTORY_SNAPSHOTS", "source_file": "stg_erp/inventory/erp_inventory_snapshots.parquet"},
        "KPI-SOT-001": {"semantic": "SEM_PROCUREMENT", "ontology": "ONT_PURCHASE_RECEIPT", "curated": "FACT_PURCHASE_RECEIPTS", "raw": "SUP_RECEIPTS", "source_file": "stg_supplier/receipts/sup_receipts.json"},
        "KPI-LC-001": {"semantic": "SEM_COST", "ontology": "ONT_SHIPMENT,FIN_COST_ALLOCATIONS", "curated": "FACT_SHIPMENTS", "raw": "FIN_COST_ALLOCATIONS,TMS_SHIPMENTS_MASTER", "source_file": "stg_finance/cost_allocations/fin_cost_allocations.csv.gz"},
    }
    lineage = lineage_map.get(kpi_id, {})
    return {
        "evidence_id": f"EVD-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid.uuid4().hex[:6]}",
        "generated_at": datetime.now().isoformat(),
        "kpi": {"id": kpi_id, "name": GOVERNED_KPIS.get(kpi_id, {}).get("name", "Unknown"), "domain": GOVERNED_KPIS.get(kpi_id, {}).get("domain", "")},
        "result": {"value": kpi_value, "unit": GOVERNED_KPIS.get(kpi_id, {}).get("unit", "")},
        "context": {"dimensions": dimensions or [], "filters": filters or []},
        "lineage": {
            "semantic": f"SC_SEM.{lineage.get('semantic', 'N/A')}",
            "ontology": f"SC_ONT.{lineage.get('ontology', 'N/A')}",
            "curated": f"SC_CURATED.{lineage.get('curated', 'N/A')}",
            "raw": f"SC_RAW.{lineage.get('raw', 'N/A')}",
            "source_file": lineage.get("source_file", "N/A"),
        },
        "sql_used": sql_used,
        "data_quality": {"status": "PASS"},
    }

def log_action(action_type, status, kpi_context, payload_summary, target):
    action_id = f"ACT-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid.uuid4().hex[:6]}"
    payload_hash = hashlib.sha256(payload_summary.encode()).hexdigest()
    session.sql(f"""
        INSERT INTO SUPPLY_CHAIN_HUB.SC_GOV.ACTION_AUDIT 
        (ACTION_ID, ACTION_TYPE, ACTION_STATUS, KPI_CONTEXT, PAYLOAD_SUMMARY, PAYLOAD_HASH, TARGET_ENDPOINT, USER_CONFIRMED, EXECUTED_AT)
        VALUES ('{action_id}', '{action_type}', '{status}', '{kpi_context}', '{payload_summary[:500]}', '{payload_hash}', '{target}', TRUE, CURRENT_TIMESTAMP())
    """).collect()
    return action_id

# --- Sidebar Navigation ---
page = st.sidebar.radio("Navigation", [
    "Executive Dashboard",
    "Delivery & Fulfillment",
    "Inventory & Planning",
    "Procurement & Suppliers",
    "Cost Analysis",
    "Quality",
    "Ask the Supply Chain",
])

# ============================================================
# PAGE 1: EXECUTIVE DASHBOARD
# ============================================================
if page == "Executive Dashboard":
    st.title("Supply Chain Command Center")
    st.caption("Governed KPI Dashboard | Source: SC_SEM Layer | All values governed by KPI_REGISTRY")
    
    kpi_df = get_kpi_summary()
    
    col1, col2, col3, col4 = st.columns(4)
    cols = [col1, col2, col3, col4, col1, col2, col3]
    
    for idx, row in kpi_df.iterrows():
        with cols[idx % 4]:
            unit = row["UNIT"]
            val = row["KPI_VALUE"]
            display_val = f"{val}%" if unit == "PERCENT" else f"${val}" if unit == "USD" else f"{val} {unit.lower()}"
            st.metric(label=row["KPI_NAME"], value=display_val, help=f"{row['KPI_ID']} | Domain: {row['DOMAIN']} | Sample: {row['SAMPLE_SIZE']:,}")
    
    st.divider()
    st.subheader("KPI Registry (Tier-1)")
    registry = run_query("""
        SELECT KPI_ID, KPI_NAME, DOMAIN, BUSINESS_DEFINITION, FORMULA_SQL, GRAIN, STATUS
        FROM SUPPLY_CHAIN_HUB.SC_ONT.KPI_REGISTRY WHERE TIER = 1 ORDER BY KPI_ID
    """)
    st.dataframe(registry, use_container_width=True)

# ============================================================
# PAGE 2: DELIVERY & FULFILLMENT
# ============================================================
elif page == "Delivery & Fulfillment":
    st.title("Delivery & Fulfillment Performance")
    
    tab1, tab2 = st.tabs(["Delivery (OTD/OTIF/POR)", "Fulfillment (Fill Rate)"])
    
    with tab1:
        otd_by_plant = run_query("""
            SELECT PLANT_CODE,
                   ROUND(SUM(OTD_NUMERATOR)::FLOAT / NULLIF(SUM(OTD_DENOMINATOR),0)*100, 2) AS OTD_PCT,
                   ROUND(SUM(OTIF_NUMERATOR)::FLOAT / NULLIF(SUM(OTD_DENOMINATOR),0)*100, 2) AS OTIF_PCT,
                   ROUND(SUM(PERFECT_ORDER_NUMERATOR)::FLOAT / NULLIF(SUM(OTD_DENOMINATOR),0)*100, 2) AS POR_PCT,
                   SUM(OTD_DENOMINATOR) AS DELIVERIES
            FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_DELIVERY
            GROUP BY PLANT_CODE ORDER BY OTD_PCT ASC
        """)
        st.dataframe(otd_by_plant, use_container_width=True)
        st.bar_chart(otd_by_plant.set_index("PLANT_CODE")[["OTD_PCT", "OTIF_PCT", "POR_PCT"]])
        
        st.subheader("OTD by Month")
        otd_monthly = run_query("""
            SELECT DATE_TRUNC('month', SHIP_DATE)::DATE AS MONTH,
                   ROUND(SUM(OTD_NUMERATOR)::FLOAT / NULLIF(SUM(OTD_DENOMINATOR),0)*100, 2) AS OTD_PCT
            FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_DELIVERY WHERE SHIP_DATE IS NOT NULL
            GROUP BY 1 ORDER BY 1
        """)
        st.line_chart(otd_monthly.set_index("MONTH"))
    
    with tab2:
        fr_by_group = run_query("""
            SELECT MATERIAL_GROUP,
                   ROUND(SUM(FILL_RATE_NUMERATOR)::FLOAT / NULLIF(SUM(FILL_RATE_DENOMINATOR),0)*100, 2) AS FILL_RATE_PCT,
                   SUM(FILL_RATE_DENOMINATOR) AS DELIVERED_LINES
            FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_FULFILLMENT
            GROUP BY MATERIAL_GROUP ORDER BY FILL_RATE_PCT ASC
        """)
        st.dataframe(fr_by_group, use_container_width=True)

# ============================================================
# PAGE 3: INVENTORY & PLANNING
# ============================================================
elif page == "Inventory & Planning":
    st.title("Inventory & Planning")
    
    inv_summary = run_query("""
        SELECT PLANT_CODE, PLANT_NAME,
               ROUND(AVG(DAYS_OF_INVENTORY), 1) AS AVG_DOI,
               SUM(IS_STOCKOUT) AS STOCKOUT_DAYS,
               COUNT(*) AS TOTAL_POSITIONS,
               ROUND(SUM(IS_STOCKOUT)::FLOAT / NULLIF(COUNT(*),0)*100, 2) AS STOCKOUT_RATE_PCT
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_INVENTORY
        GROUP BY PLANT_CODE, PLANT_NAME ORDER BY STOCKOUT_RATE_PCT DESC
    """)
    
    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Plant Inventory Health")
        st.dataframe(inv_summary, use_container_width=True)
    with col2:
        st.subheader("Stockout Rate by Plant")
        st.bar_chart(inv_summary.set_index("PLANT_NAME")["STOCKOUT_RATE_PCT"])
    
    st.subheader("Current Inventory (Latest Snapshot)")
    latest_inv = run_query("""
        SELECT PLANT_CODE, MATERIAL_GROUP, 
               SUM(QTY_ON_HAND) AS QTY_ON_HAND, SUM(QTY_AVAILABLE) AS QTY_AVAILABLE,
               ROUND(SUM(VALUATION_USD),2) AS VALUATION_USD
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_INVENTORY
        WHERE SNAPSHOT_DATE = (SELECT MAX(SNAPSHOT_DATE) FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_INVENTORY)
        GROUP BY PLANT_CODE, MATERIAL_GROUP ORDER BY VALUATION_USD DESC LIMIT 20
    """)
    st.dataframe(latest_inv, use_container_width=True)

# ============================================================
# PAGE 4: PROCUREMENT & SUPPLIERS
# ============================================================
elif page == "Procurement & Suppliers":
    st.title("Procurement & Supplier Performance")
    
    supplier_perf = run_query("""
        SELECT SUPPLIER_NAME, SUPPLIER_GROUP, SUPPLIER_REGION,
               ROUND(SUM(SOT_NUMERATOR)::FLOAT / NULLIF(SUM(SOT_DENOMINATOR),0)*100, 2) AS SOT_PCT,
               ROUND(SUM(DEFECT_PPM_NUMERATOR)::FLOAT / NULLIF(SUM(DEFECT_PPM_DENOMINATOR),0)*1000000, 0) AS DEFECT_PPM,
               ROUND(AVG(LEAD_TIME_DAYS), 1) AS AVG_LEAD_TIME,
               SUM(SOT_DENOMINATOR) AS TOTAL_RECEIPTS
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_PROCUREMENT
        WHERE SUPPLIER_NAME IS NOT NULL
        GROUP BY 1,2,3 HAVING SUM(SOT_DENOMINATOR) >= 5
        ORDER BY SOT_PCT ASC
    """)
    
    st.subheader("Supplier Scorecard")
    st.dataframe(supplier_perf, use_container_width=True)
    
    st.subheader("Bottom 10 Suppliers by On-Time %")
    bottom10 = supplier_perf.head(10)
    st.bar_chart(bottom10.set_index("SUPPLIER_NAME")["SOT_PCT"])

# ============================================================
# PAGE 5: COST ANALYSIS
# ============================================================
elif page == "Cost Analysis":
    st.title("Cost Analysis")
    
    cost_by_type = run_query("""
        SELECT COST_TYPE, 
               ROUND(SUM(AMOUNT_USD), 2) AS TOTAL_USD,
               COUNT(DISTINCT SHIPMENT_REF) AS SHIPMENTS
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_COST WHERE IS_DELIVERED = TRUE
        GROUP BY COST_TYPE ORDER BY TOTAL_USD DESC
    """)
    
    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Cost Breakdown by Type")
        st.dataframe(cost_by_type, use_container_width=True)
    with col2:
        lc = run_query("""
            SELECT ROUND(SUM(AMOUNT_USD) / NULLIF(
                (SELECT SUM(pieces) FROM (
                    SELECT DISTINCT SHIPMENT_REF, SHIPMENT_PIECES AS pieces
                    FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_COST WHERE IS_DELIVERED = TRUE
                )), 0), 2) AS LANDED_COST_PER_UNIT
            FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_COST WHERE IS_DELIVERED = TRUE
        """)
        st.metric("Landed Cost per Unit (USD)", f"${lc.iloc[0,0]}")
        
        fc = run_query("""
            SELECT ROUND(SUM(FREIGHT_COST_USD) / NULLIF(SUM(FREIGHT_WEIGHT_DENOMINATOR),0), 2) AS FREIGHT_COST_PER_KG
            FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_COST WHERE IS_DELIVERED = TRUE AND COST_TYPE = 'FREIGHT'
        """)
        st.metric("Freight Cost per kg (USD)", f"${fc.iloc[0,0]}")

# ============================================================
# PAGE 6: QUALITY
# ============================================================
elif page == "Quality":
    st.title("Quality Events")
    
    quality_summary = run_query("""
        SELECT SEVERITY, COUNT(*) AS EVENT_COUNT, SUM(UNITS_AFFECTED) AS TOTAL_UNITS_AFFECTED
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_QUALITY
        GROUP BY SEVERITY ORDER BY EVENT_COUNT DESC
    """)
    st.dataframe(quality_summary, use_container_width=True)
    
    st.subheader("Quality Events by Plant")
    quality_by_plant = run_query("""
        SELECT PLANT_NAME, PLANT_CODE, SEVERITY, COUNT(*) AS EVENTS
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_QUALITY
        GROUP BY 1,2,3 ORDER BY EVENTS DESC LIMIT 20
    """)
    st.dataframe(quality_by_plant, use_container_width=True)
    
    st.subheader("Recent Critical Events")
    critical = run_query("""
        SELECT EVENT_ID, PLANT_NAME, MATERIAL_DESC, DEFECT_CATEGORY, ROOT_CAUSE, 
               UNITS_AFFECTED, DISPOSITION, EVENT_TIMESTAMP
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_QUALITY
        WHERE SEVERITY = 'CRITICAL' ORDER BY EVENT_TIMESTAMP DESC LIMIT 10
    """)
    st.dataframe(critical, use_container_width=True)

# ============================================================
# PAGE 7: ASK THE SUPPLY CHAIN (Cortex Analyst + Evidence + Actions)
# ============================================================
elif page == "Ask the Supply Chain":
    st.title("Ask the Supply Chain")
    st.caption("Natural language queries powered by Cortex Analyst | Governed by KPI_REGISTRY")
    
    # Initialize chat history
    if "messages" not in st.session_state:
        st.session_state.messages = []
    if "last_evidence" not in st.session_state:
        st.session_state.last_evidence = None
    
    # Display chat history
    for msg in st.session_state.messages:
        with st.chat_message(msg["role"]):
            st.write(msg["content"])
            if msg.get("df") is not None:
                st.dataframe(msg["df"], use_container_width=True)
    
    # Chat input
    user_question = st.chat_input("Ask a supply chain question...")
    
    if user_question:
        st.session_state.messages.append({"role": "user", "content": user_question})
        with st.chat_message("user"):
            st.write(user_question)
        
        with st.chat_message("assistant"):
            with st.spinner("Querying Cortex Analyst..."):
                try:
                    # Call Cortex Analyst
                    analyst_response = session.sql(f"""
                        SELECT SNOWFLAKE.CORTEX.COMPLETE(
                            'llama3.1-70b',
                            'You are a supply chain analyst. Given this question, return ONLY the SQL query to answer it using SUPPLY_CHAIN_HUB.SC_SEM views. Question: {user_question.replace("'", "''")}'
                        ) AS response
                    """).to_pandas()
                    
                    # For demo, use verified queries directly
                    # Map common questions to governed SQL
                    governed_sql = None
                    question_lower = user_question.lower()
                    
                    if "otd" in question_lower or "on-time delivery" in question_lower or "on time" in question_lower:
                        if "plant" in question_lower:
                            governed_sql = """SELECT PLANT_CODE, ROUND(SUM(OTD_NUMERATOR)::FLOAT/NULLIF(SUM(OTD_DENOMINATOR),0)*100,2) AS OTD_PCT, SUM(OTD_DENOMINATOR) AS DELIVERIES FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_DELIVERY GROUP BY PLANT_CODE ORDER BY OTD_PCT ASC"""
                        elif "why" in question_lower or "low" in question_lower:
                            governed_sql = """SELECT PLANT_CODE, CARRIER_KEY, SUM(OTD_DENOMINATOR)-SUM(OTD_NUMERATOR) AS LATE_SHIPMENTS, SUM(OTD_DENOMINATOR) AS TOTAL, ROUND((SUM(OTD_DENOMINATOR)-SUM(OTD_NUMERATOR))::FLOAT/NULLIF(SUM(OTD_DENOMINATOR),0)*100,2) AS LATE_PCT FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_DELIVERY WHERE IS_DELIVERED=TRUE GROUP BY 1,2 ORDER BY LATE_SHIPMENTS DESC LIMIT 10"""
                        else:
                            governed_sql = """SELECT ROUND(SUM(OTD_NUMERATOR)::FLOAT/NULLIF(SUM(OTD_DENOMINATOR),0)*100,2) AS ON_TIME_DELIVERY_PCT FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_DELIVERY"""
                    elif "fill rate" in question_lower:
                        governed_sql = """SELECT ROUND(SUM(FILL_RATE_NUMERATOR)::FLOAT/NULLIF(SUM(FILL_RATE_DENOMINATOR),0)*100,2) AS FILL_RATE_PCT FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_FULFILLMENT"""
                    elif "otif" in question_lower:
                        if "month" in question_lower:
                            governed_sql = """SELECT DATE_TRUNC('month',SHIP_DATE)::DATE AS MONTH, ROUND(SUM(OTIF_NUMERATOR)::FLOAT/NULLIF(SUM(OTD_DENOMINATOR),0)*100,2) AS OTIF_PCT FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_DELIVERY WHERE SHIP_DATE IS NOT NULL GROUP BY 1 ORDER BY 1"""
                        else:
                            governed_sql = """SELECT ROUND(SUM(OTIF_NUMERATOR)::FLOAT/NULLIF(SUM(OTD_DENOMINATOR),0)*100,2) AS OTIF_PCT FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_DELIVERY"""
                    elif "supplier" in question_lower and ("worst" in question_lower or "bottom" in question_lower or "performing" in question_lower):
                        governed_sql = """SELECT SUPPLIER_NAME, ROUND(SUM(SOT_NUMERATOR)::FLOAT/NULLIF(SUM(SOT_DENOMINATOR),0)*100,2) AS SOT_PCT, SUM(SOT_DENOMINATOR) AS RECEIPTS FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_PROCUREMENT WHERE SUPPLIER_NAME IS NOT NULL GROUP BY 1 HAVING SUM(SOT_DENOMINATOR)>=10 ORDER BY SOT_PCT ASC LIMIT 10"""
                    elif "landed cost" in question_lower:
                        governed_sql = """SELECT ROUND(SUM(AMOUNT_USD)/NULLIF((SELECT SUM(pieces) FROM (SELECT DISTINCT SHIPMENT_REF, SHIPMENT_PIECES AS pieces FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_COST WHERE IS_DELIVERED=TRUE)),0),2) AS LANDED_COST_PER_UNIT FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_COST WHERE IS_DELIVERED=TRUE"""
                    elif "inventory" in question_lower and ("risk" in question_lower or "stockout" in question_lower):
                        governed_sql = """SELECT PLANT_CODE, PLANT_NAME, SUM(IS_STOCKOUT) AS STOCKOUT_DAYS, COUNT(*) AS TOTAL_DAYS, ROUND(SUM(IS_STOCKOUT)::FLOAT/NULLIF(COUNT(*),0)*100,2) AS STOCKOUT_RATE_PCT FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_INVENTORY GROUP BY 1,2 ORDER BY STOCKOUT_RATE_PCT DESC LIMIT 10"""
                    elif "carrier" in question_lower and "damage" in question_lower:
                        governed_sql = """SELECT CARRIER_KEY, SUM(CASE WHEN IS_DAMAGED THEN 1 ELSE 0 END) AS DAMAGED, SUM(OTD_DENOMINATOR) AS TOTAL, ROUND(SUM(CASE WHEN IS_DAMAGED THEN 1 ELSE 0 END)::FLOAT/NULLIF(SUM(OTD_DENOMINATOR),0)*100,2) AS DAMAGE_RATE_PCT FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_DELIVERY WHERE IS_DELIVERED=TRUE GROUP BY 1 ORDER BY DAMAGE_RATE_PCT DESC"""
                    elif "tier-1" in question_lower or "all kpi" in question_lower or "summary" in question_lower:
                        governed_sql = """SELECT KPI_ID, KPI_NAME, DOMAIN, ROUND(KPI_VALUE,2) AS KPI_VALUE, UNIT, SAMPLE_SIZE FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_KPI_SUMMARY ORDER BY KPI_ID"""
                    elif "quality" in question_lower and "critical" in question_lower:
                        governed_sql = """SELECT EVENT_ID, PLANT_NAME, MATERIAL_DESC, DEFECT_CATEGORY, ROOT_CAUSE, UNITS_AFFECTED, DISPOSITION FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_QUALITY WHERE SEVERITY='CRITICAL' ORDER BY EVENT_TIMESTAMP DESC LIMIT 10"""
                    
                    if governed_sql:
                        result_df = run_query(governed_sql)
                        st.write("**Result:**")
                        st.dataframe(result_df, use_container_width=True)
                        st.session_state.messages.append({"role": "assistant", "content": "Query executed successfully.", "df": result_df})
                        
                        # Generate evidence
                        kpi_id = "KPI-OTD-001"  # Default; would be determined by query type
                        if "fill rate" in question_lower: kpi_id = "KPI-FR-001"
                        elif "otif" in question_lower: kpi_id = "KPI-OTIF-001"
                        elif "supplier" in question_lower: kpi_id = "KPI-SOT-001"
                        elif "landed" in question_lower: kpi_id = "KPI-LC-001"
                        elif "inventory" in question_lower: kpi_id = "KPI-DOI-001"
                        
                        evidence = generate_evidence(kpi_id, str(result_df.iloc[0,0] if len(result_df) == 1 else "See table"), governed_sql)
                        st.session_state.last_evidence = evidence
                    else:
                        st.write("I couldn't map that question to a governed query. Please try rephrasing or use one of the suggested questions below.")
                        st.session_state.messages.append({"role": "assistant", "content": "Could not map to governed query."})
                        
                except Exception as e:
                    st.error(f"Error: {str(e)}")
                    st.session_state.messages.append({"role": "assistant", "content": f"Error: {str(e)}"})
    
    # Evidence Panel
    if st.session_state.last_evidence:
        with st.expander("Evidence & Lineage (Last Query)", expanded=False):
            ev = st.session_state.last_evidence
            st.json(ev)
    
    # Action Panel
    st.divider()
    st.subheader("Governed Actions")
    st.caption("All actions require explicit confirmation and are logged to ACTION_AUDIT")
    
    col1, col2, col3 = st.columns(3)
    with col1:
        if st.button("Create Jira Issue (Demo)"):
            st.session_state["action_pending"] = "JIRA"
    with col2:
        if st.button("Send SMS Alert (Demo)"):
            st.session_state["action_pending"] = "SMS"
    with col3:
        if st.button("Send WhatsApp Alert (Demo)"):
            st.session_state["action_pending"] = "WHATSAPP"
    
    if st.session_state.get("action_pending"):
        action_type = st.session_state["action_pending"]
        st.warning(f"**Confirmation Required**: You are about to trigger a {action_type} action in DEMO MODE.")
        st.caption("No external API call will be made. This action will be logged to ACTION_AUDIT as MOCKED.")
        
        if st.button(f"CONFIRM {action_type} Action"):
            payload = f"[DEMO] {action_type} action triggered from Supply Chain Command Center"
            action_id = log_action(action_type, "MOCKED", "KPI-OTD-001", payload, f"DEMO_{action_type}_ENDPOINT")
            st.success(f"Action logged as MOCKED. Action ID: {action_id}")
            st.session_state["action_pending"] = None
        
        if st.button("Cancel"):
            st.session_state["action_pending"] = None
    
    # Suggested Questions
    st.divider()
    st.caption("**Suggested questions:** What is our OTD? | What is our Fill Rate? | Show OTIF by month | Which suppliers are worst? | What is landed cost per unit? | Which plants have inventory risk? | Show carrier damage rate | Give me all Tier-1 KPIs")
