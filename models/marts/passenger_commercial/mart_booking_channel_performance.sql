with bookings as (

    select
        booking_channel_key,
        booking_channel,
        is_cancelled,
        passenger_count,
        ticket_count
    from {{ ref('fct_bookings') }}

),

aggregated as (

    select
        booking_channel_key,
        booking_channel,
        count(*) as booking_count,
        sum(case when is_cancelled then 1 else 0 end) as cancelled_booking_count,
        sum(passenger_count) as total_passenger_count,
        sum(ticket_count) as total_ticket_count
    from bookings
    group by booking_channel_key, booking_channel

)

select
    booking_channel_key,
    booking_channel,
    booking_count,
    cancelled_booking_count,
    total_passenger_count,
    total_ticket_count,
    case when booking_count > 0 then cancelled_booking_count / booking_count end
        as cancellation_rate
from aggregated
