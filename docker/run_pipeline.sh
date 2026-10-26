#!/usr/bin/env bash
# Pipeline completo: limpieza (Python) -> staging -> modelo dimensional -> carga -> validaciones -> vistas/funciones.
# Se ejecuta dentro del contenedor "etl" (variables PG* definidas en docker-compose.yml).
set -euo pipefail
cd "${APP_DIR:-/app}"
mkdir -p evidencias

echo "=== 0/7 Verificando CSV originales en data/raw ==="
faltan=0
for f in olist_orders_dataset olist_order_items_dataset olist_order_payments_dataset olist_order_reviews_dataset \
         olist_customers_dataset olist_sellers_dataset olist_products_dataset olist_geolocation_dataset \
         product_category_name_translation; do
  [ -f "data/raw/$f.csv" ] || { echo "FALTA data/raw/$f.csv"; faltan=1; }
done
[ "$faltan" = "0" ] || { echo "Descarga el dataset de Kaggle y copia los 9 CSV en data/raw/ (ver data/raw/LEEME.md)"; exit 1; }

echo "=== 1/7 Esperando a PostgreSQL ($PGHOST:$PGPORT) ==="
for i in $(seq 1 30); do
  pg_isready -q && break
  [ "$i" = "30" ] && { echo "PostgreSQL no responde en $PGHOST:$PGPORT. Revisa: docker compose ps / docker compose logs db"; exit 1; }
  sleep 2
done

echo "=== 2/7 Limpieza + carga a staging (python/etl_olist.py) ==="
python python/etl_olist.py | tee evidencias/etl_salida.txt

echo "=== 3/7 Modelo dimensional (hechos, dimensiones, PK y FK) ==="
psql -v ON_ERROR_STOP=1 -q -f sql/02_modelo_dimensional.sql

echo "=== 4/7 Carga de dimensiones y tabla de hechos ==="
psql -v ON_ERROR_STOP=1 -q -f sql/03_carga_dimensiones_hechos.sql

echo "=== 5/7 Validaciones ==="
psql -f sql/04_validaciones.sql > evidencias/validaciones.txt 2>&1
echo "    -> evidencias/validaciones.txt"

echo "=== 6/7 Vistas, funciones y pruebas ==="
psql -v ON_ERROR_STOP=1 -q -f sql/05_vistas_funciones.sql
psql -f sql/06_pruebas_objetos.sql > evidencias/pruebas_objetos.txt 2>&1
echo "    -> evidencias/pruebas_objetos.txt"

echo "=== 7/7 Funciones de la app, validaciones extra y pruebas (Entregable 3) ==="
psql -v ON_ERROR_STOP=1 -q -f sql/07_funciones_app.sql
psql -f sql/08_validaciones_extra.sql > evidencias/validaciones_extra.txt 2>&1
psql -f sql/09_pruebas_funciones_app.sql > evidencias/pruebas_funciones_app.txt 2>&1
echo "    -> evidencias/validaciones_extra.txt y evidencias/pruebas_funciones_app.txt"

echo
echo "LISTO. Conectate desde tu PC con: host=localhost  puerto=<DB_PORT, por defecto 5432>  bd=$PGDATABASE  usuario=$PGUSER"
