-- Grain is one row per adjustment (adjustment_id). Reuses fct_adjustments (Milestone 16) and
-- int_ticket_revenue_recognition rather than re-deriving adjustment or recognition logic.
--
-- Not every adjustment is revenue-affecting by default: revenue_impact_indicator is true only when
-- the adjustment resolves to a real invoice/booking (has_invoice_match, so the deliberately
-- injected invalid_adjustment exception is automatically excluded) AND that booking has positive
-- related_recognised_revenue (at least one of its tickets actually flew) -- the same "only impacts
-- revenue if revenue exists to impact" principle this milestone already applies to refund
-- reversals, applied here by extension for consistency, not a new invented rule.
--
-- recognised_adjustment_amount preserves adjustment.amount's own native sign (credit = negative,
-- decreasing amount due; debit = positive -- see docs/data_models/airline_refunds_adjustments.md)
-- while capping its magnitude at related_recognised_revenue, so an adjustment can never remove more
-- revenue than was actually recognised for its booking -- the same defensible capping principle
-- used for refund reversals. It is 0 when revenue_impact_indicator is false.
with adjustments as (

    select
        adjustment_id,
        invoice_id,
        booking_id,
        adjustment_type,
        amount,
        currency,
        created_at_utc,
        has_invoice_match
    from {{ ref('fct_adjustments') }}

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
        adjustments.adjustment_id,
        adjustments.invoice_id,
        adjustments.booking_id,
        adjustments.adjustment_type,
        adjustments.currency,
        adjustments.amount,
        adjustments.created_at_utc,
        adjustments.has_invoice_match,
        coalesce(recognised_by_booking.related_recognised_revenue, 0) as related_recognised_revenue
    from adjustments
    left join recognised_by_booking
        on adjustments.booking_id = recognised_by_booking.booking_id

),

final as (

    select
        adjustment_id,
        invoice_id,
        booking_id,
        adjustment_type,
        currency,
        amount,
        created_at_utc,
        has_invoice_match,
        related_recognised_revenue,
        has_invoice_match and related_recognised_revenue > 0 as revenue_impact_indicator,
        case
            when has_invoice_match and related_recognised_revenue > 0
                then sign(amount) * least(abs(amount), related_recognised_revenue)
            else 0
        end as recognised_adjustment_amount
    from joined

)

select
    adjustment_id,
    invoice_id,
    booking_id,
    adjustment_type,
    currency,
    amount,
    created_at_utc,
    has_invoice_match,
    related_recognised_revenue,
    revenue_impact_indicator,
    cast(recognised_adjustment_amount as decimal(18, 2)) as recognised_adjustment_amount
from final
