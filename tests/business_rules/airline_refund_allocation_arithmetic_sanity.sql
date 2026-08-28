-- Recomputes refund_limit_variance = refund.amount - payment.amount directly from staging,
-- bypassing int_refund_allocation entirely, and fails if it disagrees with that model's own
-- output by more than a cent -- a regression guard on the allocation formula, not a tautology.
with recomputed as (

    select
        refunds.refund_id,
        refunds.amount - payments.amount as recomputed_refund_limit_variance
    from {{ ref('stg_airline__refunds') }} as refunds
    inner join {{ ref('stg_airline__payments') }} as payments
        on refunds.payment_id = payments.payment_id

)

select
    recomputed.refund_id,
    recomputed.recomputed_refund_limit_variance,
    allocation.refund_limit_variance
from recomputed
inner join {{ ref('int_refund_allocation') }} as allocation
    on recomputed.refund_id = allocation.refund_id
where abs(recomputed.recomputed_refund_limit_variance - allocation.refund_limit_variance) > 0.01
