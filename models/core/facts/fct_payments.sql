-- Grain is one row per successful payment transaction (payment_id). Reuses int_payment_allocation
-- (which already reuses int_invoice_payment_matching) rather than re-deriving matching/allocation
-- logic, and adds surrogate dimension keys. No refunded-amount or revenue-recognition field exists
-- on this fact -- those remain out of scope until Milestone 16+.
--
-- invoice_key/booking_key are null for the deliberately injected payment_without_invoice
-- controlled exception (has_invoice_match = false) -- preserved, not repaired or dropped.
with allocation as (

    select
        payment_id,
        payment_attempt_id,
        invoice_id,
        booking_id,
        payment_datetime_utc,
        method,
        payment_amount,
        transaction_currency,
        invoice_currency,
        allocation_status,
        has_invoice_match,
        is_currency_match,
        match_status,
        payment_delay_days,
        allocated_amount,
        unallocated_amount
    from {{ ref('int_payment_allocation') }}

),

invoices as (

    select
        invoice_key,
        invoice_id
    from {{ ref('fct_invoices') }}

),

bookings as (

    select
        booking_key,
        booking_id
    from {{ ref('fct_bookings') }}

),

payment_methods as (

    select
        payment_method_key,
        method
    from {{ ref('dim_payment_method') }}

),

currencies as (

    select
        currency_key,
        currency_code
    from {{ ref('dim_currency') }}

),

joined as (

    select
        allocation.payment_id,
        allocation.payment_attempt_id,
        invoices.invoice_key,
        allocation.invoice_id,
        bookings.booking_key,
        allocation.booking_id,
        allocation.payment_datetime_utc,
        payment_methods.payment_method_key,
        allocation.method,
        currencies.currency_key,
        allocation.transaction_currency,
        allocation.invoice_currency,
        allocation.payment_amount,
        allocation.allocated_amount,
        allocation.unallocated_amount,
        allocation.allocation_status,
        allocation.has_invoice_match,
        allocation.is_currency_match,
        allocation.match_status,
        allocation.payment_delay_days
    from allocation
    left join invoices
        on allocation.invoice_id = invoices.invoice_id
    left join bookings
        on allocation.booking_id = bookings.booking_id
    left join payment_methods
        on allocation.method = payment_methods.method
    left join currencies
        on allocation.transaction_currency = currencies.currency_code

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['payment_id']) }} as payment_key,
        payment_id,
        payment_attempt_id,
        invoice_key,
        invoice_id,
        booking_key,
        booking_id,
        payment_datetime_utc,
        payment_method_key,
        method,
        currency_key,
        transaction_currency as currency,
        invoice_currency,
        payment_amount,
        allocated_amount,
        unallocated_amount,
        allocation_status,
        has_invoice_match,
        is_currency_match,
        match_status,
        payment_delay_days
    from joined

)

select
    payment_key,
    payment_id,
    payment_attempt_id,
    invoice_key,
    invoice_id,
    booking_key,
    booking_id,
    payment_datetime_utc,
    payment_method_key,
    method,
    currency_key,
    currency,
    invoice_currency,
    payment_amount,
    allocated_amount,
    unallocated_amount,
    allocation_status,
    has_invoice_match,
    is_currency_match,
    match_status,
    payment_delay_days
from final
