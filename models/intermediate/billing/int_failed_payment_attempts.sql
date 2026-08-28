-- Grain is one row per failed payment attempt. Filters int_payment_attempt_classification to
-- attempt_classification = 'failed' -- no new derivation, no billing-exception classification.
-- This is evidence only: the failed_payment controlled exception (see docs/data_models/
-- airline_synthetic_exception_catalogue.md) is an invoice whose every payment attempt is a row in
-- this model with no corresponding fct_payments row -- observable via int_invoice_payment_matching
-- / fct_invoices.payment_count, not flagged here.
with failed_attempts as (

    select
        payment_attempt_id,
        invoice_id,
        booking_id,
        attempt_datetime_utc,
        method,
        amount,
        currency,
        raw_failure_reason,
        classified_failure_reason
    from {{ ref('int_payment_attempt_classification') }}
    where attempt_classification = 'failed'

)

select
    payment_attempt_id,
    invoice_id,
    booking_id,
    attempt_datetime_utc,
    method,
    amount,
    currency,
    raw_failure_reason,
    classified_failure_reason
from failed_attempts
