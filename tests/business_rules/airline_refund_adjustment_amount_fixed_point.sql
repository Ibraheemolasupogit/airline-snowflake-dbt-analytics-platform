-- Fails if any refund or adjustment amount carries more than 2 decimal places of precision, which
-- would indicate floating-point drift rather than the fixed-point decimal(18, 2) arithmetic this
-- milestone requires throughout.
with refund_amounts as (

    select
        refund_id as record_id,
        'refund' as source_model,
        refund_limit_variance as amount
    from {{ ref('int_refund_allocation') }}

),

adjustment_amounts as (

    select
        adjustment_id as record_id,
        'adjustment' as source_model,
        amount
    from {{ ref('int_adjustment_allocation') }}

),

unioned as (

    select * from refund_amounts
    union all
    select * from adjustment_amounts

)

select
    record_id,
    source_model,
    amount
from unioned
where
    amount is not null
    and abs(amount - round(amount, 2)) > 0.0000001
