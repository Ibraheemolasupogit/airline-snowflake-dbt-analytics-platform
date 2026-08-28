-- Reusable dated-flight-occurrence transformation. Grain is one row per flight instance.
-- Combines the flight instance with its scheduled context (int_scheduled_flight_segments) and
-- the actual operating aircraft (stg_airline__aircraft), so the schedule's assigned aircraft
-- type can be compared with the aircraft that actually operated the flight.
--
-- No actual/observed departure or arrival timestamps exist in the Milestone 9 source -- only
-- scheduled timestamps -- so no delay measures are computed here. No booking/ticket data is
-- referenced; passenger and load-factor measures are added downstream in fct_flight_operations
-- as explicitly null placeholders, documented there.
with flight_instances as (

    select
        flight_instance_id,
        schedule_id,
        flight_date,
        origin_ident,
        destination_ident,
        aircraft_registration,
        scheduled_departure_utc,
        scheduled_arrival_utc,
        status
    from {{ ref('stg_airline__flight_instances') }}

),

scheduled_segments as (

    select
        schedule_id,
        route_id,
        airline_code,
        airline_name,
        flight_number,
        origin_airport_name,
        destination_airport_name,
        distance_km,
        aircraft_type_code as scheduled_aircraft_type_code
    from {{ ref('int_scheduled_flight_segments') }}

),

operating_aircraft as (

    select
        aircraft.aircraft_registration,
        aircraft.aircraft_type_code as actual_aircraft_type_code,
        aircraft_types.type_name as actual_aircraft_type_name,
        aircraft_types.typical_seats as actual_aircraft_typical_seats
    from {{ ref('stg_airline__aircraft') }} as aircraft
    left join {{ ref('stg_airline__aircraft_types') }} as aircraft_types
        on aircraft.aircraft_type_code = aircraft_types.aircraft_type_code

),

joined as (

    select
        flight_instances.flight_instance_id,
        flight_instances.schedule_id,
        scheduled_segments.route_id,
        scheduled_segments.airline_code,
        scheduled_segments.airline_name,
        scheduled_segments.flight_number,
        flight_instances.flight_date,
        flight_instances.origin_ident,
        scheduled_segments.origin_airport_name,
        flight_instances.destination_ident,
        scheduled_segments.destination_airport_name,
        scheduled_segments.distance_km,
        flight_instances.aircraft_registration,
        scheduled_segments.scheduled_aircraft_type_code,
        operating_aircraft.actual_aircraft_type_code,
        operating_aircraft.actual_aircraft_type_name,
        operating_aircraft.actual_aircraft_typical_seats,
        flight_instances.scheduled_departure_utc,
        flight_instances.scheduled_arrival_utc,
        flight_instances.status,
        case
            when flight_instances.status in ('scheduled', 'completed', 'cancelled') then flight_instances.status
            when flight_instances.status is null then null
            else 'other'
        end as operational_completion_status,
        case
            when
                scheduled_segments.scheduled_aircraft_type_code is null
                or operating_aircraft.actual_aircraft_type_code is null
                then null
            when scheduled_segments.scheduled_aircraft_type_code = operating_aircraft.actual_aircraft_type_code
                then true
            else false
        end as is_assigned_aircraft_type_consistent
    from flight_instances
    left join scheduled_segments
        on flight_instances.schedule_id = scheduled_segments.schedule_id
    left join operating_aircraft
        on flight_instances.aircraft_registration = operating_aircraft.aircraft_registration

)

select
    flight_instance_id,
    schedule_id,
    route_id,
    airline_code,
    airline_name,
    flight_number,
    flight_date,
    origin_ident,
    origin_airport_name,
    destination_ident,
    destination_airport_name,
    distance_km,
    aircraft_registration,
    scheduled_aircraft_type_code,
    actual_aircraft_type_code,
    actual_aircraft_type_name,
    actual_aircraft_typical_seats,
    scheduled_departure_utc,
    scheduled_arrival_utc,
    status,
    operational_completion_status,
    is_assigned_aircraft_type_consistent
from joined
