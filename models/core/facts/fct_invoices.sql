-- Grain is one row per invoice (invoice_id). Reuses int_invoice_calculation (arithmetic) and
-- int_invoice_status (current-state status) rather than re-deriving either, and adds surrogate
-- dimension keys, following the established core-layer pattern. No amount_paid, outstanding
-- balance, refund amount, or recognised-revenue field exists on this fact -- those remain out of
-- scope until Milestone 15+.
--
-- The duplicate_invoice controlled exception (see docs/data_models/airline_synthetic_exception_
-- catalogue.md) produces two distinct invoice_id rows sharing the same booking_id; both are
-- preserved unchanged here -- booking_id is intentionally not unique-tested on this fact.
with invoice_calculation as (

    select
        invoice_id,
        booking_id,
        invoice_date_utc,
        currency,
        bill_to_type,
        bill_to_id,
        source_subtotal_amount,
        source_tax_amount,
        source_fee_amount,
        source_ancillary_amount,
        source_discount_amount,
        source_invoice_total,
        line_count,
        calculated_base_fare_total,
        calculated_tax_total,
        calculated_fee_total,
        calculated_ancillary_total,
        calculated_discount_total,
        calculated_invoice_line_total,
        invoice_total_variance
    from {{ ref('int_invoice_calculation') }}

),

invoice_status as (

    select
        invoice_id,
        status,
        is_cancelled
    from {{ ref('int_invoice_status') }}

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
        invoice_calculation.invoice_id,
        bookings.booking_key,
        invoice_calculation.booking_id,
        invoice_calculation.invoice_date_utc,
        currencies.currency_key,
        invoice_calculation.currency,
        invoice_calculation.bill_to_type,
        invoice_calculation.bill_to_id,
        invoice_status.status,
        invoice_status.is_cancelled,
        invoice_calculation.source_subtotal_amount,
        invoice_calculation.source_tax_amount,
        invoice_calculation.source_fee_amount,
        invoice_calculation.source_ancillary_amount,
        invoice_calculation.source_discount_amount,
        invoice_calculation.source_invoice_total,
        invoice_calculation.line_count,
        invoice_calculation.calculated_base_fare_total,
        invoice_calculation.calculated_tax_total,
        invoice_calculation.calculated_fee_total,
        invoice_calculation.calculated_ancillary_total,
        invoice_calculation.calculated_discount_total,
        invoice_calculation.calculated_invoice_line_total,
        invoice_calculation.invoice_total_variance
    from invoice_calculation
    left join invoice_status
        on invoice_calculation.invoice_id = invoice_status.invoice_id
    left join bookings
        on invoice_calculation.booking_id = bookings.booking_id
    left join currencies
        on invoice_calculation.currency = currencies.currency_code

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['invoice_id']) }} as invoice_key,
        invoice_id,
        booking_key,
        booking_id,
        invoice_date_utc,
        currency_key,
        currency,
        bill_to_type,
        bill_to_id,
        status,
        is_cancelled,
        source_subtotal_amount,
        source_tax_amount,
        source_fee_amount,
        source_ancillary_amount,
        source_discount_amount,
        source_invoice_total,
        line_count,
        calculated_base_fare_total,
        calculated_tax_total,
        calculated_fee_total,
        calculated_ancillary_total,
        calculated_discount_total,
        calculated_invoice_line_total,
        invoice_total_variance
    from joined

)

select
    invoice_key,
    invoice_id,
    booking_key,
    booking_id,
    invoice_date_utc,
    currency_key,
    currency,
    bill_to_type,
    bill_to_id,
    status,
    is_cancelled,
    source_subtotal_amount,
    source_tax_amount,
    source_fee_amount,
    source_ancillary_amount,
    source_discount_amount,
    source_invoice_total,
    line_count,
    calculated_base_fare_total,
    calculated_tax_total,
    calculated_fee_total,
    calculated_ancillary_total,
    calculated_discount_total,
    calculated_invoice_line_total,
    invoice_total_variance
from final
