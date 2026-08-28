with payments as (

    select
        allocation_status,
        currency,
        unallocated_amount
    from {{ ref('fct_payments') }}
    where unallocated_amount > 0

),

aggregated as (

    select
        allocation_status,
        currency,
        count(*) as unallocated_payment_count,
        sum(unallocated_amount) as unallocated_amount_total
    from payments
    group by allocation_status, currency

)

select
    allocation_status,
    currency,
    unallocated_payment_count,
    cast(unallocated_amount_total as decimal(18, 2)) as unallocated_amount_total
from aggregated
