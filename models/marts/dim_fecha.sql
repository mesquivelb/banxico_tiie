with fechas as(
    select fecha
    from unnest(
        generate_date_array('2008-01-01','2027-12-31', interval 1 day)
    ) as fecha
)
SELECT
    cast(format_date('%Y%m%d',fecha)as int64) as id_fecha,
    fecha,
    extract(year from fecha) as anio,
    extract(month from fecha) as mes,
    extract(quarter from fecha) as trimestre,
    format_date('%B',fecha) as nombre,
    extract(day from fecha) as dia_del_mes,
    extract(dayofweek from fecha) as dia_semana_num,
    format_date('%A', fecha) as  dia_semana_nombre,
    case 
    when extract(dayofweek from fecha) in (1,7)then true
    else false
    end as es_Fin_de_semana,

    from fechas