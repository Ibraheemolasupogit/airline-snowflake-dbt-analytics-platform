with geography as (

    select
        ident,
        airport_source_id,
        airport_name,
        airport_type,
        country_code,
        country_name,
        region_code,
        region_name
    from {{ ref('int_airport_geography') }}

),

runway_profile as (

    select
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
    from {{ ref('int_airport_runway_profile') }}

),

operational_status as (

    select
        ident,
        has_scheduled_service
    from {{ ref('int_airport_operational_status') }}

),

final as (

    select
        geography.ident,
        geography.airport_source_id,
        geography.airport_name,
        geography.airport_type,
        geography.country_code,
        geography.country_name,
        geography.region_code,
        geography.region_name,
        operational_status.has_scheduled_service,
        runway_profile.runway_count,
        runway_profile.open_runway_count,
        runway_profile.closed_runway_count,
        runway_profile.lighted_runway_count,
        runway_profile.max_runway_length_ft,
        runway_profile.min_runway_length_ft,
        runway_profile.avg_runway_length_ft,
        runway_profile.max_runway_width_ft,
        runway_profile.avg_runway_width_ft,
        runway_profile.distinct_surface_count
    from geography
    left join runway_profile
        on geography.ident = runway_profile.ident
    left join operational_status
        on geography.ident = operational_status.ident

)

select
    ident,
    airport_source_id,
    airport_name,
    airport_type,
    country_code,
    country_name,
    region_code,
    region_name,
    has_scheduled_service,
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
