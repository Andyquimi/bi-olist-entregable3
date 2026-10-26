"""Filtros globales (fecha, categoría, estado del cliente). Se alimentan de funciones SQL y se
conservan al cambiar de página."""
import datetime as dt

import streamlit as st

from db import consulta, verificar_conexion

TODAS, TODOS = "Todas", "Todos"


def _recordar(clave, defecto):
    """Evita que Streamlit olvide el valor del widget al cambiar de página."""
    st.session_state[clave] = st.session_state.get(clave, defecto)


def sidebar_filtros():
    """Dibuja los filtros y devuelve (desde, hasta, categoria, estado); None = sin filtro."""
    verificar_conexion()
    rango = consulta("SELECT * FROM dw.fn_rango_fechas()").iloc[0]
    fmin, fmax = rango["fecha_min"], rango["fecha_max"]
    categorias = [TODAS] + consulta("SELECT * FROM dw.fn_lista_categorias()").iloc[:, 0].tolist()
    estados = [TODOS] + consulta("SELECT * FROM dw.fn_lista_estados_cliente()").iloc[:, 0].tolist()

    _recordar("f_fechas", (fmin, fmax))
    _recordar("f_cat", TODAS)
    _recordar("f_est", TODOS)

    st.sidebar.header("Filtros")
    fechas = st.sidebar.date_input("Rango de fechas de compra", min_value=fmin, max_value=fmax, key="f_fechas")
    categoria = st.sidebar.selectbox("Categoría de producto", categorias, key="f_cat")
    estado = st.sidebar.selectbox("Estado del cliente", estados, key="f_est")
    if st.sidebar.button("Limpiar filtros"):
        for k in ("f_fechas", "f_cat", "f_est"):
            st.session_state.pop(k, None)
        st.rerun()

    if not isinstance(fechas, (tuple, list)) or len(fechas) != 2:
        st.info("Selecciona la fecha inicial y la final en el filtro de la izquierda.")
        st.stop()
    desde, hasta = fechas
    return (desde, hasta,
            None if categoria == TODAS else categoria,
            None if estado == TODOS else estado)


def resumen(desde, hasta, categoria, estado):
    return (f"Filtros activos: {desde:%d/%m/%Y} – {hasta:%d/%m/%Y} · "
            f"categoría: {categoria or 'todas'} · estado del cliente: {estado or 'todos'}")


def args(desde, hasta, categoria, estado):
    """Parámetros para llamar a las funciones SQL."""
    return (desde, hasta, categoria, estado)


FILTROS_SQL = "%s::date, %s::date, %s::text, %s::char(2)"
