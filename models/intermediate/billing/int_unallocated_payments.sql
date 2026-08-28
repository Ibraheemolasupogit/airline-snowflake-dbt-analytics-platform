-- Grain is one row per payment with a positive unallocated amount. Filters int_payment_allocation
-- to unallocated_amount > 0 -- evidence only, no billing-exception classification (no severity,
-- ownership, financial-value-at-risk, or remediation field). Captures both the deliberately
-- injected unallocated_payment exception (an overpaid, invoice-matched payment) and the
-- payment_without_invoice exception (an entirely unmatched payment, 100% unallocated) with the
-- same evidence shape, since both are legitimately "amount collected that could not be applied to
-- an invoice."
with allocation as (

    select
        payment_id,
        invoice_id,
        booking_id,
        payment_datetime_utc,
        method,
        payment_amount,
        transaction_currency,
        allocation_status,
        has_invoice_match,
        is_currency_match,
        allocated_amount,
        unallocated_amount
    from {{ ref('int_payment_allocation') }}
    where unallocated_amount > 0

)

select
    payment_id,
    invoice_id,
    booking_id,
    payment_datetime_utc,
    method,
    payment_amount,
    transaction_currency,
    allocation_status,
    has_invoice_match,
    is_currency_match,
    allocated_amount,
    unallocated_amount
from allocation
