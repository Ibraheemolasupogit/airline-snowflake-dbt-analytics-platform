-- Preserves amount exactly as generated, including the deliberately injected incorrect_fare
-- controlled exception and the deliberately removed lines documented in exception_manifest.csv.
with source as (

    select *
    from {{ source('airline_billing', 'invoice_lines') }}

),

renamed as (

    select
        nullif(trim(cast(invoice_line_id as varchar)), '') as invoice_line_id,
        nullif(trim(cast(invoice_id as varchar)), '') as invoice_id,
        nullif(trim(cast(ticket_id as varchar)), '') as ticket_id,
        nullif(trim(cast(line_type as varchar)), '') as line_type,
        nullif(trim(cast(reference_code as varchar)), '') as reference_code,
        nullif(trim(cast(description as varchar)), '') as description,
        try_to_decimal(nullif(trim(cast(amount as varchar)), ''), 18, 2) as amount,
        nullif(trim(cast(currency as varchar)), '') as currency
    from source

)

select
    invoice_line_id,
    invoice_id,
    ticket_id,
    line_type,
    reference_code,
    description,
    amount,
    currency
from renamed
