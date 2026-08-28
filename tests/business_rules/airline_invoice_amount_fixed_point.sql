-- Fails if any invoice arithmetic or pricing-comparison amount carries more than 2 decimal places
-- of precision, which would indicate floating-point drift rather than the fixed-point
-- decimal(18, 2) arithmetic this milestone requires throughout.
with invoice_calculation_amounts as (

    select
        invoice_id as record_id,
        'invoice_calculation' as source_model,
        calculated_invoice_line_total as amount
    from {{ ref('int_invoice_calculation') }}
    union all
    select
        invoice_id as record_id,
        'invoice_calculation' as source_model,
        invoice_total_variance as amount
    from {{ ref('int_invoice_calculation') }}

),

charge_comparison_amounts as (

    select
        invoice_id || ':' || comparable_line_type || ':' || coalesce(reference_code, '') as record_id,
        'charge_comparison' as source_model,
        variance_amount as amount
    from {{ ref('int_invoice_charge_comparison') }}

),

unioned as (

    select * from invoice_calculation_amounts
    union all
    select * from charge_comparison_amounts

)

select
    record_id,
    source_model,
    amount
from unioned
where
    amount is not null
    and abs(amount - round(amount, 2)) > 0.0000001
