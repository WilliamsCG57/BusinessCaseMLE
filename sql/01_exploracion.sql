   -- 01_exploracion.sql
   -- Objetivo: verificar columnas, volumen, rango de fechas y estados de orden

   -- 1. Columnas reales de las tablas usadas
   SELECT table_name, column_name, data_type
   FROM `bussiness-case-tyc.bussiness_case_ecommerce.INFORMATION_SCHEMA.COLUMNS`
   WHERE table_name IN ('users','orders','order_items','products','events')
   ORDER BY table_name, ordinal_position;

   -- 2. Volumen y rango de fechas de órdenes
   SELECT
     COUNT(*)                AS n_ordenes,
     COUNT(DISTINCT user_id) AS n_clientes_con_orden,
     MIN(created_at)         AS primera_orden,
     MAX(created_at)         AS ultima_orden
   FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders`;

   -- 3. Distribución de estados de orden
   SELECT status, COUNT(*) AS n
   FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders`
   GROUP BY status
   ORDER BY n DESC;
