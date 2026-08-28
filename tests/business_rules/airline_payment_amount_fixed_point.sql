-- Fails if any payment allocation amount carries more than 2 decimal places of precision, which
-- would indicate floating-point drift rather than the fixed-point decimal(18, 2) arithmetic this
-- milestone requires throughout.
with allocation_amounts as (

    select
        payment_id,
        'allocated_amount' as measure,
        allocated_amount as amount
    from {{ ref('int_payment_allocation') }}
    union all
    select
        payment_id,
        'unallocated_amount' as measure,
        unallocated_amount as amount
    from {{ ref('int_payment_allocation') }}

)

select
    payment_id,
    measure,
    amount
from allocation_amounts
where
    amount is not null
    and abs(amount - round(amount, 2)) > 0.0000001
