-- Grain is one row per invoice (invoice_id). Reuses int_invoice_calculation (arithmetic),
-- int_invoice_status (current-state status), and int_payment_allocation (Milestone 15, payment
-- aggregation) rather than re-deriving any of them, and adds surrogate dimension keys, following
-- the established core-layer pattern. No refund amount or recognised-revenue field exists on this
-- fact -- those remain out of scope until Milestone 16+.
--
-- amount_collected/payment_count (Milestone 15) are provisional collected-amount measures, NOT an
-- outstanding-balance calculation: amount_collected sums int_payment_allocation.allocated_amount
-- (the portion of each matched payment actually applied to this invoice, capped at
-- source_invoice_total -- see that model for why) across every payment matched to this invoice_id;
-- it deliberately excludes any payment_without_invoice row, which by definition cannot match an
-- invoice_id. Refunds, credits, and adjustments are not yet modelled anywhere in this repository,
-- so amount_collected - source_invoice_total is NOT a final outstanding_balance and this fact does
-- not expose one; that calculation is reserved for a later milestone once refunds/adjustments
-- exist to net against it.
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

payment_aggregates as (

    select
        invoice_id,
        count(*) as payment_count,
        sum(allocated_amount) as amount_collected
    from {{ ref('int_payment_allocation') }}
    where has_invoice_match
    group by invoice_id

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
        invoice_calculation.invoice_total_variance,
        coalesce(payment_aggregates.payment_count, 0) as payment_count,
        coalesce(payment_aggregates.amount_collected, 0) as amount_collected
    from invoice_calculation
    left join invoice_status
        on invoice_calculation.invoice_id = invoice_status.invoice_id
    left join bookings
        on invoice_calculation.booking_id = bookings.booking_id
    left join currencies
        on invoice_calculation.currency = currencies.currency_code
    left join payment_aggregates
        on invoice_calculation.invoice_id = payment_aggregates.invoice_id

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
        invoice_total_variance,
        payment_count,
        cast(amount_collected as decimal(18, 2)) as amount_collected
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
    invoice_total_variance,
    payment_count,
    amount_collected
from final
