-- Grain is one row per reconciliation control. Primary key is control_id. Upstream models are
-- seed_synthetic_control_totals (source side) and fct_payments/fct_payment_attempts (warehouse
-- side, reused unchanged -- no payment allocation logic is recomputed here).
--
-- successful_payment_total_value compares against sum(fct_payments.payment_amount) -- the raw,
-- uncapped amount actually collected -- NOT allocated_amount (Milestone 15's invoice-capped
-- figure). control_totals.json's own successful_payment_total_value sums payments.csv's own
-- amount field directly with no capping, so this is the equivalent-semantics comparison.
--
-- failed_attempt_count is supplementary, per this milestone's explicit instruction ("Use
-- fct_payment_attempts only for supplementary failed-attempt controls"): control_totals.json has
-- no failed-attempt total to compare against at all, so this row has no source_measure and
-- control_status = 'not_applicable', never 'pass'/'fail'.
with source_controls as (

    select
        metric_name,
        cast(metric_value as decimal(38, 6)) as metric_value,
        as_of_date
    from {{ ref('seed_synthetic_control_totals') }}

),

warehouse_payments as (

    select
        count(*) as successful_payment_count,
        sum(payment_amount) as successful_payment_total_value
    from {{ ref('fct_payments') }}

),

warehouse_failed_attempts as (

    select count(*) as failed_attempt_count
    from {{ ref('fct_payment_attempts') }}
    where attempt_classification = 'failed'

),

count_controls as (

    select
        'payment.successful_payment_count' as control_id,
        'payment' as control_domain,
        'successful_payment_count' as control_name,
        source_controls.metric_value as source_measure,
        warehouse_payments.successful_payment_count as warehouse_measure,
        warehouse_payments.successful_payment_count - source_controls.metric_value as variance,
        source_controls.as_of_date,
        'fct_payments row count (1:1 with payments.csv -- every row is a successful transaction '
        || 'by construction).' as notes,
        'pass_fail' as status_mode
    from source_controls
    cross join warehouse_payments
    where source_controls.metric_name = 'successful_payment_count'

    union all

    select
        'payment.failed_attempt_count' as control_id,
        'payment' as control_domain,
        'failed_attempt_count' as control_name,
        cast(null as decimal(38, 6)) as source_measure,
        warehouse_failed_attempts.failed_attempt_count as warehouse_measure,
        cast(null as decimal(38, 6)) as variance,
        max(source_controls.as_of_date) as as_of_date,
        'Supplementary, NOT a source-to-warehouse control: control_totals.json has no '
        || 'failed-attempt total. count(*) from fct_payment_attempts where '
        || 'attempt_classification = ''failed''.' as notes,
        'not_applicable' as status_mode
    from source_controls
    cross join warehouse_failed_attempts
    group by warehouse_failed_attempts.failed_attempt_count

),

amount_controls as (

    select
        'payment.successful_payment_total_value' as control_id,
        'payment' as control_domain,
        'successful_payment_total_value' as control_name,
        source_controls.metric_value as source_measure,
        warehouse_payments.successful_payment_total_value as warehouse_measure,
        source_controls.as_of_date,
        'sum(fct_payments.payment_amount), the raw uncapped amount -- not allocated_amount.'
            as notes,
        warehouse_payments.successful_payment_total_value - source_controls.metric_value as variance
    from source_controls
    cross join warehouse_payments
    where source_controls.metric_name = 'successful_payment_total_value'

)

select
    control_id,
    control_domain,
    control_name,
    source_measure,
    warehouse_measure,
    cast(null as decimal(18, 2)) as variance_amount,
    cast(variance as number(38, 0)) as variance_count,
    case
        when status_mode = 'not_applicable' then 'not_applicable'
        when variance = 0 then 'pass'
        else 'fail'
    end as control_status,
    cast(0 as decimal(18, 2)) as materiality_threshold,
    as_of_date,
    notes
from count_controls

union all

select
    control_id,
    control_domain,
    control_name,
    source_measure,
    warehouse_measure,
    cast(variance as decimal(18, 2)) as variance_amount,
    cast(null as number(38, 0)) as variance_count,
    case when abs(variance) <= 0.01 then 'pass' else 'fail' end as control_status,
    cast(0.01 as decimal(18, 2)) as materiality_threshold,
    as_of_date,
    notes
from amount_controls
