-- Grain is one row per credit note (credit_note_id). Reuses int_credit_note_application rather
-- than re-deriving link evidence, and adds surrogate dimension keys. Implemented as a standalone
-- fact (not merged into fct_refunds) because a credit note is its own distinct document type in
-- the source: it has its own natural key, its own status lifecycle, and can in principle relate to
-- either a refund or an adjustment -- see int_credit_note_application for why, in the current
-- dataset, every credit note actually links to a refund and none link to an adjustment.
-- adjustment_key is still joined defensively so this fact keeps working correctly if that ever
-- changes.
with application as (

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
    from {{ ref('int_credit_note_application') }}

),

invoices as (

    select
        invoice_key,
        invoice_id
    from {{ ref('fct_invoices') }}

),

refunds as (

    select
        refund_key,
        refund_id
    from {{ ref('fct_refunds') }}

),

adjustments as (

    select
        adjustment_key,
        adjustment_id
    from {{ ref('fct_adjustments') }}

),

currencies as (

    select
        currency_key,
        currency_code
    from {{ ref('dim_currency') }}

),

joined as (

    select
        application.credit_note_id,
        invoices.invoice_key,
        application.invoice_id,
        refunds.refund_key,
        application.refund_id,
        adjustments.adjustment_key,
        application.adjustment_id,
        currencies.currency_key,
        application.currency,
        application.amount,
        application.issued_at_utc,
        application.status,
        application.has_invoice_match,
        application.has_refund_link,
        application.has_adjustment_link,
        application.is_currency_match
    from application
    left join invoices
        on application.invoice_id = invoices.invoice_id
    left join refunds
        on application.refund_id = refunds.refund_id
    left join adjustments
        on application.adjustment_id = adjustments.adjustment_id
    left join currencies
        on application.currency = currencies.currency_code

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['credit_note_id']) }} as credit_note_key,
        credit_note_id,
        invoice_key,
        invoice_id,
        refund_key,
        refund_id,
        adjustment_key,
        adjustment_id,
        currency_key,
        currency,
        amount,
        issued_at_utc,
        status,
        has_invoice_match,
        has_refund_link,
        has_adjustment_link,
        is_currency_match
    from joined

)

select
    credit_note_key,
    credit_note_id,
    invoice_key,
    invoice_id,
    refund_key,
    refund_id,
    adjustment_key,
    adjustment_id,
    currency_key,
    currency,
    amount,
    issued_at_utc,
    status,
    has_invoice_match,
    has_refund_link,
    has_adjustment_link,
    is_currency_match
from final
