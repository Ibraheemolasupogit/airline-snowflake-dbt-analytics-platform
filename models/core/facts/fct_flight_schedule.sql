-- Grain is one row per scheduled flight service (schedule_id). Operational schedule measures
-- only; no passenger-booking, revenue, or ticketing facts.
with scheduled_segments as (

    select
        schedule_id,
        route_id,
        distance_km,
        scheduled_departure_local_time,
        scheduled_duration_minutes,
        weekly_operating_day_count
    from {{ ref('int_scheduled_flight_segments') }}

),

flights as (

    select
        flight_key,
        schedule_id,
        airline_key,
        aircraft_type_key
    from {{ ref('dim_flight') }}

),

routes as (

    select
        route_id,
        origin_airport_key,
        destination_airport_key
    from {{ ref('dim_route') }}

),

joined as (

    select
        scheduled_segments.schedule_id,
        flights.flight_key,
        flights.airline_key,
        routes.origin_airport_key,
        routes.destination_airport_key,
        flights.aircraft_type_key,
        scheduled_segments.route_id,
        scheduled_segments.scheduled_departure_local_time,
        scheduled_segments.scheduled_duration_minutes,
        scheduled_segments.weekly_operating_day_count,
        scheduled_segments.distance_km
    from scheduled_segments
    left join flights
        on scheduled_segments.schedule_id = flights.schedule_id
    left join routes
        on scheduled_segments.route_id = routes.route_id

)

select
    schedule_id,
    flight_key,
    airline_key,
    origin_airport_key,
    destination_airport_key,
    aircraft_type_key,
    route_id,
    scheduled_departure_local_time,
    scheduled_duration_minutes,
    weekly_operating_day_count,
    distance_km
from joined
