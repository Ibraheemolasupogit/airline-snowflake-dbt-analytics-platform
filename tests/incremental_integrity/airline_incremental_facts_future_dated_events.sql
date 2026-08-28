-- Sanity check on every Milestone 21 incremental airline fact's own incremental-filter timestamp
-- column: no event should be dated after the moment this test runs. This is an environment-timing
-- check, not a business-logic guarantee (a synthetic dataset generated with a fixed seed could, in
-- principle, be regenerated with a future as_of date), so it is configured as a warning rather
-- than a hard failure -- see dbt_project.yml/this test's config.
{{ config(severity='warn') }}

with future_payment_attempts as (

    select
        'fct_payment_attempts' as fact_name,
        payment_attempt_id as natural_key,
        attempt_datetime_utc as event_timestamp
    from {{ ref('fct_payment_attempts') }}
    where attempt_datetime_utc > current_timestamp()

),

future_payments as (

    select
        'fct_payments' as fact_name,
        payment_id as natural_key,
        payment_datetime_utc as event_timestamp
    from {{ ref('fct_payments') }}
    where payment_datetime_utc > current_timestamp()

),

future_refunds as (

    select
        'fct_refunds' as fact_name,
        refund_id as natural_key,
        refund_datetime_utc as event_timestamp
    from {{ ref('fct_refunds') }}
    where refund_datetime_utc > current_timestamp()

),

future_revenue_events as (

    select
        'fct_revenue' as fact_name,
        event_type || '|' || source_event_id as natural_key,
        event_date as event_timestamp
    from {{ ref('fct_revenue') }}
    where event_date > current_timestamp()

),

final as (

    select * from future_payment_attempts
    union all
    select * from future_payments
    union all
    select * from future_refunds
    union all
    select * from future_revenue_events

)

select
    fact_name,
    natural_key,
    event_timestamp
from final
