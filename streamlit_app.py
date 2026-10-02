import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Supply Chain Command Center", layout="wide")

session = get_active_session()

def run_query(sql):
    return session.sql(sql).to_pandas()

# --- Sidebar ---
st.sidebar.title("SC Command Center")
page = st.sidebar.radio("Navigate", [
    "KPI Dashboard",
    "Delivery & Logistics",
    "Fulfillment",
    "Inventory",
    "Procurement & Quality",
    "Cost Analytics",
    "SQL Explorer"
])

# ============================================================
# KPI DASHBOARD
# ============================================================
if page == "KPI Dashboard":
    st.title("Supply Chain Command Center")
    st.markdown("**Governed KPI Dashboard** - real-time from semantic layer")

    kpis = run_query("""
        SELECT KPI_ID, KPI_NAME, ROUND(KPI_VALUE, 2) AS KPI_VALUE, UNIT
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_KPI_SUMMARY ORDER BY KPI_ID
    """)

    st.subheader("Tier-1 KPIs")
    c1, c2, c3, c4, c5, c6, c7 = st.columns(7)
    cols_list = [c1, c2, c3, c4, c5, c6, c7]
    for i, row in kpis.iterrows():
        if i < 7:
            val = row["KPI_VALUE"]
            unit = row["UNIT"]
            if unit in ("$/unit",):
                display = f"${val}"
            else:
                display = f"{val} {unit}"
            cols_list[i].metric(label=row["KPI_NAME"], value=display)

    st.markdown("---")

    st.subheader("Full KPI Registry (24 KPIs)")
    registry = run_query("""
        SELECT KPI_ID, KPI_NAME, DOMAIN, TIER, GRAIN, UNIT, OWNER_PERSONA, STATUS
        FROM SUPPLY_CHAIN_HUB.SC_ONT.KPI_REGISTRY ORDER BY TIER, DOMAIN, KPI_ID
    """)
    st.dataframe(registry, use_container_width=True)

# ============================================================
# DELIVERY & LOGISTICS
# ============================================================
elif page == "Delivery & Logistics":
    st.title("Delivery & Logistics")

    summary = run_query("""
        SELECT
          ROUND(SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END)::FLOAT /
                NULLIF(SUM(CASE WHEN is_delivered THEN 1 ELSE 0 END),0)*100, 2) AS OTD,
          ROUND(SUM(CASE WHEN is_damaged THEN 1 ELSE 0 END)::FLOAT /
                NULLIF(COUNT(*),0)*100, 2) AS DAMAGE_RATE,
          ROUND(AVG(transit_days), 1) AS AVG_TRANSIT
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_DELIVERY WHERE is_delivered
    """)
    c1, c2, c3 = st.columns(3)
    c1.metric("On-Time Delivery %", f"{summary['OTD'].iloc[0]}%")
    c2.metric("Damage Rate %", f"{summary['DAMAGE_RATE'].iloc[0]}%")
    c3.metric("Avg Transit Days", f"{summary['AVG_TRANSIT'].iloc[0]}")

    st.subheader("OTD by Carrier")
    carrier = run_query("""
        SELECT carrier_name AS "Carrier",
          COUNT(*) AS "Shipments",
          ROUND(SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END)::FLOAT /
                NULLIF(SUM(CASE WHEN is_delivered THEN 1 ELSE 0 END),0)*100, 1) AS "OTD %",
          ROUND(SUM(CASE WHEN is_damaged THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*),0)*100,1) AS "Damage %",
          ROUND(AVG(transit_days),1) AS "Avg Transit"
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_DELIVERY WHERE is_delivered
        GROUP BY carrier_name ORDER BY "Shipments" DESC
    """)
    st.dataframe(carrier, use_container_width=True)

    chart_data = carrier[["Carrier", "OTD %"]].set_index("Carrier")
    st.bar_chart(chart_data)

    st.subheader("OTD by Plant Region")
    region = run_query("""
        SELECT plant_region AS "Region",
          COUNT(*) AS "Shipments",
          ROUND(SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END)::FLOAT /
                NULLIF(SUM(CASE WHEN is_delivered THEN 1 ELSE 0 END),0)*100, 1) AS "OTD %"
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_DELIVERY WHERE is_delivered AND plant_region IS NOT NULL
        GROUP BY plant_region ORDER BY "Shipments" DESC
    """)
    st.dataframe(region, use_container_width=True)

