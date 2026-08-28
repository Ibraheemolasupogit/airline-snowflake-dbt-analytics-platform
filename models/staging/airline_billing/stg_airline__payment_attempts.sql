with source as (

    select *
    from {{ source('airline_billing', 'payment_attempts') }}

),

renamed as (

    select
        nullif(trim(cast(payment_attempt_id as varchar)), '') as payment_attempt_id,
        nullif(trim(cast(invoice_id as varchar)), '') as invoice_id,
        try_to_timestamp_ntz(nullif(trim(cast(attempt_datetime_utc as varchar)), '')) as attempt_datetime_utc,
        nullif(trim(cast(method as varchar)), '') as method,
        try_to_decimal(nullif(trim(cast(amount as varchar)), ''), 18, 2) as amount,
        nullif(trim(cast(currency as varchar)), '') as currency,
        nullif(trim(cast(result as varchar)), '') as result,
        nullif(trim(cast(failure_reason as varchar)), '') as failure_reason
    from source

)

select
    payment_attempt_id,
    invoice_id,
    attempt_datetime_utc,
    method,
    amount,
    currency,
    result,
    failure_reason
from renamed
