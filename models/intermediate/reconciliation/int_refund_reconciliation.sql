-- Grain is one row per reconciliation control. Primary key is control_id. Upstream models are
-- seed_synthetic_control_totals (source side) and fct_refunds (warehouse side, reused unchanged --
-- no refund allocation logic is recomputed here).
--
-- refund_total_value compares against sum(fct_refunds.refund_amount), UNCAPPED -- Milestone 16
-- deliberately never caps or corrects a refund's own amount (only exposes
-- refund_limit_variance/refundable_amount_reference as separate evidence). This is the exact
-- point this milestone's own scope requires demonstrating: the deliberately injected
-- refund_greater_than_collected_amount controlled exception's row is expected to reconcile
-- PERFECTLY here (source refund_amount = warehouse refund_amount, both the same unmodified
-- +100-inflated figure), because a data-quality/business anomaly is different from a
-- source-to-warehouse reconciliation failure. That anomaly is separately, correctly flagged via
-- fct_billing_exceptions (Milestone 18), never here.
with source_controls as (

    select
        metric_name,
        cast(metric_value as decimal(38, 6)) as metric_value,
        as_of_date
    from {{ ref('seed_synthetic_control_totals') }}

),

warehouse_refunds as (

    select
        count(*) as refund_count,
        sum(refund_amount) as refund_total_value
    from {{ ref('fct_refunds') }}

),

count_controls as (

    select
        'refund.refund_count' as control_id,
        'refund' as control_domain,
        'refund_count' as control_name,
        source_controls.metric_value as source_measure,
        warehouse_refunds.refund_count as warehouse_measure,
        source_controls.as_of_date,
        'fct_refunds row count (1:1 with refunds.csv).' as notes,
        warehouse_refunds.refund_count - source_controls.metric_value as variance
    from source_controls
    cross join warehouse_refunds
    where source_controls.metric_name = 'refund_count'

),

amount_controls as (

    select
        'refund.refund_total_value' as control_id,
        'refund' as control_domain,
        'refund_total_value' as control_name,
        source_controls.metric_value as source_measure,
        warehouse_refunds.refund_total_value as warehouse_measure,
        source_controls.as_of_date,
        warehouse_refunds.refund_total_value - source_controls.metric_value as variance,
        'sum(fct_refunds.refund_amount), UNCAPPED -- includes the refund_greater_than_collected_'
        || 'amount controlled exception''s full inflated amount, which is expected to reconcile '
        || 'exactly.' as notes
    from source_controls
    cross join warehouse_refunds
    where source_controls.metric_name = 'refund_total_value'

)

select
    control_id,
    control_domain,
    control_name,
    source_measure,
    warehouse_measure,
    cast(null as decimal(18, 2)) as variance_amount,
    cast(variance as number(38, 0)) as variance_count,
    case when variance = 0 then 'pass' else 'fail' end as control_status,
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
