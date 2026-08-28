with source as (

    select *
    from {{ source('airline_bookings', 'booking_passengers') }}

),

renamed as (

    select
        nullif(trim(cast(booking_passenger_id as varchar)), '') as booking_passenger_id,
        nullif(trim(cast(booking_id as varchar)), '') as booking_id,
        nullif(trim(cast(passenger_id as varchar)), '') as passenger_id,
        nullif(trim(cast(passenger_type as varchar)), '') as passenger_type,
        try_to_number(nullif(trim(cast(seq_in_booking as varchar)), ''), 38, 0) as seq_in_booking
    from source

)

select
    booking_passenger_id,
    booking_id,
    passenger_id,
    passenger_type,
    seq_in_booking
from renamed
