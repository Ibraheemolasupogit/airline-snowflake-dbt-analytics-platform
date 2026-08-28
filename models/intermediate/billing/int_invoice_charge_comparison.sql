-- Pricing-vs-invoice comparison evidence. Grain is one row per (invoice_id, comparable_line_type,
-- reference_code, ticket_id) -- ticket_id is null only for the booking-scoped discount type. This
-- model exposes comparison evidence only: expected amount, invoiced amount, variance amount,
-- component type, booking/ticket references, currency. It does NOT classify anything as a billing
-- exception (no is_incorrect_fare / billing_exception_type / financial_value_at_risk column) --
-- that classification belongs to a later milestone.
--
-- comparable_line_type buckets Milestone 13's component_type onto Milestone 9's invoice_lines
-- line_type: 'base_fare' and 'distance_fare' both map to 'base_fare' (see below for why), and
-- every other component_type maps to itself unchanged. This same mapping is intentionally kept in
-- sync with int_invoice_line_validation's expected_pricing_component_available check.
--
-- Why base_fare + distance_fare collapse to one bucket: scripts/airline_synth/build_billing.py
-- generates exactly ONE 'base_fare' invoice line per ticket, with amount = base_fare_usd +
-- per_km_usd * distance_km combined (see _fare_amount_usd) -- there is no separate 'distance_fare'
-- line_type anywhere in the Milestone 9 specification. Comparing Milestone 13's separate
-- base_fare/distance_fare components individually against that single combined source line would
-- produce a spurious variance on every ticket, not a real one. Grouping by reference_code (both
-- Milestone 13 rows share fare_class_code) achieves this combination without any special-case
-- logic.
--
-- reference_code alignment (verified against build_billing.py's invoice_lines construction) lets
-- every component type match precisely, not just by bucket: fare_class_code (base_fare),
-- tax_code (tax), fee_code (airport_fee), service_code (ancillary), discount_code (discount) are
-- identical on both the fct_pricing_events side (Milestone 13) and the invoice_lines side
-- (Milestone 9 source).
--
-- The duplicate_invoice controlled exception (two invoice_ids for the same booking_id) is
-- preserved and observable, not resolved: because the expected side is joined via invoice_id ->
-- booking_id -> ticket_id, both invoices for a duplicated booking each get their own full set of
-- comparison rows against the SAME expected pricing -- exactly the evidence Milestone 18 will need.
--
-- Sign convention: variance_amount = invoiced_amount - expected_amount, consistent with
-- int_invoice_calculation.invoice_total_variance's "source minus calculated/expected" convention.
-- Positive means the invoice charged more than expected; negative means less, including a
-- component missing entirely from the invoice (invoiced_amount null, treated as 0 for the
-- subtraction only -- the raw invoiced_amount/expected_amount columns stay nullable so a reader
-- can distinguish "charged zero" from "no line exists at all").
with pricing_events as (

    select
        component_type,
        charge_scope,
        booking_id,
        ticket_id,
        reference_code,
        currency,
        amount
    from {{ ref('fct_pricing_events') }}

),

expected_ticket_scoped as (

    select
        ticket_id,
        reference_code,
        currency,
        case
            when component_type in ('base_fare', 'distance_fare') then 'base_fare'
            else component_type
        end as comparable_line_type,
        sum(amount) as expected_amount
    from pricing_events
    where charge_scope = 'ticket'
    group by
        ticket_id,
        case
            when component_type in ('base_fare', 'distance_fare') then 'base_fare'
            else component_type
        end,
        reference_code,
        currency

),

expected_booking_scoped as (

    select
        booking_id,
        component_type as comparable_line_type,
        reference_code,
        currency,
        sum(amount) as expected_amount
    from pricing_events
    where charge_scope = 'booking'
    group by booking_id, component_type, reference_code, currency

),

invoice_ticket_map as (

    select
        invoices.invoice_id,
        invoices.booking_id,
        tickets.ticket_id
    from {{ ref('stg_airline__invoices') }} as invoices
    inner join {{ ref('stg_airline__tickets') }} as tickets
        on invoices.booking_id = tickets.booking_id

),

expected_by_invoice as (

    select
        invoice_ticket_map.invoice_id,
        invoice_ticket_map.booking_id,
        invoice_ticket_map.ticket_id,
        expected_ticket_scoped.comparable_line_type,
        expected_ticket_scoped.reference_code,
        expected_ticket_scoped.currency,
        expected_ticket_scoped.expected_amount
    from invoice_ticket_map
    inner join expected_ticket_scoped
        on invoice_ticket_map.ticket_id = expected_ticket_scoped.ticket_id

    union all

    select
        invoices.invoice_id,
        invoices.booking_id,
        cast(null as varchar) as ticket_id,
        expected_booking_scoped.comparable_line_type,
        expected_booking_scoped.reference_code,
        expected_booking_scoped.currency,
        expected_booking_scoped.expected_amount
    from {{ ref('stg_airline__invoices') }} as invoices
    inner join expected_booking_scoped
        on invoices.booking_id = expected_booking_scoped.booking_id

),

invoiced_lines as (

    select
        invoice_id,
        ticket_id,
        line_type as comparable_line_type,
        reference_code,
        currency,
        sum(amount) as invoiced_amount
    from {{ ref('stg_airline__invoice_lines') }}
    group by invoice_id, ticket_id, line_type, reference_code, currency

),

compared as (

    select
        expected_by_invoice.expected_amount,
        invoiced_lines.invoiced_amount,
        coalesce(expected_by_invoice.invoice_id, invoiced_lines.invoice_id) as invoice_id,
        coalesce(expected_by_invoice.booking_id, invoice_booking_fallback.booking_id) as booking_id,
        coalesce(expected_by_invoice.ticket_id, invoiced_lines.ticket_id) as ticket_id,
        coalesce(
            expected_by_invoice.comparable_line_type, invoiced_lines.comparable_line_type
        ) as comparable_line_type,
        coalesce(expected_by_invoice.reference_code, invoiced_lines.reference_code) as reference_code,
        coalesce(expected_by_invoice.currency, invoiced_lines.currency) as currency
    from expected_by_invoice
    full outer join invoiced_lines
        on
            expected_by_invoice.invoice_id = invoiced_lines.invoice_id
            and expected_by_invoice.comparable_line_type = invoiced_lines.comparable_line_type
            and equal_null(expected_by_invoice.reference_code, invoiced_lines.reference_code)
            and equal_null(expected_by_invoice.ticket_id, invoiced_lines.ticket_id)
    left join {{ ref('stg_airline__invoices') }} as invoice_booking_fallback
        on invoiced_lines.invoice_id = invoice_booking_fallback.invoice_id

)

select
    invoice_id,
    booking_id,
    ticket_id,
    comparable_line_type,
    reference_code,
    currency,
    cast(expected_amount as decimal(18, 2)) as expected_amount,
    cast(invoiced_amount as decimal(18, 2)) as invoiced_amount,
    cast(coalesce(invoiced_amount, 0) - coalesce(expected_amount, 0) as decimal(18, 2)) as variance_amount
from compared
