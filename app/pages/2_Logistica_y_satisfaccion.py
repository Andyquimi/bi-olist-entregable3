"""Página 2 · Logística y satisfacción  (preguntas P2 y P3)."""
import plotly.express as px
import streamlit as st

from db import consulta
from filtros import FILTROS_SQL as F, args, resumen, sidebar_filtros

st.set_page_config(page_title="BI Olist · Logística", page_icon="🚚", layout="wide")
st.title("🚚 2 · Logística y satisfacción")

desde, hasta, cat, est = sidebar_filtros()
a = args(desde, hasta, cat, est)
st.caption(resumen(desde, hasta, cat, est))

# ---- KPI (K4, K5, K6) ----
k = consulta(f"""SELECT dw.fn_tasa_entrega_a_tiempo({F}) AS a_tiempo, dw.fn_tiempo_promedio_entrega({F}) AS dias,
                        dw.fn_calificacion_promedio({F}) AS calificacion""", a * 3).iloc[0]
nd = lambda v, f: "—" if v != v or v is None else f.format(v)
c1, c2, c3 = st.columns(3)
c1.metric("Entrega a tiempo", nd(k["a_tiempo"], "{:.2f} %"))
c2.metric("Tiempo promedio de entrega", nd(k["dias"], "{:.1f} días"))
c3.metric("Calificación promedio", nd(k["calificacion"], "{:.2f} / 5"))

# ---- Gráficos (G3, G4) ----
g1, g2 = st.columns(2)
log = consulta(f"SELECT * FROM dw.fn_logistica_estado({F})", a)
with g1:
    st.markdown("**% de entrega a tiempo por estado (peores 10)**")
    if log.empty:
        st.warning("Sin pedidos entregados para los filtros seleccionados.")
    else:
        st.plotly_chart(px.bar(log.head(10), x="estado", y="pct_entrega_a_tiempo",
                               labels={"pct_entrega_a_tiempo": "% a tiempo", "estado": "Estado"}), width="stretch")
ret = consulta(f"SELECT * FROM dw.fn_retraso_vs_resena({F})", a)
with g2:
    st.markdown("**Calificación promedio según el retraso de la entrega**")
    if ret.empty:
        st.warning("Sin datos para los filtros seleccionados.")
    else:
        st.plotly_chart(px.bar(ret, x="rango_retraso", y="calificacion_prom",
                               labels={"rango_retraso": "Retraso", "calificacion_prom": "Calificación"}), width="stretch")

# ---- Tabla de detalle (T2) ----
st.markdown("**Detalle de ítems vendidos (respeta los filtros)**")
limite = st.slider("Filas a mostrar", 50, 1000, 200, step=50)
st.dataframe(consulta(f"SELECT * FROM dw.fn_detalle_ventas({F}, %s)", a + (limite,)),
             width="stretch", hide_index=True)
