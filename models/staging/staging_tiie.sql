SELECT
cast(fecha as date)as fecha,
cast(nullif(TIIE_a_182_dias, "N/E")as numeric) as TIIE_a_182_dias,
cast(nullif(tiie_dia_habil_bancario, "N/E")as numeric)as tiie_dia_habil_bancario,
cast(nullif(Tasa_de_fondeo_bancario_anual, "N/E")as numeric) as Tasa_de_fondeo_bancario_anual,
cast(nullif(tasa_de_fondeo_gubernamental_anual, "N/E")as numeric ) as tasa_de_fondeo_gubernamental_anual,
cast(nullif(tiie_a_28_dias, "N/E")as numeric)as tiie_a_28_dias,
cast(nullif(tiie_a_91_dias, "N/E")as numeric)as tiie_a_91_dias,
cast(nullif(Tasa_objetivo, "N/E")as numeric)as Tasa_objetivo
from {{ source('banxico', 'TIIE_08_26') }} 