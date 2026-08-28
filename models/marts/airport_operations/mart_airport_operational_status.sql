with operational_status as (

    select
        ident,
        airport_source_id,
        airport_type,
        has_scheduled_service,
        runway_count,
        open_runway_count,
        has_open_runway_record,
        is_not_source_closed_airport,
        analytical_operational_status
    from {{ ref('int_airport_operational_status') }}

),

geography as (

    select
        ident,
        airport_name,
        country_code,
        country_name,
        region_code,
        region_name
    from {{ ref('int_airport_geography') }}

),

final as (

    select
        operational_status.ident,
        operational_status.airport_source_id,
        geography.airport_name,
        geography.country_code,
        geography.country_name,
        geography.region_code,
        geography.region_name,
        operational_status.airport_type,
        operational_status.has_scheduled_service,
        operational_status.runway_count,
        operational_status.open_runway_count,
        operational_status.has_open_runway_record,
        operational_status.is_not_source_closed_airport,
        operational_status.analytical_operational_status
    from operational_status
    left join geography
        on operational_status.ident = geography.ident

)

select
    ident,
    airport_source_id,
    airport_name,
    country_code,
    country_name,
    region_code,
    region_name,
    airport_type,
    has_scheduled_service,
    runway_count,
    open_runway_count,
    has_open_runway_record,
    is_not_source_closed_airport,
    analytical_operational_status
from final
