-- Guards the merge behaviour of every Milestone 21 incremental airline fact: the declared
-- unique_key must never produce more than one row per key, regardless of how many incremental
-- runs have occurred. A failure here would indicate the merge configuration (unique_key /
-- incremental_strategy) is not behaving as documented, not a business-data defect.
with payment_attempt_duplicates as (

    select
        'fct_payment_attempts' as fact_name,
        payment_attempt_id as natural_key,
        count(*) as row_count
    from {{ ref('fct_payment_attempts') }}
    group by payment_attempt_id
    having count(*) > 1

),

payment_duplicates as (

    select
        'fct_payments' as fact_name,
        payment_id as natural_key,
        count(*) as row_count
    from {{ ref('fct_payments') }}
    group by payment_id
    having count(*) > 1

),

refund_duplicates as (

    select
        'fct_refunds' as fact_name,
        refund_id as natural_key,
        count(*) as row_count
    from {{ ref('fct_refunds') }}
    group by refund_id
    having count(*) > 1

),

revenue_duplicates as (

    select
        'fct_revenue' as fact_name,
        event_type || '|' || source_event_id as natural_key,
        count(*) as row_count
    from {{ ref('fct_revenue') }}
    group by event_type, source_event_id
    having count(*) > 1

),

final as (

    select * from payment_attempt_duplicates
    union all
    select * from payment_duplicates
    union all
    select * from refund_duplicates
    union all
    select * from revenue_duplicates

)

select
    fact_name,
    natural_key,
    row_count
from final
