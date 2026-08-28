-- Grain is one row per (booking channel, currency). Reuses fct_revenue directly for recognised
-- revenue; no pricing logic is recomputed. booking_channel is resolved via fct_revenue.booking_id
-- -> fct_bookings.booking_channel_key -> dim_booking_channel -- every revenue event is
-- booking-scoped, so this join is safe at every event_type's own grain (no fan-out).
with bookings as (

    select
        booking_id,
        booking_channel_key
    from {{ ref('fct_bookings') }}

),

booking_channels as (

    select
        booking_channel_key,
        booking_channel
    from {{ ref('dim_booking_channel') }}

),

revenue_events as (

    select
        booking_id,
        currency,
        event_type,
        gross_recognised_amount
    from {{ ref('fct_revenue') }}
    where event_type in ('ticket_revenue', 'ancillary_revenue')

),

attributed_revenue as (

    select
        booking_channels.booking_channel_key,
        booking_channels.booking_channel,
        revenue_events.currency,
        revenue_events.event_type,
        revenue_events.gross_recognised_amount
    from revenue_events
    left join bookings
        on revenue_events.booking_id = bookings.booking_id
    left join booking_channels
        on bookings.booking_channel_key = booking_channels.booking_channel_key

),

aggregated as (

    select
        booking_channel_key,
        booking_channel,
        currency,
        sum(case when event_type = 'ticket_revenue' then gross_recognised_amount else 0 end)
            as recognised_ticket_revenue,
        sum(case when event_type = 'ancillary_revenue' then gross_recognised_amount else 0 end)
            as recognised_ancillary_revenue,
        sum(gross_recognised_amount) as total_recognised_revenue
    from attributed_revenue
    group by booking_channel_key, booking_channel, currency

)

select
    booking_channel_key,
    booking_channel,
    currency,
    cast(recognised_ticket_revenue as decimal(18, 2)) as recognised_ticket_revenue,
    cast(recognised_ancillary_revenue as decimal(18, 2)) as recognised_ancillary_revenue,
    cast(total_recognised_revenue as decimal(18, 2)) as total_recognised_revenue
from aggregated
