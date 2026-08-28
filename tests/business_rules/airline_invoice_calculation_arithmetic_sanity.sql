-- Recomputes sum(invoice_lines.amount) grouped by invoice_id directly from staging, bypassing
-- int_invoice_calculation entirely, and fails if it disagrees with that model's own
-- calculated_invoice_line_total by more than a cent -- a regression guard on the aggregation
-- logic, not a tautology.
with recomputed as (

    select
        invoice_id,
        sum(amount) as recomputed_line_total
    from {{ ref('stg_airline__invoice_lines') }}
    group by invoice_id

)

select
    recomputed.invoice_id,
    recomputed.recomputed_line_total,
    calc.calculated_invoice_line_total
from recomputed
inner join {{ ref('int_invoice_calculation') }} as calc
    on recomputed.invoice_id = calc.invoice_id
where abs(recomputed.recomputed_line_total - calc.calculated_invoice_line_total) > 0.01
