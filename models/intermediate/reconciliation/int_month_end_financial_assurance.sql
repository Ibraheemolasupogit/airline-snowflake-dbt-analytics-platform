-- Grain is one row -- a single month-end-style snapshot as of the dataset's own fixed synthetic
-- as_of_date (data/synthetic/control_totals.json's as_of_date, 2026-01-15, sourced via
-- seed_synthetic_control_totals -- never wall-clock-dependent). Every measure reuses an existing
-- fact's own column unchanged; nothing is recomputed. This model is a reporting summary over
-- Milestones 12-18's outputs, not a new reconciliation calculation.
with as_of as (

    select max(as_of_date) as as_of_date
    from {{ ref('seed_synthetic_control_totals') }}

),

bookings as (

    select
        count(*) as booking_count,
        sum(case when is_cancelled then 1 else 0 end) as booking_cancelled_count
    from {{ ref('fct_bookings') }}

),

invoices as (

    select
        count(*) as invoice_count,
        sum(source_invoice_total) as invoice_total_value,
        sum(amount_collected) as amount_collected_total,
        sum(net_adjustment_amount) as net_adjustment_total
    from {{ ref('fct_invoices') }}

),

payments as (

    select
        count(*) as payment_count,
        sum(payment_amount) as payment_total_value
    from {{ ref('fct_payments') }}

),

refunds as (

    select
        count(*) as refund_count,
        sum(refund_amount) as refund_total_value
    from {{ ref('fct_refunds') }}

),

adjustments as (

    select count(*) as adjustment_count
    from {{ ref('fct_adjustments') }}

),

revenue as (

    select sum(net_recognised_amount) as net_recognised_revenue_total
    from {{ ref('fct_revenue') }}
    where event_type in ('ticket_revenue', 'ancillary_revenue')

),

outstanding_balances as (

    select sum(outstanding_balance) as outstanding_balance_total
    from {{ ref('fct_outstanding_balances') }}

),

billing_exceptions as (

    select
        count(*) as billing_exception_count,
        sum(financial_value_at_risk_amount) as billing_exception_financial_value_at_risk_total
    from {{ ref('fct_billing_exceptions') }}

)

select
    as_of.as_of_date,
    bookings.booking_count,
    bookings.booking_cancelled_count,
    invoices.invoice_count,
    cast(invoices.invoice_total_value as decimal(18, 2)) as invoice_total_value,
    cast(invoices.amount_collected_total as decimal(18, 2)) as amount_collected_total,
    cast(invoices.net_adjustment_total as decimal(18, 2)) as net_adjustment_total,
    payments.payment_count,
    cast(payments.payment_total_value as decimal(18, 2)) as payment_total_value,
    refunds.refund_count,
    cast(refunds.refund_total_value as decimal(18, 2)) as refund_total_value,
    adjustments.adjustment_count,
    cast(revenue.net_recognised_revenue_total as decimal(18, 2)) as net_recognised_revenue_total,
    cast(outstanding_balances.outstanding_balance_total as decimal(18, 2)) as outstanding_balance_total,
    billing_exceptions.billing_exception_count,
    cast(
        billing_exceptions.billing_exception_financial_value_at_risk_total as decimal(18, 2)
    ) as billing_exception_financial_value_at_risk_total
from as_of
cross join bookings
cross join invoices
cross join payments
cross join refunds
cross join adjustments
cross join revenue
cross join outstanding_balances
cross join billing_exceptions
