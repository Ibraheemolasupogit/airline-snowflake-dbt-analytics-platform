-- Preserves invoice_id, amount, and currency exactly as generated, including the deliberately
-- injected payment_without_invoice, unallocated_payment, late_arriving_payment, and
-- currency_mismatch controlled exceptions documented in exception_manifest.csv.
with source as (

    select *
    from {{ source('airline_billing', 'payments') }}

),

renamed as (

    select
        nullif(trim(cast(payment_id as varchar)), '') as payment_id,
        nullif(trim(cast(payment_attempt_id as varchar)), '') as payment_attempt_id,
        nullif(trim(cast(invoice_id as varchar)), '') as invoice_id,
        try_to_timestamp_ntz(nullif(trim(cast(payment_datetime_utc as varchar)), '')) as payment_datetime_utc,
        nullif(trim(cast(method as varchar)), '') as method,
        try_to_decimal(nullif(trim(cast(amount as varchar)), ''), 18, 2) as amount,
        nullif(trim(cast(currency as varchar)), '') as currency,
        nullif(trim(cast(allocation_status as varchar)), '') as allocation_status
    from source

)

select
    payment_id,
    payment_attempt_id,
    invoice_id,
    payment_datetime_utc,
    method,
    amount,
    currency,
    allocation_status
from renamed
