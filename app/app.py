"""Página 1 · Ventas  (preguntas P1 y P5). Ejecutar con:  streamlit run app.py"""
import plotly.express as px
import streamlit as st

from db import consulta
from filtros import FILTROS_SQL as F, args, resumen, sidebar_filtros

st.set_page_config(page_title="BI Olist · Ventas", page_icon="📊", layout="wide")
st.title("📊 BI Olist – Marketplace Brasil")
st.subheader("1 · Ventas")

desde, hasta, cat, est = sidebar_filtros()
a = args(desde, hasta, cat, est)
st.caption(resumen(desde, hasta, cat, est))

# ---- KPI (K1, K2, K3) ----
k = consulta(f"""SELECT dw.fn_total_ventas({F}) AS ingresos, dw.fn_ticket_promedio({F}) AS ticket,
                        dw.fn_tasa_recompra({F}) AS recompra, dw.fn_variacion_ultimo_mes({F}) AS variacion""", a * 4).iloc[0]
c1, c2, c3 = st.columns(3)
c1.metric("Ingresos totales", f"R$ {k['ingresos']:,.0f}",
          None if k["variacion"] != k["variacion"] or k["variacion"] is None else f"{k['variacion']:.1f} % vs. mes anterior")
c2.metric("Ticket promedio (AOV)", "—" if k["ticket"] != k["ticket"] else f"R$ {k['ticket']:,.2f}")
c3.metric("Tasa de recompra", "—" if k["recompra"] != k["recompra"] else f"{k['recompra']:.2f} %")
st.caption("La tasa de recompra se calcula sobre los pedidos que cumplen los filtros activos.")

# ---- Gráficos (G1, G2) ----
g1, g2 = st.columns(2)
mensual = consulta(f"SELECT * FROM dw.fn_ventas_mensuales({F})", a)
with g1:
    st.markdown("**Evolución mensual de ingresos**")
    if mensual.empty:
        st.warning("Sin datos para los filtros seleccionados.")
    else:
        st.plotly_chart(px.line(mensual, x="anio_mes", y="ingresos", markers=True,
                                labels={"anio_mes": "Mes", "ingresos": "Ingresos (R$)"}), width="stretch")
top = consulta("SELECT * FROM dw.fn_top_categorias(%s::date, %s::date, %s::char(2), 10)", (desde, hasta, est))
with g2:
    st.markdown("**Top 10 categorías por ingresos**")
    if top.empty:
        st.warning("Sin datos para los filtros seleccionados.")
    else:
        st.plotly_chart(px.bar(top.sort_values("ingresos"), x="ingresos", y="categoria", orientation="h",
                               labels={"ingresos": "Ingresos (R$)", "categoria": ""}), width="stretch")
        st.caption("Este gráfico respeta fechas y estado; no aplica el filtro de categoría (muestra todas).")

# ---- Tabla (T1) ----
st.markdown("**Ventas por región y estado del cliente**")
st.dataframe(consulta(f"SELECT * FROM dw.fn_ventas_estado({F})", a), width="stretch", hide_index=True)
