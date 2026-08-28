-- Preserves the source total_amount and booking_id exactly as generated, including the
-- deliberately injected duplicate-invoice and missing-invoice-line controlled exceptions.
with source as (

    select *
    from {{ source('airline_billing', 'invoices') }}

),

renamed as (

    select
        nullif(trim(cast(invoice_id as varchar)), '') as invoice_id,
        nullif(trim(cast(booking_id as varchar)), '') as booking_id,
        try_to_timestamp_ntz(nullif(trim(cast(invoice_date_utc as varchar)), '')) as invoice_date_utc,
        nullif(trim(cast(currency as varchar)), '') as currency,
        nullif(trim(cast(bill_to_type as varchar)), '') as bill_to_type,
        nullif(trim(cast(bill_to_id as varchar)), '') as bill_to_id,
        try_to_decimal(nullif(trim(cast(subtotal_amount as varchar)), ''), 18, 2) as subtotal_amount,
        try_to_decimal(nullif(trim(cast(tax_amount as varchar)), ''), 18, 2) as tax_amount,
        try_to_decimal(nullif(trim(cast(fee_amount as varchar)), ''), 18, 2) as fee_amount,
        try_to_decimal(nullif(trim(cast(ancillary_amount as varchar)), ''), 18, 2) as ancillary_amount,
        try_to_decimal(nullif(trim(cast(discount_amount as varchar)), ''), 18, 2) as discount_amount,
        try_to_decimal(nullif(trim(cast(total_amount as varchar)), ''), 18, 2) as total_amount,
        nullif(trim(cast(status as varchar)), '') as status
    from source

)

select
    invoice_id,
    booking_id,
    invoice_date_utc,
    currency,
    bill_to_type,
    bill_to_id,
    subtotal_amount,
    tax_amount,
    fee_amount,
    ancillary_amount,
    discount_amount,
    total_amount,
    status
from renamed
