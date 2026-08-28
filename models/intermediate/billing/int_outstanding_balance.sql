-- Grain is one row per invoice (invoice_id). Reuses fct_invoices (Milestone 14/15/16) and
-- fct_credit_notes (Milestone 16) rather than recomputing invoice arithmetic, payment allocation,
-- or refund logic.
--
-- Formula (all components kept visible, never hidden inside one opaque expression):
--
--   outstanding_balance = source_invoice_total
--                          - amount_collected
--                          + refund_amount
--                          + net_adjustment_amount
--
-- Component sign conventions, using the actual Milestone 15/16 semantics as authority (not an
-- imposed external accounting convention):
--   - amount_collected (M15) is already a positive "applied toward this invoice" amount, so it is
--     SUBTRACTED (money collected reduces what remains due).
--   - refund_amount (M16) is always positive ("money returned to the customer" -- see
--     docs/data_models/airline_refunds_adjustments.md). A refund reverses a prior collection, so
--     it is ADDED BACK (restores the amount due that the now-reversed collection had settled).
--   - net_adjustment_amount (M16) already carries its own native sign in "amount due" terms
--     (credit = negative, decreasing amount due; debit = positive, increasing amount due -- see
--     the same doc), so it is ADDED directly with no sign flip.
--
-- credit_note_amount is exposed as its own visible column for transparency (this milestone's own
-- requirement), but is deliberately NOT netted into the balance formula above: Milestone 16
-- established that a credit note in this dataset is a paper-trail document evidencing a refund,
-- not an independent invoice-application instrument, and in the normal flow credit_note.amount is
-- definitionally identical to its linked refund.amount (same code path, same value). Netting both
-- refund_amount and credit_note_amount would double-count the same cash movement. If a credit note
-- were ever linked to an adjustment instead of a refund (has_adjustment_link), it would represent a
-- genuinely separate credit event -- none currently exists in this dataset (see
-- int_credit_note_application), so this limitation is documented but not currently exercised.
--
-- settlement_status is derived neutrally from the sign of outstanding_balance only -- no
-- collections-workflow language or urgency is implied:
--   > 0  -> 'outstanding' (amount still due)
--   = 0  -> 'settled'     (financially settled under this model)
--   < 0  -> 'over_settled' (a negative balance is NOT clamped to zero -- it may be important
--            exception evidence, e.g. a refund/credit exceeding what was ever collected)
with invoices as (

    select
        invoice_id,
        booking_id,
        currency,
        source_invoice_total,
        amount_collected,
        refund_amount,
        net_adjustment_amount
    from {{ ref('fct_invoices') }}

),

credit_note_aggregates as (

    select
        invoice_id,
        sum(amount) as credit_note_amount
    from {{ ref('fct_credit_notes') }}
    group by invoice_id

),

joined as (

    select
        invoices.invoice_id,
        invoices.booking_id,
        invoices.currency,
        invoices.source_invoice_total,
        invoices.amount_collected,
        invoices.refund_amount,
        invoices.net_adjustment_amount,
        coalesce(credit_note_aggregates.credit_note_amount, 0) as credit_note_amount
    from invoices
    left join credit_note_aggregates
        on invoices.invoice_id = credit_note_aggregates.invoice_id

),

final as (

    select
        invoice_id,
        booking_id,
        currency,
        source_invoice_total,
        amount_collected,
        refund_amount,
        net_adjustment_amount,
        credit_note_amount,
        source_invoice_total - amount_collected + refund_amount + net_adjustment_amount
            as outstanding_balance
    from joined

)

select
    invoice_id,
    booking_id,
    currency,
    source_invoice_total,
    amount_collected,
    refund_amount,
    net_adjustment_amount,
    credit_note_amount,
    cast(outstanding_balance as decimal(18, 2)) as outstanding_balance,
    case
        when outstanding_balance > 0 then 'outstanding'
        when outstanding_balance = 0 then 'settled'
        else 'over_settled'
    end as settlement_status
from final
