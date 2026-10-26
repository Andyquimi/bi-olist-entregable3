-- =====================================================================
-- 08_validaciones_extra.sql   (ENTREGABLE 3)
-- Coherencia entre datos originales y datos cargados: explica la diferencia
-- entre pedidos en staging y pedidos en la tabla de hechos.
-- =====================================================================

-- Pedidos en staging vs pedidos en hechos (los que no tienen ítems no generan filas de hecho)
SELECT (SELECT COUNT(*) FROM stg.pedidos)                                AS pedidos_staging,
       (SELECT COUNT(DISTINCT order_id) FROM dw.fact_ventas_item)         AS pedidos_en_hechos,
       (SELECT COUNT(*) FROM stg.pedidos)
         - (SELECT COUNT(DISTINCT order_id) FROM dw.fact_ventas_item)     AS pedidos_sin_items;

-- ¿Qué estados tienen esos pedidos sin ítems?
SELECT o.order_status, COUNT(*) AS pedidos_sin_items
FROM stg.pedidos o
WHERE NOT EXISTS (SELECT 1 FROM stg.items i WHERE i.order_id = o.order_id)
GROUP BY o.order_status ORDER BY 2 DESC;

-- Ingresos brutos (todos los estados) vs ingresos de negocio (sin cancelados / no disponibles)
SELECT ROUND(SUM(f.price), 2)                                            AS ingresos_brutos,
       ROUND(SUM(f.price) FILTER (WHERE e.es_ingreso_valido), 2)         AS ingresos_validos,
       ROUND(SUM(f.price) FILTER (WHERE NOT e.es_ingreso_valido), 2)     AS excluidos_cancelados
FROM dw.fact_ventas_item f JOIN dw.dim_estado_pedido e USING (estado_key);

-- La suma de la función KPI debe coincidir con la suma directa sobre los hechos
SELECT dw.fn_total_ventas() AS desde_funcion,
       (SELECT ROUND(SUM(f.price), 2) FROM dw.fact_ventas_item f
        JOIN dw.dim_estado_pedido e USING (estado_key) WHERE e.es_ingreso_valido) AS desde_hechos;
