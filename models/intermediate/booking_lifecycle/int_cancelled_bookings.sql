-- Current-state cancelled-booking model. Grain is one row per cancelled booking
-- (int_booking_current_state.booking_status = 'cancelled'). No refund-eligibility, fare, or
-- monetary logic is calculated here -- that begins in later milestones (Refunds and Adjustments,
-- Milestone 16). affected_ticket_count / affected_ticket_segment_count are derived counts, not
-- fabricated: every ticket and ticket_segment under a cancelled booking is itself cancelled by
-- generator construction (scripts/airline_synth/build_bookings.py), so in this dataset these
-- counts equal ticket_count and (ticket_count * legs) respectively. There is no
-- cancellation-date field in the source (bookings carries only a current status, not a
-- status-change history -- see int_booking_current_state), so no cancellation_date column is
-- fabricated here; booking_date_utc is retained as the only dated reference point.
with cancelled_bookings as (

    select
        booking_id,
        booking_reference,
        airline_code,
        booking_channel,
        booking_date_utc,
        booking_status,
        corporate_account_id,
        travel_agent_id,
        passenger_count,
        ticket_count
    from {{ ref('int_booking_current_state') }}
    where booking_status = 'cancelled'

),

affected_ticket_counts as (

    select
        booking_id,
        count(distinct ticket_id) as affected_ticket_count
    from {{ ref('int_ticketed_segments') }}
    where ticket_status = 'cancelled'
    group by booking_id

),

affected_segment_counts as (

    select
        booking_id,
        count(*) as affected_ticket_segment_count
    from {{ ref('int_ticketed_segments') }}
    where segment_status = 'cancelled'
    group by booking_id

),

joined as (

    select
        cancelled_bookings.booking_id,
        cancelled_bookings.booking_reference,
        cancelled_bookings.airline_code,
        cancelled_bookings.booking_channel,
        cancelled_bookings.booking_date_utc,
        cancelled_bookings.booking_status,
        cancelled_bookings.corporate_account_id,
        cancelled_bookings.travel_agent_id,
        cancelled_bookings.passenger_count,
        cancelled_bookings.ticket_count,
        coalesce(affected_ticket_counts.affected_ticket_count, 0) as affected_ticket_count,
        coalesce(affected_segment_counts.affected_ticket_segment_count, 0) as affected_ticket_segment_count
    from cancelled_bookings
    left join affected_ticket_counts
        on cancelled_bookings.booking_id = affected_ticket_counts.booking_id
    left join affected_segment_counts
        on cancelled_bookings.booking_id = affected_segment_counts.booking_id

)

select
    booking_id,
    booking_reference,
    airline_code,
    booking_channel,
    booking_date_utc,
    booking_status,
    corporate_account_id,
    travel_agent_id,
    passenger_count,
    ticket_count,
    affected_ticket_count,
    affected_ticket_segment_count
from joined
