-- Structural validation of invoice lines. Grain is one row per invoice line (invoice_line_id).
-- Adds structural validation attributes only (has_invoice_parent, has_supported_line_type,
-- has_currency, has_non_null_amount, expected_pricing_component_available) -- these are
-- validation SIGNALS, not billing-exception classifications. No is_incorrect_fare / exception_type
-- / severity column exists here; that classification belongs to a later milestone.
--
-- expected_pricing_component_available uses the same component_type -> line_type bucket mapping as
-- int_invoice_charge_comparison (base_fare + distance_fare both map to base_fare; every other
-- component_type maps to itself), kept intentionally in sync with that model, and the same
-- reference_code alignment (fare_class_code / tax_code / fee_code / service_code / discount_code)
-- verified against scripts/airline_synth/build_billing.py. A false value here does not by itself
-- mean the source line is wrong -- it means int_invoice_charge_comparison would show a null
-- expected_amount for this line, which downstream assurance can act on.
with invoice_lines as (

    select
        invoice_line_id,
        invoice_id,
        ticket_id,
        line_type,
        reference_code,
        description,
        amount,
        currency
    from {{ ref('stg_airline__invoice_lines') }}

),

invoices as (

    select
        invoice_id,
        booking_id
    from {{ ref('stg_airline__invoices') }}

),

pricing_events_by_ticket as (

    select distinct
        ticket_id,
        reference_code,
        case
            when component_type in ('base_fare', 'distance_fare') then 'base_fare'
            else component_type
        end as comparable_line_type
    from {{ ref('fct_pricing_events') }}
    where charge_scope = 'ticket'

),

pricing_events_by_booking as (

    select distinct
        booking_id,
        component_type as comparable_line_type,
        reference_code
    from {{ ref('fct_pricing_events') }}
    where charge_scope = 'booking'

),

joined as (

    select
        invoice_lines.invoice_line_id,
        invoice_lines.invoice_id,
        invoices.booking_id,
        invoice_lines.ticket_id,
        invoice_lines.line_type,
        invoice_lines.reference_code,
        invoice_lines.description,
        invoice_lines.amount,
        invoice_lines.currency,
        invoices.invoice_id is not null as has_invoice_parent,
        invoice_lines.line_type in ('base_fare', 'tax', 'airport_fee', 'ancillary', 'discount')
            as has_supported_line_type,
        invoice_lines.currency is not null as has_currency,
        invoice_lines.amount is not null as has_non_null_amount,
        case
            when invoice_lines.ticket_id is not null then ticket_match.ticket_id is not null
            else booking_match.booking_id is not null
        end as expected_pricing_component_available
    from invoice_lines
    left join invoices
        on invoice_lines.invoice_id = invoices.invoice_id
    left join pricing_events_by_ticket as ticket_match
        on
            invoice_lines.ticket_id = ticket_match.ticket_id
            and invoice_lines.line_type = ticket_match.comparable_line_type
            and invoice_lines.reference_code = ticket_match.reference_code
    left join pricing_events_by_booking as booking_match
        on
            invoices.booking_id = booking_match.booking_id
            and invoice_lines.line_type = booking_match.comparable_line_type
            and invoice_lines.reference_code = booking_match.reference_code

)

select
    invoice_line_id,
    invoice_id,
    booking_id,
    ticket_id,
    line_type,
    reference_code,
    description,
    amount,
    currency,
    has_invoice_parent,
    has_supported_line_type,
    has_currency,
    has_non_null_amount,
    expected_pricing_component_available
from joined
