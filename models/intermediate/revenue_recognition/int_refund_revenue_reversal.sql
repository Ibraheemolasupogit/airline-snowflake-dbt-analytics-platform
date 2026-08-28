-- Grain is one row per refund (refund_id). Reuses fct_refunds (Milestone 16) and
-- int_ticket_revenue_recognition rather than re-deriving refund or recognition logic.
--
-- A refund does not automatically reverse already-recognised revenue: related_recognised_revenue
-- sums int_ticket_revenue_recognition.recognised_amount across every ticket under the refund's own
-- booking_id (a refund is booking-scoped in the source, not tied to one specific ticket -- see
-- docs/data_models/airline_refunds_adjustments.md). reversal_eligibility is true only when that sum
-- is positive -- i.e. only when at least one ticket under the booking had actually flown before the
-- refund. Verified against scripts/airline_synth/build_billing.py: a refund is only ever generated
-- for a CANCELLED booking with a successful payment, and a cancelled booking's ticket_segments are
-- cancelled throughout (never flown), so reversal_eligibility is expected to be false -- and
-- reversal_amount 0 -- for essentially every refund in the current dataset. This is the correct,
-- source-grounded outcome, not a bug: a refund for a service that was never rendered has no
-- recognised revenue to reverse in the first place.
--
-- reversal_amount = least(refund_amount, related_recognised_revenue) when eligible, else 0 -- never
-- reversing more recognised revenue than is defensibly associated with the refund's booking,
-- matching the same least()-capping pattern this repository already uses for Milestone 13's
-- discount capping and Milestone 15's payment allocation capping.
with refunds as (

    select
        refund_id,
        payment_id,
        invoice_id,
        booking_id,
        refund_datetime_utc,
        refund_amount,
        currency
    from {{ ref('fct_refunds') }}

),

recognised_by_booking as (

    select
        booking_id,
        sum(recognised_amount) as related_recognised_revenue
    from {{ ref('int_ticket_revenue_recognition') }}
    group by booking_id

),

joined as (

    select
        refunds.refund_id,
        refunds.payment_id,
        refunds.invoice_id,
        refunds.booking_id,
        refunds.refund_datetime_utc,
        refunds.currency,
        refunds.refund_amount,
        coalesce(recognised_by_booking.related_recognised_revenue, 0) as related_recognised_revenue
    from refunds
    left join recognised_by_booking
        on refunds.booking_id = recognised_by_booking.booking_id

),

final as (

    select
        refund_id,
        payment_id,
        invoice_id,
        booking_id,
        refund_datetime_utc,
        currency,
        refund_amount,
        related_recognised_revenue,
        related_recognised_revenue > 0 as reversal_eligibility,
        case
            when related_recognised_revenue > 0
                then least(refund_amount, related_recognised_revenue)
            else 0
        end as reversal_amount
    from joined

)

select
    refund_id,
    payment_id,
    invoice_id,
    booking_id,
    refund_datetime_utc,
    currency,
    refund_amount,
    related_recognised_revenue,
    reversal_eligibility,
    cast(reversal_amount as decimal(18, 2)) as reversal_amount
from final
