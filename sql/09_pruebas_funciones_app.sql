-- Prueba de las funciones de la aplicación (evidencia).
\echo '--- Variación mensual (K1) ---'
SELECT * FROM dw.fn_variacion_mensual() ORDER BY anio_mes DESC LIMIT 3;
SELECT dw.fn_variacion_ultimo_mes() AS variacion_ultimo_mes_pct;
\echo '--- Funciones con filtros (2017, SP) ---'
SELECT * FROM dw.fn_ventas_estado('2017-01-01','2017-12-31', NULL, 'SP');
SELECT * FROM dw.fn_logistica_estado('2017-01-01','2017-12-31', NULL, NULL) LIMIT 5;
SELECT * FROM dw.fn_retraso_vs_resena('2017-01-01','2017-12-31', NULL, 'SP');
SELECT * FROM dw.fn_metodos_pago('2017-01-01','2017-12-31', NULL, 'SP') LIMIT 5;
SELECT * FROM dw.fn_vendedores_filtrado('2017-01-01','2017-12-31', NULL, 'SP', 5);
SELECT * FROM dw.fn_detalle_ventas('2017-01-01','2017-12-31', NULL, 'SP', 5);
\echo '--- Listas de filtros ---'
SELECT COUNT(*) AS categorias FROM dw.fn_lista_categorias();
SELECT COUNT(*) AS estados FROM dw.fn_lista_estados_cliente();
SELECT * FROM dw.fn_rango_fechas();