# ============================================================
# FULFILLMENT
# ============================================================
elif page == "Fulfillment":
    st.title("Order Fulfillment")

    fr = run_query("""
        SELECT
          ROUND(SUM(CASE WHEN is_full_fill THEN 1 ELSE 0 END)::FLOAT /
                NULLIF(SUM(CASE WHEN is_delivered THEN 1 ELSE 0 END),0)*100, 2) AS FILL_RATE,
          ROUND(SUM(CASE WHEN is_cancelled THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*),0)*100,2) AS CANCEL_RATE,
          COUNT(*) AS TOTAL_LINES
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_FULFILLMENT
    """)
    c1, c2, c3 = st.columns(3)
    c1.metric("Fill Rate %", f"{fr['FILL_RATE'].iloc[0]}%")
    c2.metric("Cancellation Rate %", f"{fr['CANCEL_RATE'].iloc[0]}%")
    c3.metric("Total Order Lines", f"{int(fr['TOTAL_LINES'].iloc[0]):,}")

    st.subheader("Fill Rate by Material Group")
    mg = run_query("""
        SELECT material_group AS "Material Group",
          COUNT(*) AS "Lines",
          ROUND(SUM(CASE WHEN is_full_fill THEN 1 ELSE 0 END)::FLOAT /
                NULLIF(SUM(CASE WHEN is_delivered THEN 1 ELSE 0 END),0)*100,1) AS "Fill Rate %"
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_FULFILLMENT
        WHERE material_group IS NOT NULL
        GROUP BY material_group ORDER BY "Lines" DESC
    """)
    st.dataframe(mg, use_container_width=True)

    chart_data = mg[["Material Group", "Fill Rate %"]].set_index("Material Group")
    st.bar_chart(chart_data)

    st.subheader("Fill Rate by Plant")
    plant = run_query("""
        SELECT plant_name AS "Plant", plant_code AS "Code",
          ROUND(SUM(CASE WHEN is_full_fill THEN 1 ELSE 0 END)::FLOAT /
                NULLIF(SUM(CASE WHEN is_delivered THEN 1 ELSE 0 END),0)*100,1) AS "Fill Rate %"
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_FULFILLMENT
        WHERE plant_name IS NOT NULL
        GROUP BY plant_name, plant_code ORDER BY "Fill Rate %" ASC
    """)
    st.dataframe(plant, use_container_width=True)

# ============================================================
# INVENTORY
# ============================================================
elif page == "Inventory":
    st.title("Inventory Position")

    inv = run_query("""
        SELECT
          ROUND(AVG(qty_on_hand),0) AS AVG_OH,
          ROUND(SUM(valuation_usd)/1e6, 2) AS TOTAL_VAL_M,
          ROUND(SUM(CASE WHEN qty_available <= 0 THEN valuation_usd ELSE 0 END)/1e6, 2) AS AT_RISK_M
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_INVENTORY
    """)
    c1, c2, c3 = st.columns(3)
    c1.metric("Avg On-Hand Qty", f"{int(inv['AVG_OH'].iloc[0]):,}")
    c2.metric("Total Valuation", f"${inv['TOTAL_VAL_M'].iloc[0]}M")
    c3.metric("Value at Risk", f"${inv['AT_RISK_M'].iloc[0]}M")

    st.subheader("Inventory by Plant")
    ip = run_query("""
        SELECT plant_name AS "Plant", plant_code AS "Code",
          ROUND(SUM(qty_on_hand),0) AS "On Hand",
          ROUND(SUM(qty_available),0) AS "Available",
          ROUND(SUM(valuation_usd)/1e6,2) AS "Value ($M)"
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_INVENTORY
        WHERE plant_name IS NOT NULL
        GROUP BY plant_name, plant_code ORDER BY "Value ($M)" DESC
    """)
    st.dataframe(ip, use_container_width=True)

    st.subheader("Top 10 Materials by Value")
    tm = run_query("""
        SELECT erp_material_nbr AS "Material", material_desc AS "Description",
          ROUND(SUM(valuation_usd)/1e3,1) AS "Value ($K)",
          ROUND(AVG(qty_on_hand),0) AS "Avg On Hand"
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_INVENTORY
        WHERE material_desc IS NOT NULL
        GROUP BY erp_material_nbr, material_desc ORDER BY "Value ($K)" DESC LIMIT 10
    """)
    st.dataframe(tm, use_container_width=True)

# ============================================================
# PROCUREMENT & QUALITY
# ============================================================
elif page == "Procurement & Quality":
    st.title("Procurement & Quality")

    proc = run_query("""
        SELECT
          ROUND(SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*),0)*100,2) AS SOT,
          ROUND(SUM(CASE WHEN quality_check_passed THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*),0)*100,2) AS QC_PASS,
          ROUND(AVG(lead_time_days),1) AS AVG_LEAD
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_PROCUREMENT
    """)
    c1, c2, c3 = st.columns(3)
    c1.metric("Supplier On-Time %", f"{proc['SOT'].iloc[0]}%")
    c2.metric("QC Pass Rate %", f"{proc['QC_PASS'].iloc[0]}%")
    c3.metric("Avg Lead Time", f"{proc['AVG_LEAD'].iloc[0]} days")

    st.subheader("Supplier Performance (Top 15)")
    sup = run_query("""
        SELECT supplier_name AS "Supplier", supplier_group AS "Group",
          COUNT(*) AS "Receipts",
          ROUND(SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*),0)*100,1) AS "On-Time %",
          ROUND(SUM(CASE WHEN quality_check_passed THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*),0)*100,1) AS "QC Pass %",
          ROUND(AVG(lead_time_days),1) AS "Lead Time"
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_PROCUREMENT
        WHERE supplier_name IS NOT NULL
        GROUP BY supplier_name, supplier_group ORDER BY "Receipts" DESC LIMIT 15
    """)
    st.dataframe(sup, use_container_width=True)

    st.subheader("Quality: Defect PPM by Supplier (Top 10 worst)")
    qual = run_query("""
        SELECT supplier_name AS "Supplier",
          SUM(quantity_received) AS "Qty Received",
          SUM(defect_count) AS "Defects",
          ROUND(SUM(defect_count)::FLOAT / NULLIF(SUM(quantity_received),0) * 1000000, 0) AS "Defect PPM"
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_QUALITY
        WHERE supplier_name IS NOT NULL
        GROUP BY supplier_name
        HAVING SUM(quantity_received) > 0
        ORDER BY "Defect PPM" DESC LIMIT 10
    """)
    st.dataframe(qual, use_container_width=True)

