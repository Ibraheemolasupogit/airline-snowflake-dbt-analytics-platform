-- Grain is one row per booking-passenger association (booking_passenger_id). Reuses
-- fct_bookings for booking_key rather than regenerating it, per the established
-- single-generation-point surrogate-key pattern (docs/architecture/development_standards.md;
-- Milestone 11's dim_route/dim_flight join upstream dimensions for their keys the same way).
with booking_passengers as (

    select
        booking_passenger_id,
        booking_id,
        passenger_id,
        passenger_type,
        seq_in_booking,
        booking_status,
        ticket_id,
        ticket_status,
        fare_class_code,
        cabin
    from {{ ref('int_booking_passengers') }}

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
        booking_passengers.booking_passenger_id,
        bookings.booking_key,
        booking_passengers.booking_id,
        passengers.passenger_key,
        booking_passengers.passenger_id,
        booking_passengers.passenger_type,
        booking_passengers.seq_in_booking,
        booking_passengers.booking_status,
        booking_passengers.ticket_id,
        booking_passengers.ticket_status,
        fare_classes.fare_class_key,
        booking_passengers.fare_class_code,
        cabins.cabin_key,
        booking_passengers.cabin
    from booking_passengers
    left join bookings
        on booking_passengers.booking_id = bookings.booking_id
    left join passengers
        on booking_passengers.passenger_id = passengers.passenger_id
    left join fare_classes
        on booking_passengers.fare_class_code = fare_classes.fare_class_code
    left join cabins
        on booking_passengers.cabin = cabins.cabin

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['booking_passenger_id']) }} as booking_passenger_key,
        booking_passenger_id,
        booking_key,
        booking_id,
        passenger_key,
        passenger_id,
        passenger_type,
        seq_in_booking,
        booking_status,
        ticket_id,
        ticket_status,
        fare_class_key,
        fare_class_code,
        cabin_key,
        cabin
    from joined

)

select
    booking_passenger_key,
    booking_passenger_id,
    booking_key,
    booking_id,
    passenger_key,
    passenger_id,
    passenger_type,
    seq_in_booking,
    booking_status,
    ticket_id,
    ticket_status,
    fare_class_key,
    fare_class_code,
    cabin_key,
    cabin
from final
