with tasas as(select * from {{ ref('staging_tiie') }}),
tasas_ff as(select
Fecha,
TIIE_a_182_dias,
tiie_dia_habil_bancario,
Tasa_de_fondeo_bancario_anual,
tasa_de_fondeo_gubernamental_anual,
tiie_a_28_dias,
tiie_a_91_dias,
Tasa_objetivo,
last_value(tasa_objetivo IGNORE nulls) over(
order by fecha rows BETWEEN UNBOUNDED PRECEDING and CURRENT ROW)
as tasa_objetivo_vigente
from tasas
)

select
CAST(format_date('%Y%m%d', t.fecha)as int64)as id_fecha,
t.tiie_a_28_dias,
  t.tiie_a_91_dias,
  t.tiie_a_182_dias,
  t.tasa_objetivo_vigente as tasa_objetivo,
  round(t.tiie_a_28_dias-t.tasa_objetivo_vigente, 4) as spread_tiie28_vs_objetivo,
  case when t.tiie_a_28_dias is not null then true else false end as es_dia_habil_bancario
  from tasas_ff t