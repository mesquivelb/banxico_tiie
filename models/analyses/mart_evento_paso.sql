with tasas as (SELECT
fecha, tiie_a_28_dias, tasa_objetivo
from {{ref('staging_tiie')}}),

tasas_ff as (
    select fecha,
    last_value(tiie_a_28_dias IGNORE NULLS) over (order by fecha 
    rows between unbounded preceding and current row) as tiie_28_ff,
    last_value(tasa_objetivo ignore nulls) over (order by fecha
    rows between unbounded preceding and current row) as t_objetivo_ff
    from tasas
),

eventos_base as( SELECT
    fecha as fecha_evento,
    tasa_objetivo,
    lag(tasa_objetivo) over (order by fecha) as tasa_anterior
    from tasas
    where tasa_objetivo is not NULL
),
eventos as( SELECT
    fecha_evento,
    tasa_anterior,
    tasa_objetivo as tasa_nueva,
    tasa_objetivo-tasa_anterior as movimiento,
    case when tasa_objetivo>tasa_anterior then 'alza' else 'recorte' end as direccion,
    div(extract(year from fecha_evento),10)*10 as decada
    from eventos_base
    where tasa_objetivo != tasa_anterior
),
eventos_punto_partida as (SELECT
    e.*,
    (select 
    t.tiie_28_ff
    from tasas_ff t
    where t.fecha<e.fecha_evento
    order by t.fecha DESC
    LIMIT 1) as tiie_28_dia_antes
    from eventos e
),

eventos_con_umbral as (SELECT
    *,
    tiie_28_dia_antes+(movimiento*0.85) as umbral_85_pct
    from eventos_punto_partida
),
convergencia as(SELECT
    e.fecha_evento,
    e.decada,
    e.direccion,
    e.movimiento,
    min(t.fecha) as convergencia_fecha
    from eventos_con_umbral e
    join tasas_ff t
    ON t.fecha BETWEEN e.fecha_evento AND DATE_ADD(e.fecha_evento, INTERVAL 90 DAY)
   AND (
        (e.direccion = 'alza'    AND t.tiie_28_ff >= e.umbral_85_pct)
     OR (e.direccion = 'recorte' AND t.tiie_28_ff <= e.umbral_85_pct)
   )
  GROUP BY e.fecha_evento, e.decada, e.direccion, e.movimiento
)

SELECT
  decada,
  direccion,
  COUNT(*)                                                        AS n_eventos,
  ROUND(AVG(DATE_DIFF(convergencia_fecha, fecha_evento, DAY)), 1)  AS dias_promedio_pass_through_85pct,
  ROUND(APPROX_QUANTILES(DATE_DIFF(convergencia_fecha, fecha_evento, DAY), 2)[OFFSET(1)], 1) AS dias_mediana

FROM convergencia
GROUP BY decada, direccion
ORDER BY decada, direccion
    