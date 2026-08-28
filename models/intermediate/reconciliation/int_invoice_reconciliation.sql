-- Grain is one row per reconciliation control. Primary key is control_id. Upstream models are
-- seed_synthetic_control_totals (source side) and fct_invoices/fct_invoice_lines (warehouse side,
-- reused unchanged -- no invoice arithmetic is recomputed here).
--
-- invoice_total_value compares against sum(fct_invoices.source_invoice_total) -- the unmodified
-- invoices.csv.total_amount passthrough -- NOT calculated_invoice_line_total, because
-- control_totals.json's own invoice_total_value is computed the same way
-- (scripts/generate_control_totals.py sums invoices.csv's own total_amount field directly). This
-- is the primary source-to-warehouse control and compares equivalent source semantics on both
-- sides.
--
-- invoice_line_arithmetic_consistency is kept separate but visible, per this milestone's explicit
-- instruction: it compares sum(calculated_invoice_line_total) against sum(source_invoice_total),
-- BOTH warehouse-side (Milestone 14's own internal header-vs-lines control, aggregated here, not
-- a new calculation) -- there is no corresponding source_controls row for it. Its nonzero value
-- reflects the already-known missing_invoice_line / incorrect_fare / completed_segment_without_
-- recognised_revenue_precursor controlled exceptions (see fct_billing_exceptions), which is a
-- documented business anomaly, not a source-to-warehouse reconciliation defect -- hence
-- control_status = 'warning', never 'fail', regardless of magnitude.
with source_controls as (

    select
        metric_name,
        cast(metric_value as decimal(38, 6)) as metric_value,
        as_of_date
    from {{ ref('seed_synthetic_control_totals') }}

),

warehouse_invoices as (

    select
        count(*) as invoice_count,
        sum(source_invoice_total) as invoice_total_value,
        sum(calculated_invoice_line_total) as calculated_invoice_line_total
    from {{ ref('fct_invoices') }}

),

count_controls as (

    select
        'invoice.invoice_count' as control_id,
        'invoice' as control_domain,
        'invoice_count' as control_name,
        source_controls.metric_value as source_measure,
        warehouse_invoices.invoice_count as warehouse_measure,
        source_controls.as_of_date,
        'fct_invoices row count (1:1 with invoices.csv, including the duplicate_invoice row).'
            as notes,
        'count' as control_type,
        warehouse_invoices.invoice_count - source_controls.metric_value as variance
    from source_controls
    cross join warehouse_invoices
    where source_controls.metric_name = 'invoice_count'

),

amount_controls as (

    select
        'invoice.invoice_total_value' as control_id,
        'invoice' as control_domain,
        'invoice_total_value' as control_name,
        source_controls.metric_value as source_measure,
        warehouse_invoices.invoice_total_value as warehouse_measure,
        warehouse_invoices.invoice_total_value - source_controls.metric_value as variance,
        source_controls.as_of_date,
        'sum(fct_invoices.source_invoice_total) -- unmodified invoices.csv.total_amount passthrough.'
            as notes,
        'amount' as control_type,
        'pass_fail' as status_mode
    from source_controls
    cross join warehouse_invoices
    where source_controls.metric_name = 'invoice_total_value'

    union all

    select
        'invoice.invoice_line_arithmetic_consistency' as control_id,
        'invoice' as control_domain,
        'invoice_line_arithmetic_consistency' as control_name,
        warehouse_invoices.invoice_total_value as source_measure,
        warehouse_invoices.calculated_invoice_line_total as warehouse_measure,
        warehouse_invoices.calculated_invoice_line_total - warehouse_invoices.invoice_total_value
            as variance,
        max(source_controls.as_of_date) as as_of_date,
        'Informational, NOT a source-to-warehouse control: sum(calculated_invoice_line_total) vs. '
        || 'sum(source_invoice_total), both warehouse-side. Nonzero reflects known controlled '
        || 'exceptions, not a reconciliation defect.' as notes,
        'amount' as control_type,
        'warning_only' as status_mode
    from source_controls
    cross join warehouse_invoices
    group by warehouse_invoices.invoice_total_value, warehouse_invoices.calculated_invoice_line_total

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
    case
        when status_mode = 'warning_only' then case when abs(variance) > 0.01 then 'warning' else 'pass' end
        when abs(variance) <= 0.01 then 'pass'
        else 'fail'
    end as control_status,
    cast(0.01 as decimal(18, 2)) as materiality_threshold,
    as_of_date,
    notes
from amount_controls
