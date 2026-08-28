-- Grain is one row per (exception_type, severity, status, currency). This is reconciliation/
-- assurance REPORTING over the existing exception fact -- it aggregates fct_billing_exceptions
-- (Milestone 18) exactly as generated; no exception is re-detected, reclassified, or recomputed
-- here.
with billing_exceptions as (

    select
        exception_type,
        severity,
        status,
        currency,
        financial_value_at_risk_amount
    from {{ ref('fct_billing_exceptions') }}

),

aggregated as (

    select
        exception_type,
        severity,
        status,
        currency,
        count(*) as exception_count,
        sum(financial_value_at_risk_amount) as financial_value_at_risk_total
    from billing_exceptions
    group by exception_type, severity, status, currency

)

select
    exception_type,
    severity,
    status,
    currency,
    exception_count,
    cast(financial_value_at_risk_total as decimal(18, 2)) as financial_value_at_risk_total
from aggregated
