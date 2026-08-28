-- Reusable booking-passenger relationship model. Grain is one row per booking-passenger
-- association (booking_passenger_id). Joins bookings -> booking_passengers -> passengers, plus
-- each passenger's single ticket for this booking (the Milestone 9 generator issues exactly one
-- ticket per booking-passenger pair, so this join does not fan out) and that ticket's fare class,
-- for its cabin attribute only. No fare values are introduced.
with booking_passengers as (

    select
        booking_passenger_id,
        booking_id,
        passenger_id,
        passenger_type,
        seq_in_booking
    from {{ ref('stg_airline__booking_passengers') }}

),

bookings as (

    select
        booking_id,
        booking_reference,
        airline_code,
        booking_channel,
        booking_date_utc,
        status as booking_status,
        corporate_account_id,
        travel_agent_id
    from {{ ref('stg_airline__bookings') }}

),

passengers as (

    select
        passenger_id,
        first_name,
        last_name,
        nationality,
        loyalty_tier
    from {{ ref('stg_airline__passengers') }}

),

tickets as (

    select
        ticket_id,
        ticket_number,
        booking_id,
        passenger_id,
        fare_class_code,
        issue_date_utc,
        ticket_status
    from {{ ref('stg_airline__tickets') }}

),

fare_classes as (

    select
        fare_class_code,
        cabin
    from {{ ref('stg_airline__fare_classes') }}

),

joined as (

    select
        booking_passengers.booking_passenger_id,
        booking_passengers.booking_id,
        booking_passengers.passenger_id,
        booking_passengers.passenger_type,
        booking_passengers.seq_in_booking,
        bookings.booking_reference,
        bookings.airline_code,
        bookings.booking_channel,
        bookings.booking_date_utc,
        bookings.booking_status,
        bookings.corporate_account_id,
        bookings.travel_agent_id,
        passengers.first_name,
        passengers.last_name,
        passengers.nationality,
        passengers.loyalty_tier,
        tickets.ticket_id,
        tickets.ticket_number,
        tickets.fare_class_code,
        fare_classes.cabin,
        tickets.issue_date_utc,
        tickets.ticket_status
    from booking_passengers
    left join bookings
        on booking_passengers.booking_id = bookings.booking_id
    left join passengers
        on booking_passengers.passenger_id = passengers.passenger_id
    left join tickets
        on
            booking_passengers.booking_id = tickets.booking_id
            and booking_passengers.passenger_id = tickets.passenger_id
    left join fare_classes
        on tickets.fare_class_code = fare_classes.fare_class_code

)

select
    booking_passenger_id,
    booking_id,
    passenger_id,
    passenger_type,
    seq_in_booking,
    booking_reference,
    airline_code,
    booking_channel,
    booking_date_utc,
    booking_status,
    corporate_account_id,
    travel_agent_id,
    first_name,
    last_name,
    nationality,
    loyalty_tier,
    ticket_id,
    ticket_number,
    fare_class_code,
    cabin,
    issue_date_utc,
    ticket_status
from joined
