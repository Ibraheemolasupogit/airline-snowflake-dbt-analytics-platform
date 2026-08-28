-- Grain is one row per passenger flight segment / journey leg (ticket_segment_id) -- the same
-- grain as int_passenger_journey_completion, which this model reuses rather than re-deriving
-- journey_completion_status. Multi-leg journeys (round trips) are intentionally NOT collapsed
-- into one row per journey: the Milestone 9 source has no shared "journey"/"itinerary" key
-- spanning a ticket's segments beyond ticket_id + segment_sequence, and grouping by ticket_id
-- would conflate two operationally distinct flight legs (different flight_instance_id, possibly
-- different completion status) into a single row. See fct_ticket_segments for the fuller
-- operational/descriptive attribute set at the same grain; this fact is deliberately narrower,
-- focused only on journey-completion semantics.
with journeys as (

    select
        ticket_segment_id,
        ticket_id,
        booking_id,
        passenger_id,
        flight_instance_id,
        segment_status,
        flight_operational_completion_status,
        journey_completion_status,
        is_completed,
        is_cancelled
    from {{ ref('int_passenger_journey_completion') }}

),

ticket_segments as (

    select
        ticket_segment_id,
        schedule_id,
        origin_ident,
        destination_ident,
        flight_date
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

joined as (

    select
        journeys.ticket_segment_id,
        journeys.ticket_id,
        bookings.booking_key,
        journeys.booking_id,
        passengers.passenger_key,
        journeys.passenger_id,
        flights.flight_key,
        journeys.flight_instance_id,
        origin_airports.airport_key as origin_airport_key,
        ticket_segments.origin_ident,
        destination_airports.airport_key as destination_airport_key,
        ticket_segments.destination_ident,
        ticket_segments.flight_date,
        journeys.segment_status,
        journeys.flight_operational_completion_status,
        journeys.journey_completion_status,
        journeys.is_completed,
        journeys.is_cancelled
    from journeys
    left join ticket_segments
        on journeys.ticket_segment_id = ticket_segments.ticket_segment_id
    left join bookings
        on journeys.booking_id = bookings.booking_id
    left join passengers
        on journeys.passenger_id = passengers.passenger_id
    left join flights
        on ticket_segments.schedule_id = flights.schedule_id
    left join origin_airports
        on ticket_segments.origin_ident = origin_airports.airport_ident
    left join destination_airports
        on ticket_segments.destination_ident = destination_airports.airport_ident

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['ticket_segment_id']) }} as passenger_journey_key,
        ticket_segment_id,
        ticket_id,
        booking_key,
        booking_id,
        passenger_key,
        passenger_id,
        flight_key,
        flight_instance_id,
        origin_airport_key,
        origin_ident,
        destination_airport_key,
        destination_ident,
        flight_date,
        segment_status,
        flight_operational_completion_status,
        journey_completion_status,
        is_completed,
        is_cancelled
    from joined

)

select
    passenger_journey_key,
    ticket_segment_id,
    ticket_id,
    booking_key,
    booking_id,
    passenger_key,
    passenger_id,
    flight_key,
    flight_instance_id,
    origin_airport_key,
    origin_ident,
    destination_airport_key,
    destination_ident,
    flight_date,
    segment_status,
    flight_operational_completion_status,
    journey_completion_status,
    is_completed,
    is_cancelled
from final
