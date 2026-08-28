-- Recomputes allocated_amount = least(payment.amount, invoice.total_amount) directly from
-- staging, bypassing int_payment_allocation entirely, and fails if it disagrees with that model's
-- own output by more than a cent -- a regression guard on the allocation formula, not a tautology.
with recomputed as (

    select
        payments.payment_id,
        case
            when invoices.invoice_id is not null
                then least(payments.amount, invoices.total_amount)
            else 0
        end as recomputed_allocated_amount
    from {{ ref('stg_airline__payments') }} as payments
    left join {{ ref('stg_airline__invoices') }} as invoices
        on payments.invoice_id = invoices.invoice_id

)

select
    recomputed.payment_id,
    recomputed.recomputed_allocated_amount,
    allocation.allocated_amount
from recomputed
inner join {{ ref('int_payment_allocation') }} as allocation
    on recomputed.payment_id = allocation.payment_id
where abs(recomputed.recomputed_allocated_amount - allocation.allocated_amount) > 0.01
