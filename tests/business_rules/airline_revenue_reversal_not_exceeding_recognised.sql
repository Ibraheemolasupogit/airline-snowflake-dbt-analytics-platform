-- Fails if any refund_reversal event's magnitude exceeds the recognised revenue actually
-- associated with its booking -- the invariant int_refund_revenue_reversal's least() capping is
-- meant to guarantee. Verified directly against fct_revenue (not just the upstream intermediate
-- model) so a future change to the fact-layer join cannot silently violate it.
with related_recognised_revenue as (

    select
        booking_id,
        sum(gross_recognised_amount) as recognised_revenue
    from {{ ref('fct_revenue') }}
    where event_type = 'ticket_revenue'
    group by booking_id

)

select
    fct_revenue.revenue_event_key,
    fct_revenue.reversal_or_adjustment_amount,
    related_recognised_revenue.recognised_revenue
from {{ ref('fct_revenue') }}
left join related_recognised_revenue
    on fct_revenue.booking_id = related_recognised_revenue.booking_id
where
    fct_revenue.event_type = 'refund_reversal'
    and abs(fct_revenue.reversal_or_adjustment_amount)
    > coalesce(related_recognised_revenue.recognised_revenue, 0) + 0.01
