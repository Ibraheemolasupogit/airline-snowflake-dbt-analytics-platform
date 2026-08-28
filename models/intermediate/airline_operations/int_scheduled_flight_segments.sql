-- Reusable scheduled-flight-service transformation. Grain is one row per flight schedule.
-- Combines the schedule with its airline, route/airport context (reused from
-- int_route_airport_pair rather than re-joining AirStats here), and assigned aircraft type.
with schedules as (

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
    from {{ ref('stg_airline__flight_schedules') }}

),

airlines as (

    select
        airline_code,
        airline_name
    from {{ ref('stg_airline__airlines') }}

),

aircraft_types as (

    select
        aircraft_type_code,
        type_name as aircraft_type_name,
        body_type as aircraft_body_type,
        typical_seats as aircraft_typical_seats,
        cabins as aircraft_cabins
    from {{ ref('stg_airline__aircraft_types') }}

),

route_airports as (

    select
        route_id,
        origin_airport_name,
        origin_country_code,
        destination_airport_name,
        destination_country_code,
        distance_km
    from {{ ref('int_route_airport_pair') }}

),

joined as (

    select
        schedules.schedule_id,
        schedules.route_id,
        schedules.airline_code,
        airlines.airline_name,
        schedules.flight_number,
        schedules.origin_ident,
        route_airports.origin_airport_name,
        route_airports.origin_country_code,
        schedules.destination_ident,
        route_airports.destination_airport_name,
        route_airports.destination_country_code,
        route_airports.distance_km,
        schedules.aircraft_type_code,
        aircraft_types.aircraft_type_name,
        aircraft_types.aircraft_body_type,
        aircraft_types.aircraft_typical_seats,
        aircraft_types.aircraft_cabins,
        schedules.scheduled_departure_local_time,
        schedules.scheduled_duration_minutes,
        schedules.operating_days_of_week,
        array_size(split(schedules.operating_days_of_week, '|')) as weekly_operating_day_count
    from schedules
    left join airlines
        on schedules.airline_code = airlines.airline_code
    left join aircraft_types
        on schedules.aircraft_type_code = aircraft_types.aircraft_type_code
    left join route_airports
        on schedules.route_id = route_airports.route_id

)

select
    schedule_id,
    route_id,
    airline_code,
    airline_name,
    flight_number,
    origin_ident,
    origin_airport_name,
    origin_country_code,
    destination_ident,
    destination_airport_name,
    destination_country_code,
    distance_km,
    aircraft_type_code,
    aircraft_type_name,
    aircraft_body_type,
    aircraft_typical_seats,
    aircraft_cabins,
    scheduled_departure_local_time,
    scheduled_duration_minutes,
    operating_days_of_week,
    weekly_operating_day_count
from joined
