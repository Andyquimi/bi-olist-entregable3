# BI Olist – Entregable 3: PostgreSQL + Python + Streamlit

```
Kaggle (9 CSV) → Python/pandas (limpieza) → PostgreSQL (Docker) → modelo estrella (dw)
   → vistas/funciones SQL → Python (psycopg2) → Streamlit → dashboard
```
Dataset: [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).
**Granularidad:** una fila de `dw.fact_ventas_item` representa un ítem (producto) vendido dentro de un pedido.

## Ejecución
Requisitos: Docker Desktop abierto, Python 3.10+ y los 9 CSV de Kaggle en `data/raw/` (ver `data/raw/LEEME.md`).

```bash
# 1) (opcional) cambiar puerto/credenciales:  copy .env.example .env
# 2) Base de datos + limpieza + modelo + carga + validaciones + funciones (2–4 min)
docker compose run --rm etl
# 3) Aplicación
cd app
pip install -r requirements.txt
streamlit run app.py          # abre http://localhost:8501
```
La app lee el puerto de `.env` (`DB_PORT`, por defecto 5432). La app **solo consulta PostgreSQL**, nunca los CSV.

Conexión desde pgAdmin: host `localhost`, puerto `DB_PORT`, base `bi_database`, usuario `bi_user`, contraseña `bi_password`.

## Contenido
| Carpeta | Qué contiene |
|---|---|
| `python/etl_olist.py` | Limpieza, transformación y carga a staging |
| `sql/01`–`03` | Staging, modelo dimensional (PK/FK) y carga de dimensiones y hechos |
| `sql/04`, `08` | Consultas de validación (conteos, integridad, nulos, totales, conciliación) |
| `sql/05`, `07` | Vistas y funciones SQL (07 = funciones con filtros para Streamlit) |
| `sql/06`, `09` | Pruebas de los objetos SQL |
| `app/` | Aplicación Streamlit (3 páginas, 3 filtros, 6 gráficos, 3 tablas) |
| `docs/` | Diagrama estrella, log de transformaciones, matriz de trazabilidad, documento final |
| `evidencias/` | Salidas del pipeline (se generan al ejecutar) |

## Resultados esperados (datos reales)
Ítems en hechos 112 279 · ingresos 13 449 529.68 · ticket 137.37 · entrega a tiempo 93.21 % · calificación 4.12 · recompra 3.03 %.

## Problemas frecuentes
| Síntoma | Solución |
|---|---|
| `Cannot connect to the Docker daemon` | Abre Docker Desktop y espera a que esté en ejecución |
| `FALTA data/raw/...csv` | Copia los 9 CSV en `data/raw/` |
| La app dice "No se pudo conectar" | `docker compose up -d db` y revisa `DB_PORT` en `.env` |
| Puerto 5432 ocupado | Pon `DB_PORT=5434` en `.env` |
| `password authentication failed` | `docker compose down -v` y repite el paso 2 (borra datos) |
