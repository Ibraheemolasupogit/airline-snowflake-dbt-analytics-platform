-- Curated AirStats runway analysis: distribution of runway capability categories by country.
-- Deterministic source-derived buckets only; not a certification or regulatory assessment.

with runway_capability as (

    select
        country_code,
        country_name,
        runway_length_category,
        runway_surface_category,
        is_source_usable
    from {{ ref('mart_airport_runway_capability') }}

),

summarised as (

    select
        country_code,
        country_name,
        runway_length_category,
        runway_surface_category,
        count(*) as runway_count,
        count_if(is_source_usable) as usable_runway_count
    from runway_capability
    group by country_code, country_name, runway_length_category, runway_surface_category

)

select
    country_code,
    country_name,
    runway_length_category,
    runway_surface_category,
    runway_count,
    usable_runway_count
from summarised
order by country_code asc, runway_count desc
