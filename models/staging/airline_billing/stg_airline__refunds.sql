-- Preserves amount exactly as generated, including the deliberately injected
-- refund_greater_than_collected_amount controlled exception.
with source as (

    select *
    from {{ source('airline_billing', 'refunds') }}

),

renamed as (

    select
        nullif(trim(cast(refund_id as varchar)), '') as refund_id,
        nullif(trim(cast(invoice_id as varchar)), '') as invoice_id,
        nullif(trim(cast(booking_id as varchar)), '') as booking_id,
        nullif(trim(cast(payment_id as varchar)), '') as payment_id,
        try_to_timestamp_ntz(nullif(trim(cast(refund_datetime_utc as varchar)), '')) as refund_datetime_utc,
        nullif(trim(cast(reason as varchar)), '') as reason,
        try_to_decimal(nullif(trim(cast(amount as varchar)), ''), 18, 2) as amount,
        nullif(trim(cast(currency as varchar)), '') as currency,
        nullif(trim(cast(method as varchar)), '') as method,
        nullif(trim(cast(status as varchar)), '') as status
    from source

)

select
    refund_id,
    invoice_id,
    booking_id,
    payment_id,
    refund_datetime_utc,
    reason,
    amount,
    currency,
    method,
    status
from renamed
