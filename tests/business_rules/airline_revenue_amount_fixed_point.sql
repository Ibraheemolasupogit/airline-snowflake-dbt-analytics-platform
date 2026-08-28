-- Fails if any revenue-event amount carries more than 2 decimal places of precision, which would
-- indicate floating-point drift rather than the fixed-point decimal(18, 2) arithmetic this
-- milestone requires throughout.
with revenue_amounts as (

    select
        revenue_event_key,
        'gross_recognised_amount' as measure,
        gross_recognised_amount as amount
    from {{ ref('fct_revenue') }}
    union all
    select
        revenue_event_key,
        'reversal_or_adjustment_amount' as measure,
        reversal_or_adjustment_amount as amount
    from {{ ref('fct_revenue') }}
    union all
    select
        revenue_event_key,
        'net_recognised_amount' as measure,
        net_recognised_amount as amount
    from {{ ref('fct_revenue') }}

)

select
    revenue_event_key,
    measure,
    amount
from revenue_amounts
where
    amount is not null
    and abs(amount - round(amount, 2)) > 0.0000001
