"""Página 3 · Vendedores y pagos  (preguntas P4 y P5)."""
import plotly.express as px
import streamlit as st

from db import consulta
from filtros import FILTROS_SQL as F, args, resumen, sidebar_filtros

st.set_page_config(page_title="BI Olist · Vendedores", page_icon="🏪", layout="wide")
st.title("🏪 3 · Vendedores y pagos")

desde, hasta, cat, est = sidebar_filtros()
a = args(desde, hasta, cat, est)
st.caption(resumen(desde, hasta, cat, est))

k = consulta(f"""SELECT dw.fn_total_ventas({F}) AS ingresos, dw.fn_calificacion_promedio({F}) AS calificacion,
                        dw.fn_tasa_recompra({F}) AS recompra""", a * 3).iloc[0]
nd = lambda v, f: "—" if v != v or v is None else f.format(v)
c1, c2, c3 = st.columns(3)
c1.metric("Ingresos totales", f"R$ {k['ingresos']:,.0f}")
c2.metric("Calificación promedio", nd(k["calificacion"], "{:.2f} / 5"))
c3.metric("Tasa de recompra", nd(k["recompra"], "{:.2f} %"))

top_n = st.sidebar.slider("Vendedores en el ranking", 5, 50, 10)
vend = consulta(f"SELECT * FROM dw.fn_vendedores_filtrado({F}, %s)", a + (top_n,))
pagos = consulta(f"SELECT * FROM dw.fn_metodos_pago({F})", a)

g1, g2 = st.columns(2)
with g1:
    st.markdown("**Top vendedores por ingresos**")
    if vend.empty:
        st.warning("Sin datos para los filtros seleccionados.")
    else:
        v = vend.head(10).copy()
        v["vendedor"] = v["seller_id"].str[:6] + "…"
        st.plotly_chart(px.bar(v.sort_values("ingresos"), x="ingresos", y="vendedor", orientation="h",
                               labels={"ingresos": "Ingresos (R$)", "vendedor": "Vendedor"}), width="stretch")
with g2:
    st.markdown("**Pedidos por tipo de pago**")
    if pagos.empty:
        st.warning("Sin datos para los filtros seleccionados.")
    else:
        por_tipo = pagos.groupby("tipo_pago", as_index=False)["pedidos"].sum()
        st.plotly_chart(px.bar(por_tipo, x="tipo_pago", y="pedidos",
                               labels={"tipo_pago": "Tipo de pago", "pedidos": "Pedidos"}), width="stretch")

st.markdown("**Ranking de vendedores (ingresos y reputación)**")
st.dataframe(vend, width="stretch", hide_index=True)
st.caption("La calificación de un pedido con varios vendedores se asigna a todos ellos (la reseña es del pedido).")
