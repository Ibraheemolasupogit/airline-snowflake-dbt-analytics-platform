with source as (

    select *
    from {{ source('airline_operations', 'flight_schedules') }}

),

renamed as (

    select
        nullif(trim(cast(schedule_id as varchar)), '') as schedule_id,
        nullif(trim(cast(route_id as varchar)), '') as route_id,
        nullif(trim(cast(airline_code as varchar)), '') as airline_code,
        nullif(trim(cast(flight_number as varchar)), '') as flight_number,
        nullif(trim(cast(origin_ident as varchar)), '') as origin_ident,
        nullif(trim(cast(destination_ident as varchar)), '') as destination_ident,
        nullif(trim(cast(aircraft_type_code as varchar)), '') as aircraft_type_code,
        nullif(trim(cast(scheduled_departure_local_time as varchar)), '') as scheduled_departure_local_time,
        try_to_number(
            nullif(trim(cast(scheduled_duration_minutes as varchar)), ''), 38, 0
        ) as scheduled_duration_minutes,
        nullif(trim(cast(operating_days_of_week as varchar)), '') as operating_days_of_week
    from source

)

select
    schedule_id,
    route_id,
    airline_code,
    flight_number,
    origin_ident,
    destination_ident,
    aircraft_type_code,
    scheduled_departure_local_time,
    scheduled_duration_minutes,
    operating_days_of_week
from renamed
