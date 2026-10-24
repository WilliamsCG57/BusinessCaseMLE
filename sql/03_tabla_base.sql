-- 03_tabla_base.sql
-- Tabla base del modelo: 1 fila por cliente con primera compra válida
-- Etiqueta: 1 si el cliente tiene otra orden distinta (no cancelada) dentro de los 60 días siguientes a su primera compra
-- Variables: solo información disponible hasta la fecha de la primera compra (sin fuga de información)
-- Decisiones: se excluyen órdenes Cancelled; Returned/Processing/Shipped/Complete cuentan como compra
-- Censura: ventana_completa = FALSE para clientes sin 60 días de historia (no se usan para entrenar; se puntúan)

DECLARE window_days INT64 DEFAULT 60;
DECLARE cutoff_ts TIMESTAMP DEFAULT (
  SELECT MAX(created_at) FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders`);

CREATE OR REPLACE TABLE `bussiness-case-tyc.williams_ccompi.base_recompra`
PARTITION BY DATE_TRUNC(first_order_date, MONTH)
CLUSTER BY user_id AS
WITH users_clean AS (            -- 1 fila por usuario; solo columnas no sensibles
  SELECT id AS user_id, age, gender, country, traffic_source, created_at AS signup_ts
  FROM `bussiness-case-tyc.bussiness_case_ecommerce.users`
  WHERE id IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY created_at) = 1
),
orders_valid AS (                -- 1 fila por orden válida hasta la fecha de corte
  SELECT order_id, user_id, created_at
  FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders`
  WHERE status != 'Cancelled'
    AND user_id IS NOT NULL AND created_at IS NOT NULL
    AND created_at <= cutoff_ts
  QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY created_at) = 1
),
ranked AS (                      -- orden cronológico de compras por cliente
  SELECT *, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at, order_id) AS rn
  FROM orders_valid
),
first_order AS (                 -- 1 fila por cliente
  SELECT user_id, order_id AS first_order_id, created_at AS first_order_ts
  FROM ranked
  WHERE rn = 1
),
label AS (                       -- etiqueta a nivel ORDEN (no ítem)
  SELECT f.user_id, COUNT(DISTINCT r.order_id) AS n_orders_60d
  FROM first_order f
  LEFT JOIN ranked r
    ON r.user_id = f.user_id
   AND r.rn > 1
   AND r.created_at <= TIMESTAMP_ADD(f.first_order_ts, INTERVAL window_days DAY)
  GROUP BY f.user_id
),
first_items AS (                 -- ítems de la primera orden agregados ANTES de unir
  SELECT i.order_id,
    COUNT(*)                   AS n_items,
    SUM(i.sale_price)          AS order_value,
    AVG(i.sale_price)          AS avg_item_price,
    COUNT(DISTINCT p.category) AS n_categories,
    APPROX_TOP_COUNT(p.category, 1)[SAFE_OFFSET(0)].value   AS main_category,
    APPROX_TOP_COUNT(p.department, 1)[SAFE_OFFSET(0)].value AS main_department
  FROM `bussiness-case-tyc.bussiness_case_ecommerce.order_items` i
  JOIN first_order f ON i.order_id = f.first_order_id
  LEFT JOIN `bussiness-case-tyc.bussiness_case_ecommerce.products` p ON i.product_id = p.id
  GROUP BY i.order_id
),
pre_events AS (                  -- navegación identificada HASTA la primera compra
  SELECT e.user_id,
    COUNT(*)                          AS n_events_pre,
    COUNT(DISTINCT e.session_id)      AS n_sessions_pre,
    COUNTIF(e.event_type = 'product') AS n_product_views_pre,
    COUNTIF(e.event_type = 'cart')    AS n_cart_pre
  FROM `bussiness-case-tyc.bussiness_case_ecommerce.events` e
  JOIN first_order f ON e.user_id = f.user_id
  WHERE e.created_at <= f.first_order_ts
  GROUP BY e.user_id
)
SELECT
  f.user_id,
  f.first_order_id,
  f.first_order_ts,
  DATE(f.first_order_ts) AS first_order_date,
  u.age, u.gender, u.country, u.traffic_source,
  DATE_DIFF(DATE(f.first_order_ts), DATE(u.signup_ts), DAY) AS days_signup_to_first_order,
  EXTRACT(DAYOFWEEK FROM f.first_order_ts) AS first_order_dow,
  EXTRACT(MONTH FROM f.first_order_ts)     AS first_order_month,
  fi.n_items, fi.order_value, fi.avg_item_price, fi.n_categories,
  fi.main_category, fi.main_department,
  IFNULL(pe.n_events_pre, 0)        AS n_events_pre,
  IFNULL(pe.n_sessions_pre, 0)      AS n_sessions_pre,
  IFNULL(pe.n_product_views_pre, 0) AS n_product_views_pre,
  IFNULL(pe.n_cart_pre, 0)          AS n_cart_pre,
  IF(l.n_orders_60d > 0, 1, 0)      AS label_recompra_60d,
  f.first_order_ts <= TIMESTAMP_SUB(cutoff_ts, INTERVAL window_days DAY) AS ventana_completa
FROM first_order f
JOIN users_clean u USING (user_id)
JOIN label l       USING (user_id)
LEFT JOIN first_items fi ON fi.order_id = f.first_order_id
LEFT JOIN pre_events pe  USING (user_id);
