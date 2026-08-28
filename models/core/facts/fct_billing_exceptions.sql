-- Grain is one row per detected billing/revenue exception. Reuses int_billing_exceptions (which
-- reuses Milestone 14-17 evidence directly, recomputing nothing) and adds surrogate dimension
-- keys plus deterministic current-state workflow defaults, following the established core-layer
-- pattern.
--
-- Workflow fields (status, assigned_owner, resolution_date, root_cause, remediation_action): no
-- investigation ever occurred in this synthetic dataset, so this milestone does not fabricate one.
-- status defaults to the single deterministic value 'open' for every detected exception (a
-- reasonable current-state default: every exception here was just detected, not yet worked).
-- assigned_owner, resolution_date, root_cause, and remediation_action are always null -- no
-- deterministic synthetic workflow-history data exists anywhere in the Milestone 9 specification
-- to populate them honestly, and this milestone explicitly avoids pretending a human investigation
-- took place. rule_description (from int_billing_exceptions) is NOT a root-cause finding -- it is
-- a mechanical statement of which detection rule fired, kept as a clearly separate column.
--
-- invoice_key is null for the duplicate_invoice exception_type: its own source_record_id/
-- invoice_id is a pipe-joined pair of invoice_ids (e.g. "INV-00005|INV-00005-DUP"), not a single
-- resolvable invoice_id -- both affected invoices remain independently visible via
-- fct_outstanding_balances/fct_invoices, joined by booking_id.
with exceptions as (

    select
        exception_type,
        source_system,
        source_record_id,
        booking_id,
        ticket_id,
        ticket_segment_id,
        flight_instance_id,
        invoice_id,
        payment_id,
        refund_id,
        adjustment_id,
        route_id,
        airport_ident,
        currency,
        detected_at,
        financial_value_at_risk_amount,
        rule_description,
        severity
    from {{ ref('int_billing_exceptions') }}

),

bookings as (

    select
        booking_key,
        booking_id
    from {{ ref('fct_bookings') }}

),

invoices as (

    select
        invoice_key,
        invoice_id
    from {{ ref('fct_invoices') }}

),

payments as (

    select
        payment_key,
        payment_id
    from {{ ref('fct_payments') }}

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

routes as (

    select
        route_key,
        route_id
    from {{ ref('dim_route') }}

),

airports as (

    select
        airport_key,
        airport_ident
    from {{ ref('dim_airport') }}

),

currencies as (

    select
        currency_key,
        currency_code
    from {{ ref('dim_currency') }}

),

joined as (

    select
        exceptions.exception_type,
        exceptions.source_system,
        exceptions.source_record_id,
        bookings.booking_key,
        exceptions.booking_id,
        exceptions.ticket_id,
        exceptions.ticket_segment_id,
        exceptions.flight_instance_id,
        invoices.invoice_key,
        exceptions.invoice_id,
        payments.payment_key,
        exceptions.payment_id,
        refunds.refund_key,
        exceptions.refund_id,
        adjustments.adjustment_key,
        exceptions.adjustment_id,
        routes.route_key,
        exceptions.route_id,
        airports.airport_key,
        exceptions.airport_ident,
        currencies.currency_key,
        exceptions.currency,
        exceptions.detected_at,
        exceptions.financial_value_at_risk_amount,
        exceptions.rule_description,
        exceptions.severity
    from exceptions
    left join bookings
        on exceptions.booking_id = bookings.booking_id
    left join invoices
        on exceptions.invoice_id = invoices.invoice_id
    left join payments
        on exceptions.payment_id = payments.payment_id
    left join refunds
        on exceptions.refund_id = refunds.refund_id
    left join adjustments
        on exceptions.adjustment_id = adjustments.adjustment_id
    left join routes
        on exceptions.route_id = routes.route_id
    left join airports
        on exceptions.airport_ident = airports.airport_ident
    left join currencies
        on exceptions.currency = currencies.currency_code

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['exception_type', 'source_record_id']) }} as exception_key,
        exception_type,
        source_system,
        source_record_id,
        booking_key,
        booking_id,
        ticket_id,
        ticket_segment_id,
        flight_instance_id,
        invoice_key,
        invoice_id,
        payment_key,
        payment_id,
        refund_key,
        refund_id,
        adjustment_key,
        adjustment_id,
        route_key,
        route_id,
        airport_key,
        airport_ident,
        currency_key,
        currency,
        detected_at,
        financial_value_at_risk_amount,
        rule_description,
        severity,
        'open' as status,
        cast(null as varchar) as assigned_owner,
        cast(null as timestamp_ntz) as resolution_date,
        cast(null as varchar) as root_cause,
        cast(null as varchar) as remediation_action
    from joined

)

select
    exception_key,
    exception_type,
    source_system,
    source_record_id,
    booking_key,
    booking_id,
    ticket_id,
    ticket_segment_id,
    flight_instance_id,
    invoice_key,
    invoice_id,
    payment_key,
    payment_id,
    refund_key,
    refund_id,
    adjustment_key,
    adjustment_id,
    route_key,
    route_id,
    airport_key,
    airport_ident,
    currency_key,
    currency,
    detected_at,
    financial_value_at_risk_amount,
    rule_description,
    severity,
    status,
    assigned_owner,
    resolution_date,
    root_cause,
    remediation_action
from final
