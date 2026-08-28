with outstanding_balances as (

    select
        settlement_status,
        currency,
        source_invoice_total,
        outstanding_balance
    from {{ ref('fct_outstanding_balances') }}

),

aggregated as (

    select
        settlement_status,
        currency,
        count(*) as invoice_count,
        sum(source_invoice_total) as invoice_total_value,
        sum(outstanding_balance) as outstanding_balance_total
    from outstanding_balances
    group by settlement_status, currency

)

select
    settlement_status,
    currency,
    invoice_count,
    cast(invoice_total_value as decimal(18, 2)) as invoice_total_value,
    cast(outstanding_balance_total as decimal(18, 2)) as outstanding_balance_total
from aggregated
