-- =====================================================================
-- 07_funciones_app.sql   (ENTREGABLE 3)
-- Funciones con filtros para la aplicación Streamlit. Convierten en
-- funciones parametrizadas las vistas que ignoraban los filtros y agregan
-- la variación mensual (tarjeta K1) y las listas para los filtros.
-- Parámetros comunes: desde, hasta, categoría (categoria_en), estado del
-- cliente (p. ej. 'SP'). NULL = sin filtro.
-- =====================================================================

-- Ventas por región/estado del cliente  (antes: v_ventas_estado)
CREATE OR REPLACE FUNCTION dw.fn_ventas_estado(p_desde DATE DEFAULT NULL, p_hasta DATE DEFAULT NULL,
        p_categoria TEXT DEFAULT NULL, p_estado_cliente CHAR(2) DEFAULT NULL)
RETURNS TABLE (region TEXT, estado TEXT, pedidos BIGINT, ingresos NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT c.region::text, c.estado::text, COUNT(*), ROUND(SUM(b.ingresos), 2)
    FROM dw.fn_base_pedidos(p_desde, p_hasta, p_categoria, p_estado_cliente) b
    JOIN dw.dim_cliente c ON c.cliente_key = b.cliente_key
    GROUP BY c.region, c.estado
    ORDER BY 4 DESC
$$;

-- Logística por estado del cliente, solo pedidos entregados  (antes: v_logistica_estado)
CREATE OR REPLACE FUNCTION dw.fn_logistica_estado(p_desde DATE DEFAULT NULL, p_hasta DATE DEFAULT NULL,
        p_categoria TEXT DEFAULT NULL, p_estado_cliente CHAR(2) DEFAULT NULL)
RETURNS TABLE (estado TEXT, pedidos_entregados BIGINT, dias_entrega_prom NUMERIC,
               pct_entrega_a_tiempo NUMERIC, dias_retraso_prom NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT c.estado::text, COUNT(*), ROUND(AVG(b.dias_entrega), 1),
           ROUND(100.0 * AVG(b.entrega_a_tiempo), 2), ROUND(AVG(b.dias_retraso), 2)
    FROM dw.fn_base_pedidos(p_desde, p_hasta, p_categoria, p_estado_cliente) b
    JOIN dw.dim_cliente c ON c.cliente_key = b.cliente_key
    WHERE b.entregado
    GROUP BY c.estado
    ORDER BY 4
$$;

-- Efecto del retraso en la calificación (P3)  (antes: v_retraso_vs_resena)
CREATE OR REPLACE FUNCTION dw.fn_retraso_vs_resena(p_desde DATE DEFAULT NULL, p_hasta DATE DEFAULT NULL,
        p_categoria TEXT DEFAULT NULL, p_estado_cliente CHAR(2) DEFAULT NULL)
RETURNS TABLE (rango_retraso TEXT, pedidos BIGINT, calificacion_prom NUMERIC, pct_resenas_1_2 NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT CASE WHEN dias_retraso = 0 THEN '1. A tiempo'
                WHEN dias_retraso <= 3 THEN '2. 1-3 días tarde'
                WHEN dias_retraso <= 7 THEN '3. 4-7 días tarde'
                ELSE '4. Más de 7 días tarde' END,
           COUNT(*), ROUND(AVG(review_score), 2),
           ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2) / NULLIF(COUNT(review_score), 0), 2)
    FROM dw.fn_base_pedidos(p_desde, p_hasta, p_categoria, p_estado_cliente)
    WHERE entregado AND review_score IS NOT NULL
    GROUP BY 1 ORDER BY 1
$$;

-- Medios de pago (P5)  (antes: v_metodos_pago)
CREATE OR REPLACE FUNCTION dw.fn_metodos_pago(p_desde DATE DEFAULT NULL, p_hasta DATE DEFAULT NULL,
        p_categoria TEXT DEFAULT NULL, p_estado_cliente CHAR(2) DEFAULT NULL)
RETURNS TABLE (tipo_pago TEXT, grupo_cuotas TEXT, pedidos BIGINT, ingresos NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT g.tipo_pago::text, g.grupo_cuotas::text, COUNT(DISTINCT f.order_id), ROUND(SUM(f.price), 2)
    FROM dw.fact_ventas_item f
    JOIN dw.dim_fecha d         ON d.fecha_key = f.fecha_compra_key
    JOIN dw.dim_estado_pedido e ON e.estado_key = f.estado_key AND e.es_ingreso_valido
    JOIN dw.dim_pago g          ON g.pago_key = f.pago_key
    JOIN dw.dim_producto p      ON p.producto_key = f.producto_key
    JOIN dw.dim_cliente c       ON c.cliente_key = f.cliente_key
    WHERE (p_desde IS NULL OR d.fecha >= p_desde) AND (p_hasta IS NULL OR d.fecha <= p_hasta)
      AND (p_categoria IS NULL OR p.categoria_en = p_categoria)
      AND (p_estado_cliente IS NULL OR c.estado = p_estado_cliente)
    GROUP BY g.tipo_pago, g.grupo_cuotas, g.orden_cuotas
    ORDER BY g.tipo_pago, g.orden_cuotas
$$;

-- Variación de ingresos mes a mes (tarjeta K1: "vs. mes anterior")
CREATE OR REPLACE FUNCTION dw.fn_variacion_mensual(p_desde DATE DEFAULT NULL, p_hasta DATE DEFAULT NULL,
        p_categoria TEXT DEFAULT NULL, p_estado_cliente CHAR(2) DEFAULT NULL)
RETURNS TABLE (anio_mes TEXT, ingresos NUMERIC, variacion_pct NUMERIC)
LANGUAGE sql STABLE AS $$
    WITH m AS (
        SELECT to_char(fecha_compra, 'YYYY-MM') AS am, SUM(ingresos) AS ing
        FROM dw.fn_base_pedidos(p_desde, p_hasta, p_categoria, p_estado_cliente) GROUP BY 1)
    SELECT am, ROUND(ing, 2),
           ROUND(100.0 * (ing - LAG(ing) OVER (ORDER BY am)) / NULLIF(LAG(ing) OVER (ORDER BY am), 0), 2)
    FROM m ORDER BY am
$$;

-- Variación del último mes del rango frente al mes anterior (un solo número)
CREATE OR REPLACE FUNCTION dw.fn_variacion_ultimo_mes(p_desde DATE DEFAULT NULL, p_hasta DATE DEFAULT NULL,
        p_categoria TEXT DEFAULT NULL, p_estado_cliente CHAR(2) DEFAULT NULL)
RETURNS NUMERIC LANGUAGE sql STABLE AS $$
    SELECT v.variacion_pct
    FROM dw.fn_variacion_mensual(p_desde, p_hasta, p_categoria, p_estado_cliente) v
    ORDER BY v.anio_mes DESC LIMIT 1
$$;

-- Ranking de vendedores respetando TODOS los filtros (reemplaza a fn_ranking_vendedores en la app)
CREATE OR REPLACE FUNCTION dw.fn_vendedores_filtrado(p_desde DATE DEFAULT NULL, p_hasta DATE DEFAULT NULL,
        p_categoria TEXT DEFAULT NULL, p_estado_cliente CHAR(2) DEFAULT NULL, p_top INT DEFAULT 20)
RETURNS TABLE (seller_id TEXT, estado TEXT, ciudad TEXT, pedidos BIGINT, ingresos NUMERIC,
               calificacion_prom NUMERIC, pct_entregas_tarde NUMERIC)
LANGUAGE sql STABLE AS $$
    WITH por_pedido AS (          -- un registro por (vendedor, pedido)
        SELECT f.vendedor_key, f.order_id, SUM(f.price) AS ingresos,
               MAX(f.review_score) AS review, MAX(f.entrega_a_tiempo) AS a_tiempo
        FROM dw.fact_ventas_item f
        JOIN dw.dim_fecha d         ON d.fecha_key = f.fecha_compra_key
        JOIN dw.dim_estado_pedido e ON e.estado_key = f.estado_key AND e.es_ingreso_valido
        JOIN dw.dim_producto p      ON p.producto_key = f.producto_key
        JOIN dw.dim_cliente c       ON c.cliente_key = f.cliente_key
        WHERE (p_desde IS NULL OR d.fecha >= p_desde) AND (p_hasta IS NULL OR d.fecha <= p_hasta)
          AND (p_categoria IS NULL OR p.categoria_en = p_categoria)
          AND (p_estado_cliente IS NULL OR c.estado = p_estado_cliente)
        GROUP BY f.vendedor_key, f.order_id)
    SELECT v.seller_id::text, v.estado::text, v.ciudad::text, COUNT(*), ROUND(SUM(pp.ingresos), 2),
           ROUND(AVG(pp.review), 2),
           ROUND(100.0 * COUNT(*) FILTER (WHERE pp.a_tiempo = 0) / NULLIF(COUNT(pp.a_tiempo), 0), 2)
    FROM por_pedido pp JOIN dw.dim_vendedor v ON v.vendedor_key = pp.vendedor_key
    GROUP BY v.seller_id, v.estado, v.ciudad
    ORDER BY 5 DESC LIMIT p_top
$$;

-- Detalle de ítems (tabla drill-down) con filtros
CREATE OR REPLACE FUNCTION dw.fn_detalle_ventas(p_desde DATE DEFAULT NULL, p_hasta DATE DEFAULT NULL,
        p_categoria TEXT DEFAULT NULL, p_estado_cliente CHAR(2) DEFAULT NULL, p_limite INT DEFAULT 200)
RETURNS TABLE (order_id TEXT, fecha_compra DATE, estado_pedido TEXT, categoria TEXT, estado_cliente TEXT,
               seller_id TEXT, tipo_pago TEXT, price NUMERIC, freight_value NUMERIC,
               dias_entrega NUMERIC, dias_retraso SMALLINT, review_score SMALLINT)
LANGUAGE sql STABLE AS $$
    SELECT f.order_id::text, d.fecha, e.estado_es::text, p.categoria_en::text, c.estado::text,
           v.seller_id::text, g.tipo_pago::text, f.price::numeric, f.freight_value::numeric,
           f.dias_entrega::numeric, f.dias_retraso, f.review_score
    FROM dw.fact_ventas_item f
    JOIN dw.dim_fecha d         ON d.fecha_key = f.fecha_compra_key
    JOIN dw.dim_estado_pedido e ON e.estado_key = f.estado_key
    JOIN dw.dim_producto p      ON p.producto_key = f.producto_key
    JOIN dw.dim_cliente c       ON c.cliente_key = f.cliente_key
    JOIN dw.dim_vendedor v      ON v.vendedor_key = f.vendedor_key
    JOIN dw.dim_pago g          ON g.pago_key = f.pago_key
    WHERE (p_desde IS NULL OR d.fecha >= p_desde) AND (p_hasta IS NULL OR d.fecha <= p_hasta)
      AND (p_categoria IS NULL OR p.categoria_en = p_categoria)
      AND (p_estado_cliente IS NULL OR c.estado = p_estado_cliente)
    ORDER BY d.fecha DESC, f.order_id, f.order_item_id
    LIMIT p_limite
$$;

-- Listas para poblar los filtros de la aplicación
CREATE OR REPLACE FUNCTION dw.fn_lista_categorias() RETURNS SETOF TEXT LANGUAGE sql STABLE AS $$
    SELECT DISTINCT categoria_en::text FROM dw.dim_producto ORDER BY 1 $$;

CREATE OR REPLACE FUNCTION dw.fn_lista_estados_cliente() RETURNS SETOF TEXT LANGUAGE sql STABLE AS $$
    SELECT DISTINCT estado::text FROM dw.dim_cliente WHERE estado IS NOT NULL ORDER BY 1 $$;

CREATE OR REPLACE FUNCTION dw.fn_rango_fechas() RETURNS TABLE (fecha_min DATE, fecha_max DATE)
LANGUAGE sql STABLE AS $$
    SELECT MIN(d.fecha), MAX(d.fecha)
    FROM dw.fact_ventas_item f JOIN dw.dim_fecha d ON d.fecha_key = f.fecha_compra_key $$;
