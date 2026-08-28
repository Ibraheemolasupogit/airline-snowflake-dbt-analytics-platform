with airports as (

    select
        ident,
        airport_source_id
    from {{ ref('stg_airstats__airports') }}

),

runways as (

    select
        runway_source_id,
        airport_ident,
        length_ft,
        width_ft,
        surface,
        is_lighted,
        is_closed
    from {{ ref('stg_airstats__runways') }}

),

runway_profile as (

    select
        airport_ident,
        count(runway_source_id) as runway_count,
        count_if(is_closed = false) as open_runway_count,
        count_if(is_closed = true) as closed_runway_count,
        count_if(is_lighted = true) as lighted_runway_count,
        max(length_ft) as max_runway_length_ft,
        min(length_ft) as min_runway_length_ft,
        avg(length_ft) as avg_runway_length_ft,
        max(width_ft) as max_runway_width_ft,
        avg(width_ft) as avg_runway_width_ft,
        count(distinct surface) as distinct_surface_count
    from runways
    group by airport_ident

),

final as (

    select
        airports.airport_source_id,
        airports.ident,
        runway_profile.max_runway_length_ft,
        runway_profile.min_runway_length_ft,
        runway_profile.avg_runway_length_ft,
        runway_profile.max_runway_width_ft,
        runway_profile.avg_runway_width_ft,
        coalesce(runway_profile.runway_count, 0) as runway_count,
        coalesce(runway_profile.open_runway_count, 0) as open_runway_count,
        coalesce(runway_profile.closed_runway_count, 0) as closed_runway_count,
        coalesce(runway_profile.lighted_runway_count, 0) as lighted_runway_count,
        coalesce(runway_profile.distinct_surface_count, 0) as distinct_surface_count
    from airports
    left join runway_profile
        on airports.ident = runway_profile.airport_ident

)

select
    airport_source_id,
    ident,
    runway_count,
    open_runway_count,
    closed_runway_count,
    lighted_runway_count,
    max_runway_length_ft,
    min_runway_length_ft,
    avg_runway_length_ft,
    max_runway_width_ft,
    avg_runway_width_ft,
    distinct_surface_count
from final
