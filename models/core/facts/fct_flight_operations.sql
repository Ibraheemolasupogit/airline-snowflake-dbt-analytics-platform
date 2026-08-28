-- Grain is one row per dated flight instance. seats_available is real, taken from the actual
-- operating aircraft's type capacity. No actual/observed departure or arrival timestamps exist
-- in the source, so no delay measures are computed here.
--
-- passengers_carried (Milestone 12): count of this flight instance's ticket segments whose
-- int_passenger_journey_completion.journey_completion_status = 'completed' -- i.e. the ticket
-- segment was actually flown (segment_status = 'flown') on a flight instance that itself
-- completed. Cancelled and not-yet-flown segments are deliberately excluded ("do not count
-- cancelled/non-flown passengers as carried"). ticket_segment_id is that model's grain key, so
-- counting its rows counts distinct passenger-segments, not raw ticket rows, which avoids
-- double-counting a passenger across a round trip's two segments (each leg is a separate
-- flight_instance_id and therefore a separate count here). Flight instances with no completed
-- segments (still-scheduled or cancelled flights) get passengers_carried = 0, not null, since
-- zero is a real, known count rather than an unknown one.
-- load_factor = passengers_carried / seats_available, computed only where seats_available > 0,
-- unchanged from the Milestone 11 guard.
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

passenger_counts as (

    select
        flight_instance_id,
        count(*) as passengers_carried
    from {{ ref('int_passenger_journey_completion') }}
    where journey_completion_status = 'completed'
    group by flight_instance_id

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
        coalesce(passenger_counts.passengers_carried, 0) as passengers_carried,
        case
            when operated_segments.actual_aircraft_typical_seats > 0
                then
                    coalesce(passenger_counts.passengers_carried, 0)
                    / operated_segments.actual_aircraft_typical_seats
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
    left join passenger_counts
        on operated_segments.flight_instance_id = passenger_counts.flight_instance_id

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
