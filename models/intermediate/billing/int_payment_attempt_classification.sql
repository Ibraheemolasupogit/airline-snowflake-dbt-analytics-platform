-- Deterministic payment-attempt classification. Grain is one row per payment attempt
-- (payment_attempt_id). Upstream models are stg_airline__payment_attempts and
-- stg_airline__invoices (for booking_id only).
--
-- attempt_classification is derived directly from stg_airline__payment_attempts.result, which
-- verified against scripts/airline_synth/build_billing.py only ever takes the value 'success' or
-- 'failed' -- every attempt in this dataset already has a definitive terminal outcome. A 'pending'
-- category (an attempt still awaiting an outcome) is deliberately NOT used: no such concept exists
-- anywhere in the Milestone 9 generator, and inventing one would fabricate a state the source
-- cannot produce. 'other' is retained as a structurally defensible, forward-looking fallback for
-- any unrecognised result value, matching the same pattern Milestone 11's
-- operational_completion_status and Milestone 12's journey_completion_status already use for their
-- own 'other' fallbacks.
--
-- classified_failure_reason buckets stg_airline__payment_attempts.failure_reason (raw_failure_reason,
-- preserved unchanged) into a small number of categories actually justified by the three raw values
-- scripts/airline_synth/reference.py::FAILURE_REASONS produces ("card_declined", "insufficient_funds",
-- "bank_rejected"): 'card_declined' and 'bank_rejected' both represent the counterparty declining/
-- rejecting the attempt, so both map to 'declined'; 'insufficient_funds' is a materially different
-- root cause (the payer's own funds, not an issuer decision) and is kept as its own category rather
-- than folded into 'declined'. 'expired' / 'reversed' / 'incomplete' are deliberately NOT used as
-- categories: no card-expiry, post-success-reversal, or attempt-never-completed concept exists
-- anywhere in the Milestone 9 specification, so none of the three raw reasons can be honestly mapped
-- to them. 'other' is the defensive fallback for any unrecognised raw value.
with payment_attempts as (

    select
        payment_attempt_id,
        invoice_id,
        attempt_datetime_utc,
        method,
        amount,
        currency,
        result,
        failure_reason
    from {{ ref('stg_airline__payment_attempts') }}

),

invoices as (

    select
        invoice_id,
        booking_id
    from {{ ref('stg_airline__invoices') }}

),

joined as (

    select
        payment_attempts.payment_attempt_id,
        payment_attempts.invoice_id,
        invoices.booking_id,
        payment_attempts.attempt_datetime_utc,
        payment_attempts.method,
        payment_attempts.amount,
        payment_attempts.currency,
        payment_attempts.result,
        payment_attempts.failure_reason as raw_failure_reason,
        case
            when payment_attempts.result = 'success' then 'successful'
            when payment_attempts.result = 'failed' then 'failed'
            else 'other'
        end as attempt_classification,
        case
            when payment_attempts.failure_reason is null then null
            when payment_attempts.failure_reason in ('card_declined', 'bank_rejected') then 'declined'
            when payment_attempts.failure_reason = 'insufficient_funds' then 'insufficient_funds'
            else 'other'
        end as classified_failure_reason
    from payment_attempts
    left join invoices
        on payment_attempts.invoice_id = invoices.invoice_id

)

select
    payment_attempt_id,
    invoice_id,
    booking_id,
    attempt_datetime_utc,
    method,
    amount,
    currency,
    result,
    raw_failure_reason,
    attempt_classification,
    classified_failure_reason
from joined
