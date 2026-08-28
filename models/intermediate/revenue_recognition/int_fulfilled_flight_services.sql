-- Grain is one row per passenger ticket segment / journey leg (ticket_segment_id), identical to
-- int_passenger_journey_completion's (Milestone 12) own grain. Reuses that model's
-- journey_completion_status/is_completed derivation directly rather than redefining flight
-- completion semantics -- this model adds no new completion logic of its own, only the route/fare
-- context journey_completion doesn't carry (by design; see its own model comment) and an explicit
-- fulfilment_indicator alias for readability in the revenue-recognition layer.
--
-- fulfilment_indicator = is_completed = (journey_completion_status = 'completed'), i.e.
-- segment_status = 'flown' on a flight_instance whose operational_completion_status = 'completed'
-- -- deterministic and source-supported, matching docs/data_models/airline_synthetic_source_data.md's
-- "Determining fulfilment for later revenue recognition" section exactly: "flight_instances.status
-- = 'completed' and ticket_segments.segment_status = 'flown' together mean the segment was
-- actually flown."
with journey_completion as (

    select
        ticket_segment_id,
        ticket_id,
        booking_id,
        passenger_id,
        flight_instance_id,
        segment_status,
        flight_operational_completion_status as operational_completion_status,
        journey_completion_status,
        is_completed,
        is_cancelled
    from {{ ref('int_passenger_journey_completion') }}

),

ticketed_segments as (

    select
        ticket_segment_id,
        route_id,
        origin_ident,
        destination_ident,
        fare_class_code,
        cabin
    from {{ ref('int_ticketed_segments') }}

),

joined as (

    select
        journey_completion.ticket_segment_id,
        journey_completion.ticket_id,
        journey_completion.booking_id,
        journey_completion.passenger_id,
        journey_completion.flight_instance_id,
        ticketed_segments.route_id,
        ticketed_segments.origin_ident,
        ticketed_segments.destination_ident,
        ticketed_segments.fare_class_code,
        ticketed_segments.cabin,
        journey_completion.journey_completion_status,
        journey_completion.operational_completion_status,
        journey_completion.is_completed as fulfilment_indicator,
        journey_completion.is_cancelled
    from journey_completion
    left join ticketed_segments
        on journey_completion.ticket_segment_id = ticketed_segments.ticket_segment_id

)

select
    ticket_segment_id,
    ticket_id,
    booking_id,
    passenger_id,
    flight_instance_id,
    route_id,
    origin_ident,
    destination_ident,
    fare_class_code,
    cabin,
    journey_completion_status,
    operational_completion_status,
    fulfilment_indicator,
    is_cancelled
from joined
