with source as (

    select *
    from {{ source('airline_billing', 'credit_notes') }}

),

renamed as (

    select
        nullif(trim(cast(credit_note_id as varchar)), '') as credit_note_id,
        nullif(trim(cast(invoice_id as varchar)), '') as invoice_id,
        nullif(trim(cast(refund_id as varchar)), '') as refund_id,
        nullif(trim(cast(adjustment_id as varchar)), '') as adjustment_id,
        try_to_decimal(nullif(trim(cast(amount as varchar)), ''), 18, 2) as amount,
        nullif(trim(cast(currency as varchar)), '') as currency,
        try_to_timestamp_ntz(nullif(trim(cast(issued_at_utc as varchar)), '')) as issued_at_utc,
        nullif(trim(cast(status as varchar)), '') as status
    from source

)

select
    credit_note_id,
    invoice_id,
    refund_id,
    adjustment_id,
    amount,
    currency,
    issued_at_utc,
    status
from renamed
