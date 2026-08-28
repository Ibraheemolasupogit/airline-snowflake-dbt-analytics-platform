with runway_capability as (

    select
        runway_source_id,
        airport_source_id,
        airport_ident,
        length_ft,
        width_ft,
        surface,
        is_lighted,
        is_closed,
        is_source_usable,
        runway_length_category,
        runway_width_category,
        runway_surface_category,
        endpoint_completeness_status
    from {{ ref('int_runway_capability') }}

),

geography as (

    select
        ident,
        airport_name,
        country_code,
        country_name
    from {{ ref('int_airport_geography') }}

),

final as (

    select
        runway_capability.runway_source_id,
        runway_capability.airport_source_id,
        runway_capability.airport_ident,
        geography.airport_name,
        geography.country_code,
        geography.country_name,
        runway_capability.length_ft,
        runway_capability.width_ft,
        runway_capability.surface,
        runway_capability.is_lighted,
        runway_capability.is_closed,
        runway_capability.is_source_usable,
        runway_capability.runway_length_category,
        runway_capability.runway_width_category,
        runway_capability.runway_surface_category,
        runway_capability.endpoint_completeness_status
    from runway_capability
    left join geography
        on runway_capability.airport_ident = geography.ident

)

select
    runway_source_id,
    airport_source_id,
    airport_ident,
    airport_name,
    country_code,
    country_name,
    length_ft,
    width_ft,
    surface,
    is_lighted,
    is_closed,
    is_source_usable,
    runway_length_category,
    runway_width_category,
    runway_surface_category,
    endpoint_completeness_status
from final
