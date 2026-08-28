-- Grain is one row per refund (refund_id). Upstream model is int_refund_payment_matching. Exposes
-- refund-limit evidence -- calculation evidence only, not a billing-exception classification (no
-- severity/financial-value-at-risk field).
--
-- refundable_amount_reference = matched_payment_amount: the ceiling a refund is expected not to
-- exceed. This is deliberately the specific matched payment's own amount, not an invoice-level
-- aggregate (e.g. fct_invoices.amount_collected) -- scripts/airline_synth/build_billing.py always
-- ties a refund to one specific payment_id and sets refund.amount = that payment's own collected
-- amount (successful_payment_amount), so the payment is the source's own reference point, not the
-- invoice as a whole.
--
-- refund_limit_variance = refund_amount - refundable_amount_reference. Positive means the refund
-- exceeds the amount collected on its matched payment -- calculation evidence for a later
-- milestone to classify, never capped, corrected, or flagged here. The deliberately injected
-- refund_greater_than_collected_amount controlled exception (see docs/data_models/
-- airline_synthetic_exception_catalogue.md) always inflates a refund by exactly 100.0 above its
-- linked payment's amount (scripts/airline_synth/exceptions.py), so that row's
-- refund_limit_variance reads 100.00 unmodified. refundable_amount_reference/refund_limit_variance
-- are null when has_payment_match is false (no payment to compare against).
--
-- cumulative_refunded_amount_for_payment = sum(refund_amount) across every refund matched to the
-- same payment_id. In the current dataset this always equals the single refund's own amount (the
-- generator never produces more than one refund per payment), but the column is computed as a
-- genuine sum, not a passthrough, so it remains correct if that ever changes -- the same
-- structurally-defensible-but-currently-trivial pattern this repository has already used for
-- Milestone 11's 'other' completion status and Milestone 12's 'not_flown' journey status.
with matching as (

    select
        refund_id,
        invoice_id,
        booking_id,
        payment_id,
        payment_invoice_id,
        refund_datetime_utc,
        reason,
        refund_amount,
        refund_currency,
        payment_amount,
        payment_currency,
        method,
        status,
        has_payment_match,
        is_currency_match
    from {{ ref('int_refund_payment_matching') }}

),

cumulative_by_payment as (

    select
        payment_id,
        sum(refund_amount) as cumulative_refunded_amount_for_payment
    from matching
    where payment_id is not null
    group by payment_id

),

joined as (

    select
        matching.refund_id,
        matching.invoice_id,
        matching.booking_id,
        matching.payment_id,
        matching.payment_invoice_id,
        matching.refund_datetime_utc,
        matching.reason,
        matching.refund_amount,
        matching.refund_currency,
        matching.payment_amount as refundable_amount_reference,
        matching.payment_currency,
        matching.method,
        matching.status,
        matching.has_payment_match,
        matching.is_currency_match,
        cumulative_by_payment.cumulative_refunded_amount_for_payment,
        case
            when matching.has_payment_match
                then matching.refund_amount - matching.payment_amount
        end as refund_limit_variance
    from matching
    left join cumulative_by_payment
        on matching.payment_id = cumulative_by_payment.payment_id

)

select
    refund_id,
    invoice_id,
    booking_id,
    payment_id,
    payment_invoice_id,
    refund_datetime_utc,
    reason,
    refund_amount,
    refund_currency,
    refundable_amount_reference,
    payment_currency,
    method,
    status,
    has_payment_match,
    is_currency_match,
    cumulative_refunded_amount_for_payment,
    cast(refund_limit_variance as decimal(18, 2)) as refund_limit_variance
from joined
