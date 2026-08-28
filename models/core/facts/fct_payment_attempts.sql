-- Grain is one row per payment attempt (payment_attempt_id). Reuses
-- int_payment_attempt_classification rather than re-deriving classification logic, and adds
-- surrogate dimension keys, following the established core-layer pattern. No refund or
-- revenue-recognition field exists on this fact -- those remain out of scope until Milestone 16+.
with classification as (

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
    from {{ ref('int_payment_attempt_classification') }}

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
        classification.payment_attempt_id,
        invoices.invoice_key,
        classification.invoice_id,
        bookings.booking_key,
        classification.booking_id,
        classification.attempt_datetime_utc,
        payment_methods.payment_method_key,
        classification.method,
        currencies.currency_key,
        classification.currency,
        classification.amount,
        classification.result,
        classification.attempt_classification,
        classification.raw_failure_reason,
        classification.classified_failure_reason
    from classification
    left join invoices
        on classification.invoice_id = invoices.invoice_id
    left join bookings
        on classification.booking_id = bookings.booking_id
    left join payment_methods
        on classification.method = payment_methods.method
    left join currencies
        on classification.currency = currencies.currency_code

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['payment_attempt_id']) }} as payment_attempt_key,
        payment_attempt_id,
        invoice_key,
        invoice_id,
        booking_key,
        booking_id,
        attempt_datetime_utc,
        payment_method_key,
        method,
        currency_key,
        currency,
        amount,
        result,
        attempt_classification,
        raw_failure_reason,
        classified_failure_reason
    from joined

)

select
    payment_attempt_key,
    payment_attempt_id,
    invoice_key,
    invoice_id,
    booking_key,
    booking_id,
    attempt_datetime_utc,
    payment_method_key,
    method,
    currency_key,
    currency,
    amount,
    result,
    attempt_classification,
    raw_failure_reason,
    classified_failure_reason
from final
