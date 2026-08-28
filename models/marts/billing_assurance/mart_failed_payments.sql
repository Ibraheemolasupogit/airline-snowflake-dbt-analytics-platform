with payment_attempts as (

    select
        classified_failure_reason,
        currency,
        amount
    from {{ ref('fct_payment_attempts') }}
    where attempt_classification = 'failed'

),

aggregated as (

    select
        classified_failure_reason,
        currency,
        count(*) as failed_attempt_count,
        sum(amount) as failed_attempt_value
    from payment_attempts
    group by classified_failure_reason, currency

)

select
    classified_failure_reason,
    currency,
    failed_attempt_count,
    cast(failed_attempt_value as decimal(18, 2)) as failed_attempt_value
from aggregated
