with refunds as (

    select
        reason,
        currency,
        refund_amount,
        refund_limit_variance
    from {{ ref('fct_refunds') }}

),

aggregated as (

    select
        reason,
        currency,
        count(*) as refund_count,
        sum(refund_amount) as refund_amount_total,
        avg(refund_amount) as average_refund_amount,
        sum(case when refund_limit_variance > 0 then 1 else 0 end) as over_refund_count
    from refunds
    group by reason, currency

)

select
    reason,
    currency,
    refund_count,
    cast(refund_amount_total as decimal(18, 2)) as refund_amount_total,
    cast(average_refund_amount as decimal(18, 2)) as average_refund_amount,
    over_refund_count
from aggregated
