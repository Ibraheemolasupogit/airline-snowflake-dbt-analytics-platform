with bookings as (

    select
        booking_status,
        trip_type,
        passenger_count,
        ticket_count
    from {{ ref('fct_bookings') }}

),

aggregated as (

    select
        booking_status,
        trip_type,
        count(*) as booking_count,
        sum(passenger_count) as total_passenger_count,
        sum(ticket_count) as total_ticket_count
    from bookings
    group by booking_status, trip_type

)

select
    booking_status,
    trip_type,
    booking_count,
    total_passenger_count,
    total_ticket_count
from aggregated
