-- Grain is one row per financial-bridge measure. Primary key is control_id. This is deliberately
-- NOT a source-to-warehouse comparison, per this milestone's own scope: Milestone 9's
-- control_totals.json contains no recognised-revenue total to compare against, and invoice total,
-- cash collected, and net recognised revenue represent genuinely different business/accounting
-- states that are not meant to equal one another (an invoice can be issued before cash is
-- collected; revenue is recognised only once a service is fulfilled, independent of both). Every
-- row here therefore has control_status = 'not_applicable' and a null source_measure -- this model
-- explains differences between business measures, it never forces a false equality between them.
--
-- Every measure reuses an existing fact's own column unchanged (fct_invoices, fct_refunds,
-- fct_revenue, fct_outstanding_balances) -- no pricing, allocation, or revenue-recognition logic
-- is recomputed here.
with invoices as (

    select
        sum(source_invoice_total) as invoiced_value,
        sum(amount_collected) as collected_cash,
        sum(net_adjustment_amount) as net_adjustment_total
    from {{ ref('fct_invoices') }}

),

refunds as (

    select sum(refund_amount) as refund_total
    from {{ ref('fct_refunds') }}

),

revenue as (

    select sum(net_recognised_amount) as net_recognised_revenue
    from {{ ref('fct_revenue') }}

),

outstanding_balances as (

    select sum(outstanding_balance) as outstanding_balance_total
    from {{ ref('fct_outstanding_balances') }}

),

as_of as (

    select max(as_of_date) as as_of_date
    from {{ ref('seed_synthetic_control_totals') }}

),

bridge as (

    select
        'revenue_bridge.invoiced_value' as control_id,
        'revenue_bridge' as control_domain,
        'invoiced_value' as control_name,
        invoices.invoiced_value as warehouse_measure,
        'sum(fct_invoices.source_invoice_total) -- what was billed.' as notes
    from invoices

    union all

    select
        'revenue_bridge.collected_cash' as control_id,
        'revenue_bridge' as control_domain,
        'collected_cash' as control_name,
        invoices.collected_cash as warehouse_measure,
        'sum(fct_invoices.amount_collected) -- cash actually applied toward invoices.' as notes
    from invoices

    union all

    select
        'revenue_bridge.refund_total' as control_id,
        'revenue_bridge' as control_domain,
        'refund_total' as control_name,
        refunds.refund_total as warehouse_measure,
        'sum(fct_refunds.refund_amount) -- cash returned to customers.' as notes
    from refunds

    union all

    select
        'revenue_bridge.net_adjustment_total' as control_id,
        'revenue_bridge' as control_domain,
        'net_adjustment_total' as control_name,
        invoices.net_adjustment_total as warehouse_measure,
        'sum(fct_invoices.net_adjustment_amount), native sign (credit = negative).' as notes
    from invoices

    union all

    select
        'revenue_bridge.net_recognised_revenue' as control_id,
        'revenue_bridge' as control_domain,
        'net_recognised_revenue' as control_name,
        revenue.net_recognised_revenue as warehouse_measure,
        'sum(fct_revenue.net_recognised_amount) -- earned revenue, independent of billing/cash timing.'
            as notes
    from revenue

    union all

    select
        'revenue_bridge.outstanding_balance_total' as control_id,
        'revenue_bridge' as control_domain,
        'outstanding_balance_total' as control_name,
        outstanding_balances.outstanding_balance_total as warehouse_measure,
        'sum(fct_outstanding_balances.outstanding_balance) -- never clamped to zero.' as notes
    from outstanding_balances

)

select
    bridge.control_id,
    bridge.control_domain,
    bridge.control_name,
    cast(null as decimal(18, 2)) as source_measure,
    cast(bridge.warehouse_measure as decimal(18, 2)) as warehouse_measure,
    cast(null as decimal(18, 2)) as variance_amount,
    cast(null as number(38, 0)) as variance_count,
    'not_applicable' as control_status,
    cast(null as decimal(18, 2)) as materiality_threshold,
    as_of.as_of_date,
    bridge.notes
from bridge
cross join as_of
