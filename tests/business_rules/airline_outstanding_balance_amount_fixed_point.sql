-- Fails if any outstanding-balance or billing-exception monetary amount carries more than 2
-- decimal places of precision, which would indicate floating-point drift rather than the
-- fixed-point decimal(18, 2) arithmetic this milestone requires throughout.
with balance_amounts as (

    select
        invoice_id as record_id,
        'outstanding_balance' as source_model,
        outstanding_balance as amount
    from {{ ref('int_outstanding_balance') }}

),

exception_amounts as (

    select
        exception_type || ':' || source_record_id as record_id,
        'billing_exception' as source_model,
        financial_value_at_risk_amount as amount
    from {{ ref('int_billing_exceptions') }}

),

unioned as (

    select * from balance_amounts
    union all
    select * from exception_amounts

)

select
    record_id,
    source_model,
    amount
from unioned
where
    amount is not null
    and abs(amount - round(amount, 2)) > 0.0000001
