-- Grain is one row per refund (refund_id). Upstream models are stg_airline__refunds and
-- stg_airline__payments, LEFT JOINed on payment_id so a refund whose payment_id does not resolve
-- would be preserved, not dropped, even though every refund in the current dataset does resolve
-- (verified against scripts/airline_synth/build_billing.py -- payment_id is always drawn from an
-- existing payments row in both the normal cancellation flow and the refund_greater_than_
-- collected_amount controlled exception's fallback branch).
--
-- invoice_id/booking_id are preserved directly from stg_airline__refunds -- both are native
-- columns on the refunds table itself (not derived), and both are documented and tested as
-- always resolving in staging (unlike adjustments.invoice_id, which is not).
--
-- is_currency_match compares refund_currency directly against the matched payment's own
-- currency -- no conversion is attempted. It is null (not false) when there is no payment to
-- compare against at all.
with refunds as (

    select
        refund_id,
        invoice_id,
        booking_id,
        payment_id,
        refund_datetime_utc,
        reason,
        amount,
        currency,
        method,
        status
    from {{ ref('stg_airline__refunds') }}

),

payments as (

    select
        payment_id,
        invoice_id as payment_invoice_id,
        amount as payment_amount,
        currency as payment_currency
    from {{ ref('stg_airline__payments') }}

),

joined as (

    select
        refunds.refund_id,
        refunds.invoice_id,
        refunds.booking_id,
        refunds.payment_id,
        payments.payment_invoice_id,
        refunds.refund_datetime_utc,
        refunds.reason,
        refunds.amount as refund_amount,
        refunds.currency as refund_currency,
        payments.payment_amount,
        payments.payment_currency,
        refunds.method,
        refunds.status,
        payments.payment_id is not null as has_payment_match,
        case
            when payments.payment_id is null then null
            else refunds.currency = payments.payment_currency
        end as is_currency_match
    from refunds
    left join payments
        on refunds.payment_id = payments.payment_id

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
    payment_amount,
    payment_currency,
    method,
    status,
    has_payment_match,
    is_currency_match
from joined
