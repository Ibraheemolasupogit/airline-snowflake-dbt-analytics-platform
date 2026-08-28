-- Grain is one row per dated flight instance. Uses only flight-instance operational data --
-- no booking or ticket passenger counts are introduced. passengers_carried is therefore always
-- null in this milestone (populated from ticket data no earlier than Milestone 12), and
-- load_factor is consequently always null too; both are included now as a stable, documented
-- placeholder shape rather than a value later milestones must retrofit. seats_available is real,
-- taken from the actual operating aircraft's type capacity. No actual/observed departure or
-- arrival timestamps exist in the source, so no delay measures are computed here.
with operated_segments as (

    select
        flight_instance_id,
        schedule_id,
        route_id,
        aircraft_registration,
        actual_aircraft_type_code,
        actual_aircraft_typical_seats,
        flight_date,
        scheduled_departure_utc,
        scheduled_arrival_utc,
        status,
        operational_completion_status,
        is_assigned_aircraft_type_consistent
    from {{ ref('int_operated_flight_segments') }}

),

flights as (

    select
        flight_key,
        schedule_id,
        airline_key
    from {{ ref('dim_flight') }}

),

routes as (

    select
        route_id,
        origin_airport_key,
        destination_airport_key
    from {{ ref('dim_route') }}

),

aircraft as (

    select
        aircraft_key,
        aircraft_registration
    from {{ ref('dim_aircraft') }}

),

actual_aircraft_types as (

    select
        aircraft_type_key,
        aircraft_type_code
    from {{ ref('dim_aircraft_type') }}

),

joined as (

    select
        operated_segments.flight_instance_id,
        operated_segments.flight_date,
        flights.flight_key,
        flights.airline_key,
        routes.origin_airport_key,
        routes.destination_airport_key,
        aircraft.aircraft_key,
        actual_aircraft_types.aircraft_type_key as actual_aircraft_type_key,
        operated_segments.scheduled_departure_utc,
        operated_segments.scheduled_arrival_utc,
        operated_segments.status,
        operated_segments.operational_completion_status,
        operated_segments.is_assigned_aircraft_type_consistent,
        operated_segments.actual_aircraft_typical_seats as seats_available,
        cast(null as number(38, 0)) as passengers_carried,
        case
            when operated_segments.actual_aircraft_typical_seats > 0
                then cast(null as number(38, 0)) / operated_segments.actual_aircraft_typical_seats
        end as load_factor
    from operated_segments
    left join flights
        on operated_segments.schedule_id = flights.schedule_id
    left join routes
        on operated_segments.route_id = routes.route_id
    left join aircraft
        on operated_segments.aircraft_registration = aircraft.aircraft_registration
    left join actual_aircraft_types
        on operated_segments.actual_aircraft_type_code = actual_aircraft_types.aircraft_type_code

)

select
    flight_instance_id,
    flight_date,
    flight_key,
    airline_key,
    origin_airport_key,
    destination_airport_key,
    aircraft_key,
    actual_aircraft_type_key,
    scheduled_departure_utc,
    scheduled_arrival_utc,
    status,
    operational_completion_status,
    is_assigned_aircraft_type_consistent,
    seats_available,
    passengers_carried,
    load_factor
from joined
