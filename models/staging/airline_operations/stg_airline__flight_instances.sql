with source as (

    select *
    from {{ source('airline_operations', 'flight_instances') }}

),

renamed as (

    select
        nullif(trim(cast(flight_instance_id as varchar)), '') as flight_instance_id,
        nullif(trim(cast(schedule_id as varchar)), '') as schedule_id,
        nullif(trim(cast(flight_number as varchar)), '') as flight_number,
        try_to_date(nullif(trim(cast(flight_date as varchar)), '')) as flight_date,
        nullif(trim(cast(origin_ident as varchar)), '') as origin_ident,
        nullif(trim(cast(destination_ident as varchar)), '') as destination_ident,
        nullif(trim(cast(aircraft_registration as varchar)), '') as aircraft_registration,
        try_to_timestamp_ntz(nullif(trim(cast(scheduled_departure_utc as varchar)), '')) as scheduled_departure_utc,
        try_to_timestamp_ntz(nullif(trim(cast(scheduled_arrival_utc as varchar)), '')) as scheduled_arrival_utc,
        nullif(trim(cast(status as varchar)), '') as status
    from source

)

select
    flight_instance_id,
    schedule_id,
    flight_number,
    flight_date,
    origin_ident,
    destination_ident,
    aircraft_registration,
    scheduled_departure_utc,
    scheduled_arrival_utc,
    status
from renamed
