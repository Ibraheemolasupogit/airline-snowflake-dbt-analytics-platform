-- Grain is one row per flight schedule (schedule_id). In this dataset schedule_id and
-- flight_number are in 1:1 correspondence (the generator assigns exactly one schedule per
-- route with a unique flight_number), so "one scheduled flight number" and "one flight
-- schedule" are currently equivalent. schedule_id is chosen as the durable grain key because it
-- is the true source-system primary key; flight_number is retained as a descriptive attribute,
-- not the grain. Do not confuse this scheduled-flight identity with a dated flight instance,
-- which is fct_flight_operations' grain.
with scheduled_segments as (

    select
        schedule_id,
        route_id,
        airline_code,
        flight_number,
        aircraft_type_code,
        scheduled_departure_local_time,
        scheduled_duration_minutes,
        operating_days_of_week
    from {{ ref('int_scheduled_flight_segments') }}

),

airlines as (

    select
        airline_key,
        airline_code
    from {{ ref('dim_airline') }}

),

routes as (

    select
        route_key,
        route_id
    from {{ ref('dim_route') }}

),

aircraft_types as (

    select
        aircraft_type_key,
        aircraft_type_code
    from {{ ref('dim_aircraft_type') }}

),

joined as (

    select
        scheduled_segments.schedule_id,
        scheduled_segments.flight_number,
        scheduled_segments.airline_code,
        airlines.airline_key,
        scheduled_segments.route_id,
        routes.route_key,
        scheduled_segments.aircraft_type_code,
        aircraft_types.aircraft_type_key,
        scheduled_segments.scheduled_departure_local_time,
        scheduled_segments.scheduled_duration_minutes,
        scheduled_segments.operating_days_of_week
    from scheduled_segments
    left join airlines
        on scheduled_segments.airline_code = airlines.airline_code
    left join routes
        on scheduled_segments.route_id = routes.route_id
    left join aircraft_types
        on scheduled_segments.aircraft_type_code = aircraft_types.aircraft_type_code

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['schedule_id']) }} as flight_key,
        schedule_id,
        flight_number,
        airline_key,
        airline_code,
        route_key,
        route_id,
        aircraft_type_key,
        aircraft_type_code,
        scheduled_departure_local_time,
        scheduled_duration_minutes,
        operating_days_of_week
    from joined

)

select
    flight_key,
    schedule_id,
    flight_number,
    airline_key,
    airline_code,
    route_key,
    route_id,
    aircraft_type_key,
    aircraft_type_code,
    scheduled_departure_local_time,
    scheduled_duration_minutes,
    operating_days_of_week
from final
