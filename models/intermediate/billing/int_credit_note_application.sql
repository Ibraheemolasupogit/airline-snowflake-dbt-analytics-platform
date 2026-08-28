-- Grain is one row per credit note (credit_note_id). Upstream models are
-- stg_airline__credit_notes and stg_airline__invoices (for currency comparison only).
--
-- A credit note in this dataset is a paper-trail document evidencing a refund, not an independent
-- invoice-application/allocation instrument: verified against
-- scripts/airline_synth/build_billing.py, every credit_note is created in the same code block as
-- its refund, with credit_note.amount set to the identical successful_payment_amount value used
-- for that refund, and credit_note.refund_id always populated. credit_note.adjustment_id is
-- always empty/null in the current dataset -- no code path in build_billing.py or exceptions.py
-- ever creates a credit note tied to an adjustment, even though the staged schema supports it
-- (stg_airline__credit_notes.adjustment_id exists and is nullable). No allocation/application rule
-- is invented here beyond what is documented: this model preserves the credit note's own fields
-- and exposes has_refund_link / has_adjustment_link as structural evidence, per this milestone's
-- explicit instruction to document the limitation rather than invent one.
--
-- Note: scripts/airline_synth/exceptions.py's refund_greater_than_collected_amount exception
-- mutates only the linked refund's amount, never the paired credit_note's amount -- so for the one
-- refund it affects (if that refund already had a credit note from the normal flow), this credit
-- note's amount may no longer equal its refund's (now-inflated) amount. This model does not
-- reconcile or flag that; it is preserved as-is, exactly as staged.
with credit_notes as (

    select
        credit_note_id,
        invoice_id,
        refund_id,
        adjustment_id,
        amount,
        currency,
        issued_at_utc,
        status
    from {{ ref('stg_airline__credit_notes') }}

),

invoices as (

    select
        invoice_id,
        currency as invoice_currency
    from {{ ref('stg_airline__invoices') }}

),

joined as (

    select
        credit_notes.credit_note_id,
        credit_notes.invoice_id,
        credit_notes.refund_id,
        credit_notes.adjustment_id,
        credit_notes.amount,
        credit_notes.currency,
        credit_notes.issued_at_utc,
        credit_notes.status,
        invoices.invoice_id is not null as has_invoice_match,
        credit_notes.refund_id is not null as has_refund_link,
        credit_notes.adjustment_id is not null as has_adjustment_link,
        case
            when invoices.invoice_id is null then null
            else credit_notes.currency = invoices.invoice_currency
        end as is_currency_match
    from credit_notes
    left join invoices
        on credit_notes.invoice_id = invoices.invoice_id

)

select
    credit_note_id,
    invoice_id,
    refund_id,
    adjustment_id,
    amount,
    currency,
    issued_at_utc,
    status,
    has_invoice_match,
    has_refund_link,
    has_adjustment_link,
    is_currency_match
from joined
