-- Current-state booking lifecycle model. Grain is one row per booking (booking_id). The
-- Milestone 9 source captures only each booking's current status
-- (stg_airline__bookings.status), not a status-change history table, so this is deliberately
-- named "current_state" rather than "status_history" -- no historical booking events (created ->
-- confirmed -> cancelled, etc.) are fabricated here. passenger_count and ticket_count are
-- structural counts derived from booking_passengers/tickets, not fare or revenue measures.
with bookings as (

    select
        booking_id,
        booking_reference,
        airline_code,
        route_id,
        return_route_id,
        trip_type,
        booking_channel,
        booking_date_utc,
        point_of_sale_country,
        currency,
        status,
        corporate_account_id,
        travel_agent_id,
        discount_code,
        outbound_flight_instance_id,
        return_flight_instance_id
    from {{ ref('stg_airline__bookings') }}

),

passenger_counts as (

    select
        booking_id,
        count(*) as passenger_count
    from {{ ref('stg_airline__booking_passengers') }}
    group by booking_id

),

ticket_counts as (

    select
        booking_id,
        count(*) as ticket_count
    from {{ ref('stg_airline__tickets') }}
    group by booking_id

),

joined as (

    select
        bookings.booking_id,
        bookings.booking_reference,
        bookings.airline_code,
        bookings.route_id,
        bookings.return_route_id,
        bookings.trip_type,
        bookings.booking_channel,
        bookings.booking_date_utc,
        bookings.point_of_sale_country,
        bookings.currency,
        bookings.status as booking_status,
        bookings.corporate_account_id,
        bookings.travel_agent_id,
        bookings.discount_code,
        bookings.outbound_flight_instance_id,
        bookings.return_flight_instance_id,
        coalesce(passenger_counts.passenger_count, 0) as passenger_count,
        coalesce(ticket_counts.ticket_count, 0) as ticket_count,
        bookings.status = 'cancelled' as is_cancelled
    from bookings
    left join passenger_counts
        on bookings.booking_id = passenger_counts.booking_id
    left join ticket_counts
        on bookings.booking_id = ticket_counts.booking_id

)

select
    booking_id,
    booking_reference,
    airline_code,
    route_id,
    return_route_id,
    trip_type,
    booking_channel,
    booking_date_utc,
    point_of_sale_country,
    currency,
    booking_status,
    corporate_account_id,
    travel_agent_id,
    discount_code,
    outbound_flight_instance_id,
    return_flight_instance_id,
    passenger_count,
    ticket_count,
    is_cancelled
from joined
