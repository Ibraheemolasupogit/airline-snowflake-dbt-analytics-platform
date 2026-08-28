-- Grain is one row per currency. Reuses mart_outstanding_balances and mart_billing_exceptions
-- (both already-aggregated) rather than re-aggregating fct_outstanding_balances /
-- fct_billing_exceptions. Never collapses across currency -- outstanding_balance_total and
-- financial_value_at_risk_total are only ever meaningful within one currency.
with outstanding as (

    select
        currency,
        invoice_count,
        invoice_total_value,
        outstanding_balance_total
    from {{ ref('mart_outstanding_balances') }}

),

outstanding_aggregated as (

    select
        currency,
        sum(invoice_count) as invoice_count,
        sum(invoice_total_value) as invoice_total_value,
        sum(outstanding_balance_total) as outstanding_balance_total
    from outstanding
    group by currency

),

exceptions as (

    select
        currency,
        exception_count,
        financial_value_at_risk_total
    from {{ ref('mart_billing_exceptions') }}

),

exceptions_aggregated as (

    select
        currency,
        sum(exception_count) as exception_count,
        sum(financial_value_at_risk_total) as financial_value_at_risk_total
    from exceptions
    group by currency

)

select
    cast(coalesce(outstanding_aggregated.invoice_total_value, 0) as decimal(18, 2)) as invoice_total_value,
    cast(coalesce(outstanding_aggregated.outstanding_balance_total, 0) as decimal(18, 2))
        as outstanding_balance_total,
    cast(coalesce(exceptions_aggregated.financial_value_at_risk_total, 0) as decimal(18, 2))
        as financial_value_at_risk_total,
    coalesce(outstanding_aggregated.currency, exceptions_aggregated.currency) as currency,
    coalesce(outstanding_aggregated.invoice_count, 0) as invoice_count,
    coalesce(exceptions_aggregated.exception_count, 0) as exception_count
from outstanding_aggregated
full outer join exceptions_aggregated
    on outstanding_aggregated.currency = exceptions_aggregated.currency
