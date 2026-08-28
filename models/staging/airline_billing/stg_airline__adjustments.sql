-- Preserves invoice_id and amount exactly as generated, including the deliberately injected
-- invalid_adjustment controlled exception.
with source as (

    select *
    from {{ source('airline_billing', 'adjustments') }}

),

renamed as (

    select
        nullif(trim(cast(adjustment_id as varchar)), '') as adjustment_id,
        nullif(trim(cast(invoice_id as varchar)), '') as invoice_id,
        nullif(trim(cast(adjustment_type as varchar)), '') as adjustment_type,
        try_to_decimal(nullif(trim(cast(amount as varchar)), ''), 18, 2) as amount,
        nullif(trim(cast(currency as varchar)), '') as currency,
        nullif(trim(cast(reason as varchar)), '') as reason,
        try_to_timestamp_ntz(nullif(trim(cast(created_at_utc as varchar)), '')) as created_at_utc
    from source

)

select
    adjustment_id,
    invoice_id,
    adjustment_type,
    amount,
    currency,
    reason,
    created_at_utc
from renamed
