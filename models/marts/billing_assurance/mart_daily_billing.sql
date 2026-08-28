-- Grain is one row per (invoice date, currency). Reuses fct_invoices/fct_outstanding_balances
-- directly; no invoice arithmetic, allocation, or balance calculation is recomputed here.
with invoices as (

    select
        cast(invoice_date_utc as date) as invoice_date,
        currency,
        source_invoice_total,
        amount_collected,
        refund_amount,
        net_adjustment_amount
    from {{ ref('fct_invoices') }}

),

aggregated as (

    select
        invoice_date,
        currency,
        count(*) as invoice_count,
        sum(source_invoice_total) as invoice_total_value,
        sum(amount_collected) as amount_collected_total,
        sum(refund_amount) as refund_amount_total,
        sum(net_adjustment_amount) as net_adjustment_total
    from invoices
    group by invoice_date, currency

)

select
    invoice_date,
    currency,
    invoice_count,
    cast(invoice_total_value as decimal(18, 2)) as invoice_total_value,
    cast(amount_collected_total as decimal(18, 2)) as amount_collected_total,
    cast(refund_amount_total as decimal(18, 2)) as refund_amount_total,
    cast(net_adjustment_total as decimal(18, 2)) as net_adjustment_total
from aggregated
