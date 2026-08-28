with airports as (

    select
        airport_source_id,
        ident,
        airport_type,
        has_scheduled_service
    from {{ ref('stg_airstats__airports') }}

),

runway_profile as (

    select
        ident,
        runway_count,
        open_runway_count
    from {{ ref('int_airport_runway_profile') }}

),

classified as (

    select
        airports.airport_source_id,
        airports.ident,
        airports.airport_type,
        airports.has_scheduled_service,
        coalesce(runway_profile.runway_count, 0) as runway_count,
        coalesce(runway_profile.open_runway_count, 0) as open_runway_count,
        case
            when airports.airport_type = 'closed_airport' then 'source_closed_airport'
            when airports.has_scheduled_service then 'source_scheduled_service'
            when coalesce(runway_profile.open_runway_count, 0) > 0 then 'source_open_runway_recorded'
            else 'source_reference_only'
        end as analytical_operational_status,
        coalesce(runway_profile.open_runway_count, 0) > 0 as has_open_runway_record,
        airports.airport_type != 'closed_airport' as is_not_source_closed_airport
    from airports
    left join runway_profile
        on airports.ident = runway_profile.ident

),

final as (

    select
        airport_source_id,
        ident,
        airport_type,
        has_scheduled_service,
        runway_count,
        open_runway_count,
        has_open_runway_record,
        is_not_source_closed_airport,
        analytical_operational_status
    from classified

)

select
    airport_source_id,
    ident,
    airport_type,
    has_scheduled_service,
    runway_count,
    open_runway_count,
    has_open_runway_record,
    is_not_source_closed_airport,
    analytical_operational_status
from final
