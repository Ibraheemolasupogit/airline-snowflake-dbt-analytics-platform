-- Grain is one row per payment transaction (payment_id). Upstream models are
-- stg_airline__payments and stg_airline__invoices, LEFT JOINed on invoice_id so that a payment
-- whose invoice_id does not resolve to a real invoice is preserved, not dropped -- the
-- deliberately injected payment_without_invoice controlled exception (see docs/data_models/
-- airline_synthetic_exception_catalogue.md) references invoice_id = 'INV-99999', which does not
-- exist in stg_airline__invoices; that row surfaces here with has_invoice_match = false and every
-- invoice-derived column null, never removed or repaired.
--
-- is_currency_match compares stg_airline__payments.currency directly against its invoice's
-- currency -- no conversion is attempted (per this milestone's scope boundary), so the
-- deliberately injected currency_mismatch exception surfaces as is_currency_match = false with
-- both raw currencies preserved side by side. is_currency_match is null (not false) when there is
-- no invoice to compare against at all.
--
-- payment_delay_days = payment_datetime_utc - invoice_date_utc, in days. The Milestone 9
-- specification defines no fixed "late" threshold anywhere (the exception catalogue's
-- late_arriving_payment entry only says normal turnaround is hours, not a numeric cutoff), so this
-- model exposes the raw deterministic day count rather than inventing a boolean is_late flag or an
-- arbitrary threshold; a later milestone can define one against this field if needed.
with payments as (

    select
        payment_id,
        payment_attempt_id,
        invoice_id,
        payment_datetime_utc,
        method,
        amount,
        currency,
        allocation_status
    from {{ ref('stg_airline__payments') }}

),

invoices as (

    select
        invoice_id,
        booking_id,
        invoice_date_utc,
        currency as invoice_currency
    from {{ ref('stg_airline__invoices') }}

),

joined as (

    select
        payments.payment_id,
        payments.payment_attempt_id,
        payments.invoice_id,
        invoices.booking_id,
        payments.payment_datetime_utc,
        invoices.invoice_date_utc,
        payments.method,
        payments.amount as transaction_amount,
        payments.currency as transaction_currency,
        invoices.invoice_currency,
        payments.allocation_status,
        invoices.invoice_id is not null as has_invoice_match,
        case
            when invoices.invoice_id is null then null
            else payments.currency = invoices.invoice_currency
        end as is_currency_match,
        case
            when invoices.invoice_id is null then 'unmatched_invoice_missing'
            else 'matched'
        end as match_status,
        case
            when invoices.invoice_date_utc is null then null
            else datediff('day', invoices.invoice_date_utc, payments.payment_datetime_utc)
        end as payment_delay_days
    from payments
    left join invoices
        on payments.invoice_id = invoices.invoice_id

)

select
    payment_id,
    payment_attempt_id,
    invoice_id,
    booking_id,
    payment_datetime_utc,
    invoice_date_utc,
    method,
    transaction_amount,
    transaction_currency,
    invoice_currency,
    allocation_status,
    has_invoice_match,
    is_currency_match,
    match_status,
    payment_delay_days
from joined
