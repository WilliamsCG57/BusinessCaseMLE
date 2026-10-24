-- 04_validacion_tabla_base.sql
SELECT
  COUNT(*)                                   AS n_filas,
  COUNT(DISTINCT user_id)                    AS n_clientes,          -- debe ser = n_filas
  COUNTIF(ventana_completa)                  AS n_entrenamiento,
  COUNTIF(NOT ventana_completa)              AS n_a_puntuar,
  ROUND(AVG(IF(ventana_completa, label_recompra_60d, NULL)) * 100, 2) AS tasa_recompra_pct,
  COUNTIF(n_items IS NULL)                   AS sin_items,           -- debe ser 0
  COUNTIF(n_events_pre = 0)                  AS sin_eventos_previos,
  MIN(first_order_date)                      AS min_fecha,
  MAX(first_order_date)                      AS max_fecha
FROM `bussiness-case-tyc.williams_ccompi.base_recompra`;
