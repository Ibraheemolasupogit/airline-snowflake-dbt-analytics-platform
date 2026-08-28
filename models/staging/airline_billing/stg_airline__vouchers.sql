with source as (

    select *
    from {{ source('airline_billing', 'vouchers') }}

),

renamed as (

    select
        nullif(trim(cast(voucher_id as varchar)), '') as voucher_id,
        nullif(trim(cast(passenger_id as varchar)), '') as passenger_id,
        nullif(trim(cast(issued_from as varchar)), '') as issued_from,
        try_to_decimal(nullif(trim(cast(amount as varchar)), ''), 18, 2) as amount,
        nullif(trim(cast(currency as varchar)), '') as currency,
        try_to_timestamp_ntz(nullif(trim(cast(issued_at_utc as varchar)), '')) as issued_at_utc,
        try_to_date(nullif(trim(cast(expiry_date as varchar)), '')) as expiry_date,
        nullif(trim(cast(status as varchar)), '') as status,
        nullif(trim(cast(redeemed_booking_id as varchar)), '') as redeemed_booking_id
    from source

)

select
    voucher_id,
    passenger_id,
    issued_from,
    amount,
    currency,
    issued_at_utc,
    expiry_date,
    status,
    redeemed_booking_id
from renamed
