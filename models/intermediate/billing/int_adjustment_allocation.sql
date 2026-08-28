-- Grain is one row per adjustment (adjustment_id). Upstream models are stg_airline__adjustments
-- and stg_airline__invoices, LEFT JOINed on invoice_id so an adjustment whose invoice_id does not
-- resolve to a real invoice is preserved, not dropped -- the deliberately injected
-- invalid_adjustment controlled exception (see docs/data_models/airline_synthetic_exception_
-- catalogue.md) references invoice_id = 'INV-99998', which does not exist.
--
-- Sign convention, verified against scripts/airline_synth/build_billing.py::build_billing_documents
-- (the only place adjustments are generated in the normal flow): every 'credit'-type adjustment
-- is a NEGATIVE amount (`"amount": -adjustment_amount`), decreasing the amount due -- matching
-- ordinary accounting convention for a credit. No 'debit'-type adjustment is ever produced by the
-- current generator; 'debit' is a defined-but-currently-unused value in
-- stg_airline__adjustments.adjustment_type's own accepted domain, included here only because
-- staging documents it as valid, never fabricated. has_expected_sign_for_type is therefore true
-- when adjustment_type = 'credit' and amount <= 0, or adjustment_type = 'debit' and amount >= 0.
--
-- The invalid_adjustment exception is itself a sign-convention violation, not only a bad invoice
-- reference: it is adjustment_type = 'credit' with amount = +999999.0 (positive), the opposite of
-- every normal credit adjustment's sign (scripts/airline_synth/exceptions.py). This model exposes
-- that as has_expected_sign_for_type = false -- structural evidence for a later milestone to
-- classify, not a billing-exception label applied here.
--
-- booking_id is derived via the matched invoice (stg_airline__adjustments carries no booking_id
-- or ticket_id column of its own -- adjustments are invoice-level only in this specification); it
-- is null whenever has_invoice_match is false, which correctly reflects that the invalid_adjustment
-- row has no resolvable booking either.
with adjustments as (

    select
        adjustment_id,
        invoice_id,
        adjustment_type,
        amount,
        currency,
        reason,
        created_at_utc
    from {{ ref('stg_airline__adjustments') }}

),

invoices as (

    select
        invoice_id,
        booking_id,
        currency as invoice_currency
    from {{ ref('stg_airline__invoices') }}

),

joined as (

    select
        adjustments.adjustment_id,
        adjustments.invoice_id,
        invoices.booking_id,
        adjustments.adjustment_type,
        adjustments.amount,
        adjustments.currency,
        invoices.invoice_currency,
        adjustments.reason,
        adjustments.created_at_utc,
        invoices.invoice_id is not null as has_invoice_match,
        adjustments.adjustment_type in ('credit', 'debit') as has_supported_adjustment_type,
        case
            when invoices.invoice_id is null then null
            else adjustments.currency = invoices.invoice_currency
        end as is_currency_match,
        case
            when adjustments.adjustment_type = 'credit' then adjustments.amount <= 0
            when adjustments.adjustment_type = 'debit' then adjustments.amount >= 0
        end as has_expected_sign_for_type
    from adjustments
    left join invoices
        on adjustments.invoice_id = invoices.invoice_id

)

select
    adjustment_id,
    invoice_id,
    booking_id,
    adjustment_type,
    amount,
    currency,
    reason,
    created_at_utc,
    has_invoice_match,
    has_supported_adjustment_type,
    is_currency_match,
    has_expected_sign_for_type
from joined
