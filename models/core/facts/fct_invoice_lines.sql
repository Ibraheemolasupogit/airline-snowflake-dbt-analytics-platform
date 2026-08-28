-- Grain is one row per invoice line (invoice_line_id). Reuses int_invoice_line_validation
-- (structural validation) and int_invoice_charge_comparison (pricing-vs-invoice evidence) rather
-- than re-deriving either, and adds surrogate dimension keys. No payment/refund/revenue field
-- exists on this fact -- those remain out of scope until Milestone 15+.
--
-- expected_amount/pricing_variance_amount are joined in from int_invoice_charge_comparison on the
-- same (invoice_id, ticket_id, line_type, reference_code) key that model uses; because that key
-- matches Milestone 9's actual generation grain precisely (verified against build_billing.py), this
-- join is 1:1 for a normal line, not a many-broadcast. The deliberately injected incorrect_fare
-- controlled exception (see docs/data_models/airline_synthetic_exception_catalogue.md) therefore
-- surfaces here as a nonzero pricing_variance_amount on exactly the one affected base_fare line,
-- without this model correcting it or labelling it an exception.
with line_validation as (

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
    from {{ ref('int_invoice_line_validation') }}

),

charge_comparison as (

    select
        invoice_id,
        ticket_id,
        comparable_line_type,
        reference_code,
        expected_amount,
        variance_amount
    from {{ ref('int_invoice_charge_comparison') }}

),

invoices as (

    select
        invoice_key,
        invoice_id
    from {{ ref('fct_invoices') }}

),

bookings as (

    select
        booking_key,
        booking_id
    from {{ ref('fct_bookings') }}

),

currencies as (

    select
        currency_key,
        currency_code
    from {{ ref('dim_currency') }}

),

joined as (

    select
        line_validation.invoice_line_id,
        invoices.invoice_key,
        line_validation.invoice_id,
        bookings.booking_key,
        line_validation.booking_id,
        line_validation.ticket_id,
        line_validation.line_type,
        line_validation.reference_code,
        line_validation.description,
        currencies.currency_key,
        line_validation.currency,
        line_validation.amount,
        line_validation.has_invoice_parent,
        line_validation.has_supported_line_type,
        line_validation.has_currency,
        line_validation.has_non_null_amount,
        line_validation.expected_pricing_component_available,
        charge_comparison.expected_amount,
        charge_comparison.variance_amount as pricing_variance_amount
    from line_validation
    left join charge_comparison
        on
            line_validation.invoice_id = charge_comparison.invoice_id
            and line_validation.line_type = charge_comparison.comparable_line_type
            and equal_null(line_validation.reference_code, charge_comparison.reference_code)
            and equal_null(line_validation.ticket_id, charge_comparison.ticket_id)
    left join invoices
        on line_validation.invoice_id = invoices.invoice_id
    left join bookings
        on line_validation.booking_id = bookings.booking_id
    left join currencies
        on line_validation.currency = currencies.currency_code

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['invoice_line_id']) }} as invoice_line_key,
        invoice_line_id,
        invoice_key,
        invoice_id,
        booking_key,
        booking_id,
        ticket_id,
        line_type,
        reference_code,
        description,
        currency_key,
        currency,
        amount,
        has_invoice_parent,
        has_supported_line_type,
        has_currency,
        has_non_null_amount,
        expected_pricing_component_available,
        expected_amount,
        pricing_variance_amount
    from joined

)

select
    invoice_line_key,
    invoice_line_id,
    invoice_key,
    invoice_id,
    booking_key,
    booking_id,
    ticket_id,
    line_type,
    reference_code,
    description,
    currency_key,
    currency,
    amount,
    has_invoice_parent,
    has_supported_line_type,
    has_currency,
    has_non_null_amount,
    expected_pricing_component_available,
    expected_amount,
    pricing_variance_amount
from final
