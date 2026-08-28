-- Reusable ticketed passenger flight-segment transformation. Grain is one row per ticketed
-- passenger flight segment (ticket_segment_id). Joins ticket_segment -> ticket (for booking_id,
-- passenger_id, fare_class_code, ticket_status) -> the Milestone 11 operational layer
-- (int_operated_flight_segments) for flight-instance/route/airport context, reusing that layer
-- rather than rebuilding flight logic. No fares, taxes, or revenue are calculated here.
with ticket_segments as (

    select
        ticket_segment_id,
        ticket_id,
        segment_sequence,
        flight_instance_id,
        cabin,
        fare_basis_code,
        segment_status
    from {{ ref('stg_airline__ticket_segments') }}

),

tickets as (

    select
        ticket_id,
        ticket_number,
        booking_id,
        passenger_id,
        fare_class_code,
        ticket_status
    from {{ ref('stg_airline__tickets') }}

),

operated_segments as (

    select
        flight_instance_id,
        schedule_id,
        route_id,
        airline_code,
        flight_number,
        flight_date,
        origin_ident,
        origin_airport_name,
        destination_ident,
        destination_airport_name,
        distance_km,
        scheduled_departure_utc,
        scheduled_arrival_utc,
        status as flight_instance_status,
        operational_completion_status
    from {{ ref('int_operated_flight_segments') }}

),

joined as (

    select
        ticket_segments.ticket_segment_id,
        ticket_segments.ticket_id,
        tickets.ticket_number,
        tickets.booking_id,
        tickets.passenger_id,
        ticket_segments.segment_sequence,
        ticket_segments.flight_instance_id,
        operated_segments.schedule_id,
        operated_segments.route_id,
        operated_segments.airline_code,
        operated_segments.flight_number,
        operated_segments.flight_date,
        operated_segments.origin_ident,
        operated_segments.origin_airport_name,
        operated_segments.destination_ident,
        operated_segments.destination_airport_name,
        operated_segments.distance_km,
        operated_segments.scheduled_departure_utc,
        operated_segments.scheduled_arrival_utc,
        tickets.fare_class_code,
        ticket_segments.cabin,
        ticket_segments.fare_basis_code,
        tickets.ticket_status,
        ticket_segments.segment_status,
        operated_segments.flight_instance_status,
        operated_segments.operational_completion_status
    from ticket_segments
    left join tickets
        on ticket_segments.ticket_id = tickets.ticket_id
    left join operated_segments
        on ticket_segments.flight_instance_id = operated_segments.flight_instance_id

)

select
    ticket_segment_id,
    ticket_id,
    ticket_number,
    booking_id,
    passenger_id,
    segment_sequence,
    flight_instance_id,
    schedule_id,
    route_id,
    airline_code,
    flight_number,
    flight_date,
    origin_ident,
    origin_airport_name,
    destination_ident,
    destination_airport_name,
    distance_km,
    scheduled_departure_utc,
    scheduled_arrival_utc,
    fare_class_code,
    cabin,
    fare_basis_code,
    ticket_status,
    segment_status,
    flight_instance_status,
    operational_completion_status
from joined