# ============================================================
# COST ANALYTICS
# ============================================================
elif page == "Cost Analytics":
    st.title("Cost Analytics")

    cost = run_query("""
        SELECT ROUND(SUM(AMOUNT_USD)/1e6, 2) AS TOTAL_COST_M,
               COUNT(DISTINCT SHIPMENT_REF) AS SHIPMENTS_COVERED
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_COST
    """)
    c1, c2 = st.columns(2)
    c1.metric("Total Costs", f"${cost['TOTAL_COST_M'].iloc[0]}M")
    c2.metric("Shipments with Costs", f"{int(cost['SHIPMENTS_COVERED'].iloc[0]):,}")

    st.subheader("Cost Breakdown by Type")
    ct = run_query("""
        SELECT COST_TYPE AS "Cost Type",
          ROUND(SUM(AMOUNT_USD)/1e6, 2) AS "Amount ($M)",
          ROUND(SUM(AMOUNT_USD)::FLOAT / NULLIF((SELECT SUM(AMOUNT_USD) FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_COST),0)*100, 1) AS "Pct of Total"
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_COST
        GROUP BY COST_TYPE ORDER BY "Amount ($M)" DESC
    """)
    st.dataframe(ct, use_container_width=True)

    chart_data = ct[["Cost Type", "Amount ($M)"]].set_index("Cost Type")
    st.bar_chart(chart_data)

    st.subheader("Top 10 Suppliers by Cost")
    sc = run_query("""
        SELECT supplier_name AS "Supplier",
          ROUND(SUM(AMOUNT_USD)/1e6, 2) AS "Cost ($M)"
        FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_COST
        WHERE supplier_name IS NOT NULL
        GROUP BY supplier_name ORDER BY "Cost ($M)" DESC LIMIT 10
    """)
    st.dataframe(sc, use_container_width=True)

# ============================================================
# SQL EXPLORER
# ============================================================
elif page == "SQL Explorer":
    st.title("SQL Explorer")
    st.markdown("Run custom queries against the supply chain semantic layer.")

    default_sql = """SELECT KPI_ID, KPI_NAME, ROUND(KPI_VALUE, 2) AS KPI_VALUE, UNIT
FROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_KPI_SUMMARY
ORDER BY KPI_ID"""

    user_sql = st.text_area("Enter SQL query:", value=default_sql, height=150)

    if st.button("Run Query"):
        if user_sql.strip():
            try:
                result = run_query(user_sql)
                st.success(f"Returned {len(result)} rows")
                st.dataframe(result, use_container_width=True)
            except Exception as e:
                st.error(f"Query error: {str(e)}")

    st.markdown("---")
    st.subheader("Available Semantic Views")
    views = run_query("""
        SELECT TABLE_NAME AS "View", COMMENT AS "Description"
        FROM SUPPLY_CHAIN_HUB.INFORMATION_SCHEMA.VIEWS
        WHERE TABLE_SCHEMA = 'SC_SEM' ORDER BY TABLE_NAME
    """)
    st.dataframe(views, use_container_width=True)

    st.subheader("Sample Queries")
    st.code("-- On-Time Delivery by carrier\nSELECT carrier_name, COUNT(*) AS shipments,\n  ROUND(SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END)::FLOAT / NULLIF(SUM(CASE WHEN is_delivered THEN 1 ELSE 0 END),0)*100, 1) AS otd_pct\nFROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_DELIVERY\nWHERE is_delivered GROUP BY carrier_name ORDER BY shipments DESC", language="sql")
    st.code("-- Supplier defect rate\nSELECT supplier_name, SUM(defect_count) AS defects,\n  ROUND(SUM(defect_count)::FLOAT/NULLIF(SUM(quantity_received),0)*1e6, 0) AS ppm\nFROM SUPPLY_CHAIN_HUB.SC_SEM.SEM_QUALITY\nWHERE supplier_name IS NOT NULL\nGROUP BY supplier_name ORDER BY ppm DESC LIMIT 10", language="sql")
