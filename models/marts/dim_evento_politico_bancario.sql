with cambios as (SELECT
fecha,
tasa_objetivo,
lag(tasa_objetivo)over(order by fecha)as tasa_anterior
from {{ref('staging_tiie') }}
where tasa_objetivo is not NULL
)
SELECT
cast (format_date('%Y%m%d', fecha)as int64) as id_evento,
fecha as fecha_decision,
tasa_anterior,
tasa_objetivo as tasa_nueva,
round(tasa_objetivo-tasa_anterior,2) as magnitud_cambio,
CASE
when tasa_objetivo>tasa_anterior then 'alza'
when tasa_objetivo<tasa_anterior then 'recorte'
else 'sin_cambio'
end as direccion,

case 
when fecha BETWEEN '2008-01-01' and '2009-01-31' then 'Crisis financiera global, fase de alza'
when fecha BETWEEN '2009-02-01' and '2009-07-31' then 'Crisis financiera global, recortes de emergencia'
when fecha BETWEEN '2015-01-01' and '2018-12-31' then 'Alzas Fed EE.UU., "Gasolinazo", Depreciación del peso'
when fecha BETWEEN '2020-01-01' and '2020-12-31' then 'Pandemia COVID-19, recortes de emergencia'
when fecha BETWEEN '2022-01-31' and '2023-06-30' then 'Inflación post-pandemia, Guerra en Ucrania '
when fecha BETWEEN '2024-01-01' and '2026-12-31' then 'Regulación, ciclo de regulamiento'
else 'Otro'
end as contexto_evento
from cambios
where tasa_objetivo != tasa_anterior
