-- Recomputes outstanding_balance = source_invoice_total - amount_collected + refund_amount +
-- net_adjustment_amount directly from fct_invoices, bypassing int_outstanding_balance entirely,
-- and fails if it disagrees with that model's own output by more than a cent -- a regression
-- guard on the balance formula, not a tautology.
select
    invoices.invoice_id,
    balance.outstanding_balance,
    invoices.source_invoice_total
    - invoices.amount_collected
    + invoices.refund_amount
    + invoices.net_adjustment_amount as recomputed_outstanding_balance
from {{ ref('fct_invoices') }} as invoices
inner join {{ ref('int_outstanding_balance') }} as balance
    on invoices.invoice_id = balance.invoice_id
where
    abs(
        (
            invoices.source_invoice_total
            - invoices.amount_collected
            + invoices.refund_amount
            + invoices.net_adjustment_amount
        ) - balance.outstanding_balance
    ) > 0.01
