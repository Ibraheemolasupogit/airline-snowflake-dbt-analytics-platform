-- Grain is one row per refund transaction (refund_id). Reuses int_refund_allocation rather than
-- re-deriving matching/allocation logic, and adds surrogate dimension keys. No revenue-reversal
-- field exists on this fact -- that remains out of scope until Milestone 17+.
with allocation as (

    select
        refund_id,
        invoice_id,
        booking_id,
        payment_id,
        refund_datetime_utc,
        reason,
        refund_amount,
        refund_currency,
        refundable_amount_reference,
        status,
        has_payment_match,
        is_currency_match,
        cumulative_refunded_amount_for_payment,
        refund_limit_variance
    from {{ ref('int_refund_allocation') }}

),

payments as (

    select
        payment_key,
        payment_id
    from {{ ref('fct_payments') }}

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

currencies as (

    select
        currency_key,
        currency_code
    from {{ ref('dim_currency') }}

),

joined as (

    select
        allocation.refund_id,
        payments.payment_key,
        allocation.payment_id,
        invoices.invoice_key,
        allocation.invoice_id,
        bookings.booking_key,
        allocation.booking_id,
        allocation.refund_datetime_utc,
        currencies.currency_key,
        allocation.refund_currency,
        allocation.reason,
        allocation.status,
        allocation.refund_amount,
        allocation.refundable_amount_reference,
        allocation.refund_limit_variance,
        allocation.cumulative_refunded_amount_for_payment,
        allocation.has_payment_match,
        allocation.is_currency_match
    from allocation
    left join payments
        on allocation.payment_id = payments.payment_id
    left join invoices
        on allocation.invoice_id = invoices.invoice_id
    left join bookings
        on allocation.booking_id = bookings.booking_id
    left join currencies
        on allocation.refund_currency = currencies.currency_code

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['refund_id']) }} as refund_key,
        refund_id,
        payment_key,
        payment_id,
        invoice_key,
        invoice_id,
        booking_key,
        booking_id,
        refund_datetime_utc,
        currency_key,
        refund_currency as currency,
        reason,
        status,
        refund_amount,
        refundable_amount_reference,
        refund_limit_variance,
        cumulative_refunded_amount_for_payment,
        has_payment_match,
        is_currency_match
    from joined

)

select
    refund_key,
    refund_id,
    payment_key,
    payment_id,
    invoice_key,
    invoice_id,
    booking_key,
    booking_id,
    refund_datetime_utc,
    currency_key,
    currency,
    reason,
    status,
    refund_amount,
    refundable_amount_reference,
    refund_limit_variance,
    cumulative_refunded_amount_for_payment,
    has_payment_match,
    is_currency_match
from final
