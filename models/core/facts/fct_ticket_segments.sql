-- Grain is one row per ticketed passenger flight segment (ticket_segment_id). Reuses
-- int_ticketed_segments (which already reuses the Milestone 11 operational layer) and joins
-- fct_bookings / dim_passenger / dim_flight / dim_route / dim_airport / dim_fare_class /
-- dim_cabin for their already-generated surrogate keys. No fares, taxes, or revenue values.
with ticketed_segments as (

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
        flight_date,
        origin_ident,
        destination_ident,
        scheduled_departure_utc,
        scheduled_arrival_utc,
        fare_class_code,
        cabin,
        fare_basis_code,
        ticket_status,
        segment_status,
        flight_instance_status,
        operational_completion_status
    from {{ ref('int_ticketed_segments') }}

),

bookings as (

    select
        booking_key,
        booking_id
    from {{ ref('fct_bookings') }}

),

passengers as (

    select
        passenger_key,
        passenger_id
    from {{ ref('dim_passenger') }}

),

flights as (

    select
        flight_key,
        schedule_id
    from {{ ref('dim_flight') }}

),

routes as (

    select
        route_key,
        route_id
    from {{ ref('dim_route') }}

),

origin_airports as (

    select
        airport_key,
        airport_ident
    from {{ ref('dim_airport') }}

),

destination_airports as (

    select
        airport_key,
        airport_ident
    from {{ ref('dim_airport') }}

),

fare_classes as (

    select
        fare_class_key,
        fare_class_code
    from {{ ref('dim_fare_class') }}

),

cabins as (

    select
        cabin_key,
        cabin
    from {{ ref('dim_cabin') }}

),

joined as (

    select
        ticketed_segments.ticket_segment_id,
        ticketed_segments.ticket_id,
        ticketed_segments.ticket_number,
        bookings.booking_key,
        ticketed_segments.booking_id,
        passengers.passenger_key,
        ticketed_segments.passenger_id,
        ticketed_segments.segment_sequence,
        flights.flight_key,
        ticketed_segments.flight_instance_id,
        ticketed_segments.schedule_id,
        routes.route_key,
        ticketed_segments.route_id,
        origin_airports.airport_key as origin_airport_key,
        ticketed_segments.origin_ident,
        destination_airports.airport_key as destination_airport_key,
        ticketed_segments.destination_ident,
        ticketed_segments.flight_date,
        ticketed_segments.scheduled_departure_utc,
        ticketed_segments.scheduled_arrival_utc,
        fare_classes.fare_class_key,
        ticketed_segments.fare_class_code,
        cabins.cabin_key,
        ticketed_segments.cabin,
        ticketed_segments.fare_basis_code,
        ticketed_segments.ticket_status,
        ticketed_segments.segment_status,
        ticketed_segments.flight_instance_status,
        ticketed_segments.operational_completion_status
    from ticketed_segments
    left join bookings
        on ticketed_segments.booking_id = bookings.booking_id
    left join passengers
        on ticketed_segments.passenger_id = passengers.passenger_id
    left join flights
        on ticketed_segments.schedule_id = flights.schedule_id
    left join routes
        on ticketed_segments.route_id = routes.route_id
    left join origin_airports
        on ticketed_segments.origin_ident = origin_airports.airport_ident
    left join destination_airports
        on ticketed_segments.destination_ident = destination_airports.airport_ident
    left join fare_classes
        on ticketed_segments.fare_class_code = fare_classes.fare_class_code
    left join cabins
        on ticketed_segments.cabin = cabins.cabin

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['ticket_segment_id']) }} as ticket_segment_key,
        ticket_segment_id,
        ticket_id,
        ticket_number,
        booking_key,
        booking_id,
        passenger_key,
        passenger_id,
        segment_sequence,
        flight_key,
        flight_instance_id,
        schedule_id,
        route_key,
        route_id,
        origin_airport_key,
        origin_ident,
        destination_airport_key,
        destination_ident,
        flight_date,
        scheduled_departure_utc,
        scheduled_arrival_utc,
        fare_class_key,
        fare_class_code,
        cabin_key,
        cabin,
        fare_basis_code,
        ticket_status,
        segment_status,
        flight_instance_status,
        operational_completion_status
    from joined

)

select
    ticket_segment_key,
    ticket_segment_id,
    ticket_id,
    ticket_number,
    booking_key,
    booking_id,
    passenger_key,
    passenger_id,
    segment_sequence,
    flight_key,
    flight_instance_id,
    schedule_id,
    route_key,
    route_id,
    origin_airport_key,
    origin_ident,
    destination_airport_key,
    destination_ident,
    flight_date,
    scheduled_departure_utc,
    scheduled_arrival_utc,
    fare_class_key,
    fare_class_code,
    cabin_key,
    cabin,
    fare_basis_code,
    ticket_status,
    segment_status,
    flight_instance_status,
    operational_completion_status
from final
