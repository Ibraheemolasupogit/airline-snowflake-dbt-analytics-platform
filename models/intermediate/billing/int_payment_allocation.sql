-- Grain is one row per payment-to-invoice allocation. In this dataset every payment references at
-- most one invoice (scripts/airline_synth/build_billing.py never splits a payment across
-- invoices, and there is no partial-payment/instalment concept anywhere in the Milestone 9
-- specification), so this grain is identical to payment_id -- a deliberately simple allocation,
-- not an invented multi-invoice apportionment algorithm.
--
-- allocated_amount = least(transaction_amount, invoice's total_amount) when the payment has a
-- resolvable invoice, else 0 (a payment_without_invoice row has nothing to allocate against).
-- unallocated_amount = transaction_amount - allocated_amount. Both use fixed-point decimal(18, 2)
-- arithmetic throughout.
--
-- This reproduces the semantics of stg_airline__payments.allocation_status without depending on
-- it: a normal 'fully_allocated' payment (amount <= invoice total by construction) yields
-- unallocated_amount = 0; the deliberately injected unallocated_payment exception (payment amount
-- raised above its invoice total, allocation_status = 'overpaid_unallocated') yields a positive
-- unallocated_amount; the payment_without_invoice exception (allocation_status = 'unallocated')
-- yields allocated_amount = 0 and unallocated_amount = the full transaction_amount. The raw source
-- allocation_status is preserved alongside these calculated amounts, never overwritten, so later
-- assurance can compare them directly -- matching this repository's established source-vs-
-- calculated pattern (Milestone 14's int_invoice_calculation).
with matching as (

    select
        payment_id,
        payment_attempt_id,
        invoice_id,
        booking_id,
        payment_datetime_utc,
        method,
        transaction_amount,
        transaction_currency,
        invoice_currency,
        allocation_status,
        has_invoice_match,
        is_currency_match,
        match_status,
        payment_delay_days
    from {{ ref('int_invoice_payment_matching') }}

),

invoices as (

    select
        invoice_id,
        total_amount as invoice_total_amount
    from {{ ref('stg_airline__invoices') }}

),

joined as (

    select
        matching.payment_id,
        matching.payment_attempt_id,
        matching.invoice_id,
        matching.booking_id,
        matching.payment_datetime_utc,
        matching.method,
        matching.transaction_amount,
        matching.transaction_currency,
        matching.invoice_currency,
        matching.allocation_status,
        matching.has_invoice_match,
        matching.is_currency_match,
        matching.match_status,
        matching.payment_delay_days,
        invoices.invoice_total_amount,
        case
            when matching.has_invoice_match
                then least(matching.transaction_amount, invoices.invoice_total_amount)
            else 0
        end as allocated_amount
    from matching
    left join invoices
        on matching.invoice_id = invoices.invoice_id

)

select
    payment_id,
    payment_attempt_id,
    invoice_id,
    booking_id,
    payment_datetime_utc,
    method,
    transaction_amount as payment_amount,
    transaction_currency,
    invoice_currency,
    allocation_status,
    has_invoice_match,
    is_currency_match,
    match_status,
    payment_delay_days,
    cast(allocated_amount as decimal(18, 2)) as allocated_amount,
    cast(transaction_amount - allocated_amount as decimal(18, 2)) as unallocated_amount
from joined
