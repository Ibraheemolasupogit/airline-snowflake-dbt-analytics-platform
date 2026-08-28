-- Curated AirStats airport analysis: capacity profile by country, ranked by open runway count.
-- Source-derived analytical view only; not a live operational capacity assessment.

with capacity_profile as (

    select
        ident,
        airport_name,
        airport_type,
        country_code,
        country_name,
        has_scheduled_service,
        runway_count,
        open_runway_count,
        max_runway_length_ft,
        avg_runway_length_ft
    from {{ ref('mart_airport_capacity_profile') }}

),

ranked as (

    select
        ident,
        airport_name,
        airport_type,
        country_code,
        country_name,
        has_scheduled_service,
        runway_count,
        open_runway_count,
        max_runway_length_ft,
        avg_runway_length_ft,
        row_number() over (
            partition by country_code
            order by open_runway_count desc, max_runway_length_ft desc nulls last
        ) as country_capacity_rank
    from capacity_profile

)

select
    ident,
    airport_name,
    airport_type,
    country_code,
    country_name,
    has_scheduled_service,
    runway_count,
    open_runway_count,
    max_runway_length_ft,
    avg_runway_length_ft,
    country_capacity_rank
from ranked
where country_capacity_rank <= 10
order by country_code asc, country_capacity_rank asc
