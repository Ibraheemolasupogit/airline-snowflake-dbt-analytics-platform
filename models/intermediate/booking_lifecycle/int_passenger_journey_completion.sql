-- Deterministic passenger journey-completion classification. Grain is one row per passenger
-- ticket segment / journey leg (ticket_segment_id), reusing int_ticketed_segments rather than
-- rebuilding the ticket/flight join. Named int_passenger_journey_completion rather than the
-- originally suggested int_completed_passenger_journeys because this model classifies every
-- segment's completion status (scheduled/completed/cancelled/not_flown/other), not only
-- completed ones -- a "completed_*" name would misdescribe its contents.
--
-- journey_completion_status is derived from ticket_segments.segment_status combined with the
-- linked flight_instance's operational_completion_status (Milestone 11), not fabricated:
--   - segment_status = 'cancelled'                                     -> 'cancelled'
--   - segment_status = 'flown' and flight is 'completed'                -> 'completed'
--   - segment_status = 'confirmed' and flight is 'scheduled'            -> 'scheduled'
--   - segment_status = 'confirmed' and flight is no longer scheduled
--     (resolved as completed/cancelled without a matching segment update) -> 'not_flown'
--   - any other combination (including unrecognised source values)     -> 'other'
--   - either status unknown (null)                                     -> null
--
-- In the current Milestone 9 dataset every 'confirmed' segment pairs with a 'scheduled' flight
-- and every 'flown' segment pairs with a 'completed' flight (verified against
-- scripts/airline_synth/build_bookings.py and scripts/airline_synth/exceptions.py), so
-- 'not_flown' currently yields zero rows here -- it exists as a defensible, structurally
-- meaningful category rather than a fabricated one, matching the 'other' fallback pattern already
-- used by int_operated_flight_segments.operational_completion_status.
--
-- Exception EXC-006 (cancelled_flight_without_refund, see
-- docs/data_models/airline_synthetic_exception_catalogue.md) flips one already-'completed'
-- flight_instance to 'cancelled' and cancels its ticket_segments, while deliberately leaving the
-- associated ticket/booking untouched. Those segments correctly resolve to 'cancelled' here even
-- though their ticket's ticket_status stays 'issued' -- that mismatch is the exception working as
-- designed, not a bug in this model.
with ticketed_segments as (

    select
        ticket_segment_id,
        ticket_id,
        booking_id,
        passenger_id,
        flight_instance_id,
        segment_status,
        flight_instance_status,
        operational_completion_status as flight_operational_completion_status
    from {{ ref('int_ticketed_segments') }}

),

classified as (

    select
        ticket_segment_id,
        ticket_id,
        booking_id,
        passenger_id,
        flight_instance_id,
        segment_status,
        flight_operational_completion_status,
        case
            when segment_status is null or flight_operational_completion_status is null then null
            when segment_status = 'cancelled' then 'cancelled'
            when segment_status = 'flown' and flight_operational_completion_status = 'completed'
                then 'completed'
            when segment_status = 'confirmed' and flight_operational_completion_status = 'scheduled'
                then 'scheduled'
            when
                segment_status = 'confirmed'
                and flight_operational_completion_status in ('completed', 'cancelled')
                then 'not_flown'
            else 'other'
        end as journey_completion_status
    from ticketed_segments

)

select
    ticket_segment_id,
    ticket_id,
    booking_id,
    passenger_id,
    flight_instance_id,
    segment_status,
    flight_operational_completion_status,
    journey_completion_status,
    journey_completion_status = 'completed' as is_completed,
    journey_completion_status = 'cancelled' as is_cancelled
from classified
