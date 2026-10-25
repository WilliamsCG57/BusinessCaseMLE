# BusinessCaseMLE · Recompra a 60 días en The Look

Modelo que estima, en el momento de la primera compra, la probabilidad de que un cliente haga **una nueva orden** en los 60 días siguientes. Incluye la preparación de datos en BigQuery, un pipeline reproducible en Python y el diseño de la arquitectura en AWS.

## Estructura

```
├── sql/
│   ├── 01_exploracion.sql            # columnas, volumen, fechas y estados
│   ├── 02_controles_calidad.sql      # duplicados, nulos, huérfanos, consistencia
│   ├── 03_tabla_base.sql             # tabla 1 fila por cliente (etiqueta + variables)
│   └── 04_validacion_tabla_base.sql  # unicidad, tasa de recompra, conteos
├── notebooks/
│   └── recompra_60d.ipynb            # pipeline de punta a punta (Colab)
├── models/                           # modelo entrenado (.joblib)
├── outputs/                          # gráficos y predicciones (.png, .csv)
├── docs/                             # arquitectura y presentación
└── requirements.txt
```

## Cómo ejecutar

**Google Colab (recomendado)**
1. Abre `notebooks/recompra_60d.ipynb` en Colab.
2. `Entorno de ejecución → Ejecutar todas`. Se pedirá iniciar sesión con una cuenta que tenga acceso al proyecto `bussiness-case-tyc`.
3. Para otra fecha de corte, edita solo la celda **Configuración** (`cutoff_date`).

**Local**
```bash
pip install -r requirements.txt
gcloud auth application-default login
jupyter notebook notebooks/recompra_60d.ipynb
```

No se guardan credenciales en el repositorio: la autenticación es interactiva.

## Definiciones y supuestos

| Tema | Decisión |
|---|---|
| Unidad | 1 fila por cliente con al menos una orden no cancelada |
| Primera compra | Primera orden válida por `created_at` (desempate por `order_id`) |
| Recompra | Otra orden distinta y no cancelada dentro de los 60 días posteriores; se cuenta a nivel orden, no ítem |
| Estados | Se excluye `Cancelled`; `Returned`, `Processing`, `Shipped` y `Complete` cuentan como compra |
| Fuga de información | Solo se usan datos conocidos hasta la primera compra; no se usan estado final, fechas de envío/entrega/devolución ni eventos posteriores |
| Censura | Clientes sin 60 días de historia (`ventana_completa = FALSE`) no se usan para entrenar: se puntúan |
| Fecha de corte | Última orden disponible por defecto (14-feb-2025), configurable |
| Datos personales | No se usan nombre, email, dirección ni coordenadas |
| Eventos anónimos | Sin `user_id` no se atribuyen al cliente (mejora futura: vincular por `session_id`) |

## Modelado

- **Separación temporal**: entrenamiento con cohortes antiguas y prueba con el 20% más reciente, dejando una brecha de 60 días para que las etiquetas de entrenamiento no usen información del período de prueba.
- **Modelos**: azar (tasa base), regresión logística (referencia), HistGradientBoosting y LightGBM. Se elige el de mayor PR AUC en prueba y se reentrena con todos los clientes con ventana completa.
- **Métricas**: PR AUC (principal, por el desbalance) y precision, recall, F1 y lift en el top 5/10/20% de clientes.

## Reproducibilidad

- La tabla base se escribe con `WRITE_TRUNCATE` y las predicciones se reemplazan por `cutoff_date`: reejecutar no duplica resultados.
- Validaciones automáticas detienen el pipeline si hay duplicados, nulos en claves, etiquetas inválidas o tasas fuera de rango.
- `run_pipeline(cfg)` ejecuta todo el flujo en una sola llamada.

## Salidas

- `outputs/muestra_predicciones.csv`: `user_id`, `prob_recompra_60d`
- `outputs/predicciones_<corte>.csv`: además, decil, segmento de prioridad y versión del modelo
- `models/modelo_recompra_<corte>.joblib`: modelo y metadatos (variables, corte, métricas)
- Tabla `bussiness-case-tyc.williams_ccompi.predicciones_recompra`, particionada por `cutoff_date`
