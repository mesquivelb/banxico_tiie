# TIIE Pass-Through Project

Proyecto de Analytics Engineering enfocado en la resolución de un problema de negocio mediante un proceso integral de ingesta, almacenamiento y modelado de datos usando star schema, con dashboard interactivo como entregable final.

## 1. Problema de negocio

Partiendo de series históricas diarias del Banco de México (Banxico) sobre tasas de interés de referencia (2008–2026), el objetivo fue medir qué tan rápido y con qué magnitud el mercado de dinero mexicano transmite un cambio en la Tasa Objetivo hacia la TIIE 28 días — la tasa que los bancos usan como base para fijar crédito al consumidor —, y si esa velocidad de transmisión ("pass-through") ha cambiado a lo largo de las décadas.

**Dataset:**
- Fuente: [Banco de México — Sistema de Información Económica (SIE)](https://www.banxico.org.mx)
- Registros: 6,666 filas (una por día calendario)
- Series incluidas: TIIE 28, 91 y 182 días; Tasa de Fondeo a un día; Tasas de Fondeo Bancario y Gubernamental; Tasa Objetivo
- Periodo cubierto: enero 2008 – julio 2026

## 2. Arquitectura de la solución

El flujo de datos sigue 5 etapas: ingesta del CSV, almacenamiento en BigQuery, transformación con dbt, modelado dimensional (star schema) y visualización en Power BI.

```
CSV (Banxico) → BigQuery [raw] → dbt [staging] → dbt [marts] → Power BI
```

## 3. Stack tecnológico

| Etapa | Herramienta |
|---|---|
| Ingesta y almacenamiento | Google BigQuery |
| Transformación | dbt (Data Build Tool) |
| Visualización | Power BI |
| Versionamiento | Git & GitHub |

## 4. Modelado 

El proyecto implementa una estructura modular en dbt siguiendo el patrón staging → marts:

- **Modelado dimensional:** tabla de hechos (`fact_tasas_diarias`) y dimensiones (`dim_fecha`, `dim_evento_politica_monetaria`) para consultas eficientes, más un mart agregado (`mart_pass_through_tiie`) como entregable final de la pregunta de negocio.
- **Grano de la fact table:** una fila representa un día calendario, identificado por `id_fecha` (formato `YYYYMMDD`), con las tasas vigentes de ese día ya limpias y tipadas.
- **Lógica de negocio:** uso de window functions (`LAG`, `LAST_VALUE ... IGNORE NULLS`, `QUALIFY ROW_NUMBER()`) para detectar eventos de política monetaria, rellenar huecos de fin de semana en tasas "escalón", y medir la velocidad de convergencia de la TIIE tras cada decisión de Banxico.
- **Decisión de diseño — carga cruda como `STRING`:** la tabla `raw` se carga sin autodetección de tipos, porque el archivo original mezcla valores numéricos con el texto `"N/E"` (no disponible en fines de semana/festivos); el tipado correcto (`SAFE_CAST` a `FLOAT64`) se resuelve explícitamente en `staging`, evitando que la carga falle o infiera tipos incorrectos.
- **Decisión de diseño — métrica de pass-through al 85%:** una primera definición de "convergencia" (TIIE alcanza exactamente la nueva Tasa Objetivo) resultó inválida para recortes, porque el spread natural de mercado (~0.31 puntos porcentuales) impide que la TIIE baje hasta igualar la tasa. Se adoptó la métrica estándar de pass-through (captura del 85% del movimiento), que funciona simétricamente para alzas y recortes.
- **Calidad de datos:** tests de dbt (`not_null`, `accepted_values`) sobre las tasas en `staging`, y verificación cruzada del máximo histórico de la Tasa Objetivo (11.25%, marzo 2023–marzo 2024) contra fuentes públicas.
- <img width="1279" height="583" alt="image" src="https://github.com/user-attachments/assets/a1bee12c-1d55-4fd1-a3c2-03621fcc0ce5" />


## 5. Visualización

El dashboard permite:
- **KPIs centrales:** TIIE 28 actual, spread actual (TIIE 28 vs. Tasa Objetivo), promedio de días de pass-through, y número de eventos de política monetaria en los últimos 12 meses.
- **Análisis histórico:** gráfico de línea de TIIE 28 y Tasa Objetivo (2008–2026) con slicer de rango de años.
- **Comparación por período:** gráfico de barras de días promedio de pass-through, segmentado por década y por dirección (alza/recorte).
- **Exploración de eventos:** tabla de decisiones recientes de política monetaria, con magnitud del cambio y contexto macroeconómico asociado.
- <img width="866" height="491" alt="image" src="https://github.com/user-attachments/assets/a6513fbc-d4f8-43d6-94b7-eff324ae2850" />


## 6. Desafíos de calidad de datos

- **Encoding del archivo fuente:** el CSV de Banxico viene en `ISO-8859-1`, no UTF-8, lo que rompía los nombres de columna con acentos (`T�tulo`). Se resolvió especificando el encoding correcto al momento de la carga a BigQuery.
- **Metadata mezclada con los datos:** las primeras 19 filas del archivo son encabezado descriptivo (nombre de la institución, período, claves de serie), no datos. Se resolvió con `skip_leading_rows` en la configuración de carga.
- **Valores no disponibles (`N/E`) en fines de semana y festivos:** no representan un error, sino la ausencia normal de operación bancaria esos días. Se documentó explícitamente y se manejó con `SAFE_CAST(NULLIF(...))` en staging, en vez de tratarlos como datos faltantes a imputar arbitrariamente.
- **Tasa Objetivo como serie "escalón":** al publicarse incluso en días no hábiles manteniendo su último valor vigente, requirió forward-fill (`LAST_VALUE ... IGNORE NULLS`) para tener una serie continua comparable día a día contra la TIIE.

## 7. Métrica de negocio: pass-through de política monetaria

Para responder la pregunta de negocio, se definió el "pass-through al 85%": el número de días que tarda la TIIE 28 en capturar al menos el 85% del movimiento de un cambio en la Tasa Objetivo, contado desde la fecha del evento.

```sql
-- models/marts/mart_pass_through_tiie.sql (extracto)
SELECT
  decada,
  direccion,
  COUNT(*) AS n_eventos,
  ROUND(AVG(DATE_DIFF(fecha_convergencia, fecha_evento, DAY)), 1) AS dias_promedio_pass_through_85pct
FROM convergencia
GROUP BY decada, direccion
ORDER BY decada, direccion
```

**Hallazgos principales:**
- Correlación TIIE 28 vs. Tasa Objetivo: **0.9994** — transmisión prácticamente inmediata.
- El mercado transmite **alzas más rápido que recortes** en todas las décadas analizadas (rigidez a la baja).
- La velocidad de pass-through mejoró en la década de 2020 frente a 2010, con menor proporción de eventos sin convergencia en la ventana de 90 días.

## Cómo correr el proyecto

```bash
cd dbt-project/tiie_pass_through_project
dbt deps
dbt run
dbt test
```
