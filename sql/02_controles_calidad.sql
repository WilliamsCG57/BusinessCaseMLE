-- 02_controles_calidad.sql
-- Objetivo: detectar duplicados, nulos en claves, registros sin correspondencia e inconsistencias
-- Resultado esperado: n = 0 en la mayoría de controles; los que no den 0 se documentan y se tratan en 03_tabla_base.sql

-- A. Duplicados en claves primarias
SELECT 'A1_orders_dup' AS control, COUNT(*) - COUNT(DISTINCT order_id) AS n
FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders`
UNION ALL
SELECT 'A2_order_items_dup', COUNT(*) - COUNT(DISTINCT id)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.order_items`
UNION ALL
SELECT 'A3_users_dup', COUNT(*) - COUNT(DISTINCT id)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.users`
UNION ALL
SELECT 'A4_products_dup', COUNT(*) - COUNT(DISTINCT id)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.products`

-- B. Nulos en campos clave
UNION ALL
SELECT 'B1_orders_user_o_fecha_nulos', COUNTIF(user_id IS NULL OR created_at IS NULL)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders`
UNION ALL
SELECT 'B2_items_orden_o_producto_nulos', COUNTIF(order_id IS NULL OR product_id IS NULL)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.order_items`
UNION ALL
SELECT 'B3_items_precio_nulo_o_negativo', COUNTIF(sale_price IS NULL OR sale_price < 0)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.order_items`
UNION ALL
SELECT 'B4_events_sin_user (anonimos)', COUNTIF(user_id IS NULL)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.events`

-- C. Registros huérfanos: registros sin correspondencia entre tablas (integridad referencial), por ejemplo ítems sin orden.
UNION ALL
SELECT 'C1_orders_sin_user', COUNT(*)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders` o
LEFT JOIN `bussiness-case-tyc.bussiness_case_ecommerce.users` u ON o.user_id = u.id
WHERE u.id IS NULL
UNION ALL
SELECT 'C2_items_sin_orden', COUNT(*)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.order_items` i
LEFT JOIN `bussiness-case-tyc.bussiness_case_ecommerce.orders` o ON i.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'C3_items_sin_producto', COUNT(*)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.order_items` i
LEFT JOIN `bussiness-case-tyc.bussiness_case_ecommerce.products` p ON i.product_id = p.id
WHERE p.id IS NULL
UNION ALL
SELECT 'C4_orders_sin_items', COUNT(*)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders` o
LEFT JOIN (SELECT DISTINCT order_id FROM `bussiness-case-tyc.bussiness_case_ecommerce.order_items`) i
  ON o.order_id = i.order_id
WHERE i.order_id IS NULL

-- D. Consistencia entre tablas: por ejemplo, que num_of_item cuadre con el conteo real de ítems.
UNION ALL
SELECT 'D1_item_user_distinto_a_orden', COUNT(*)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.order_items` i
JOIN `bussiness-case-tyc.bussiness_case_ecommerce.orders` o ON i.order_id = o.order_id
WHERE i.user_id != o.user_id
UNION ALL
SELECT 'D2_num_of_item_no_cuadra', COUNT(*)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders` o
JOIN (SELECT order_id, COUNT(*) AS n_items
      FROM `bussiness-case-tyc.bussiness_case_ecommerce.order_items` GROUP BY order_id) i
  ON o.order_id = i.order_id
WHERE o.num_of_item != i.n_items
UNION ALL
SELECT 'D3_orden_antes_del_registro', COUNT(*)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders` o
JOIN `bussiness-case-tyc.bussiness_case_ecommerce.users` u ON o.user_id = u.id
WHERE o.created_at < u.created_at
ORDER BY control;
