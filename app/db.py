"""Conexión a PostgreSQL y helper de consultas. La app SOLO lee de PostgreSQL (nunca de los CSV)."""
import os
from pathlib import Path

import pandas as pd
import psycopg2
import streamlit as st


def _leer_env():
    """Lee ../.env si existe (mismo archivo que usa docker-compose)."""
    valores = {}
    ruta = Path(__file__).resolve().parent.parent / ".env"
    if ruta.exists():
        for linea in ruta.read_text(encoding="utf-8").splitlines():
            linea = linea.strip()
            if linea and not linea.startswith("#") and "=" in linea:
                k, v = linea.split("=", 1)
                valores[k.strip()] = v.strip()
    return valores


def _config():
    e = _leer_env()
    return dict(
        host=os.getenv("PGHOST", "localhost"),
        port=int(os.getenv("PGPORT", e.get("DB_PORT", "5432"))),
        dbname=os.getenv("PGDATABASE", e.get("POSTGRES_DB", "bi_database")),
        user=os.getenv("PGUSER", e.get("POSTGRES_USER", "bi_user")),
        password=os.getenv("PGPASSWORD", e.get("POSTGRES_PASSWORD", "bi_password")),
    )


@st.cache_data(ttl=300, show_spinner=False)
def consulta(sql: str, params: tuple = ()) -> pd.DataFrame:
    """Ejecuta un SELECT parametrizado en PostgreSQL y devuelve un DataFrame."""
    con = psycopg2.connect(**_config(), connect_timeout=5)
    try:
        with con.cursor() as cur:
            cur.execute(sql, params)
            columnas = [c.name for c in cur.description]
            filas = cur.fetchall()
        df = pd.DataFrame(filas, columns=columnas)
        for c in df.columns:                      # NUMERIC llega como Decimal -> float
            if df[c].dtype == object and len(df) and df[c].map(lambda x: x is None or hasattr(x, "as_tuple")).all():
                df[c] = pd.to_numeric(df[c])
        return df
    finally:
        con.close()


def verificar_conexion():
    """Muestra un error claro y detiene la app si no hay conexión."""
    try:
        consulta("SELECT 1")
    except Exception as exc:
        cfg = _config()
        st.error(f"No se pudo conectar a PostgreSQL en {cfg['host']}:{cfg['port']} (base {cfg['dbname']}).")
        st.info("Enciende la base con `docker compose up -d db` y revisa el puerto en el archivo `.env` (DB_PORT).")
        st.caption(f"Detalle técnico: {exc}")
        st.stop()
