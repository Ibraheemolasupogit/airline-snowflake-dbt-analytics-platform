-- Grain is one row per invoice (invoice_id). Reuses int_outstanding_balance rather than
-- recomputing invoice arithmetic, payment allocation, or refund/adjustment logic, and adds
-- surrogate dimension keys, following the established core-layer pattern. See
-- int_outstanding_balance's own comment for the exact formula, sign conventions, and why
-- credit_note_amount is exposed but not separately netted into outstanding_balance.
with outstanding_balance as (

    select
        invoice_id,
        booking_id,
        currency,
        source_invoice_total,
        amount_collected,
        refund_amount,
        net_adjustment_amount,
        credit_note_amount,
        outstanding_balance,
        settlement_status
    from {{ ref('int_outstanding_balance') }}

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
        outstanding_balance.invoice_id,
        invoices.invoice_key,
        outstanding_balance.booking_id,
        bookings.booking_key,
        currencies.currency_key,
        outstanding_balance.currency,
        outstanding_balance.source_invoice_total,
        outstanding_balance.amount_collected,
        outstanding_balance.refund_amount,
        outstanding_balance.net_adjustment_amount,
        outstanding_balance.credit_note_amount,
        outstanding_balance.outstanding_balance,
        outstanding_balance.settlement_status
    from outstanding_balance
    left join invoices
        on outstanding_balance.invoice_id = invoices.invoice_id
    left join bookings
        on outstanding_balance.booking_id = bookings.booking_id
    left join currencies
        on outstanding_balance.currency = currencies.currency_code

),

final as (

    select
        invoice_key,
        invoice_id,
        booking_key,
        booking_id,
        currency_key,
        currency,
        source_invoice_total,
        amount_collected,
        refund_amount,
        net_adjustment_amount,
        credit_note_amount,
        outstanding_balance,
        settlement_status
    from joined

)

select
    invoice_key,
    invoice_id,
    booking_key,
    booking_id,
    currency_key,
    currency,
    source_invoice_total,
    amount_collected,
    refund_amount,
    net_adjustment_amount,
    credit_note_amount,
    outstanding_balance,
    settlement_status
from final
