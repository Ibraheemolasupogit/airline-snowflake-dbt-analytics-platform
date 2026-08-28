-- Deterministic invoice arithmetic control. Grain is one row per invoice (invoice_id). Aggregates
-- stg_airline__invoice_lines by invoice_id and compares the result to the invoice header's own
-- stored amounts -- a purely internal, source-to-source reconciliation (header vs. its own lines),
-- independent of Milestone 13 pricing. See int_invoice_charge_comparison for the separate
-- pricing-vs-invoice control.
--
-- Uses the actual invoice-line sign convention as staged: base_fare/tax/airport_fee/ancillary
-- lines are positive, discount lines are negative
-- (scripts/airline_synth/build_billing.py: `"amount": -discount_amount`). Summing every line's
-- amount for an invoice (discount's negative value included) reproduces the header's total_amount
-- exactly in the clean case -- calculated_invoice_line_total is that sum, kept alongside
-- source_invoice_total (never overwritten) so later assurance/reporting can compare them directly.
--
-- calculated_discount_total is the raw signed sum of discount lines (negative or zero), NOT sign-
-- flipped to match invoices.discount_amount's "positive magnitude" convention -- see
-- docs/data_models/airline_invoices.md for the exact relationship
-- (source_discount_amount = -calculated_discount_total in the clean case).
--
-- Sign convention for invoice_total_variance: source_invoice_total - calculated_invoice_line_total.
-- Positive means the header claims more than its own lines sum to; negative means less (including
-- the deliberately injected missing_invoice_line controlled exception, where a tax line was
-- removed without adjusting the header -- see docs/data_models/airline_synthetic_exception_
-- catalogue.md). This condition is preserved unchanged, never repaired, and not classified as a
-- billing exception here.
with invoices as (

    select
        invoice_id,
        booking_id,
        invoice_date_utc,
        currency,
        bill_to_type,
        bill_to_id,
        subtotal_amount,
        tax_amount,
        fee_amount,
        ancillary_amount,
        discount_amount,
        total_amount
    from {{ ref('stg_airline__invoices') }}

),

invoice_lines as (

    select
        invoice_id,
        line_type,
        amount
    from {{ ref('stg_airline__invoice_lines') }}

),

line_aggregates as (

    select
        invoice_id,
        count(*) as line_count,
        sum(case when line_type = 'base_fare' then amount else 0 end) as calculated_base_fare_total,
        sum(case when line_type = 'tax' then amount else 0 end) as calculated_tax_total,
        sum(case when line_type = 'airport_fee' then amount else 0 end) as calculated_fee_total,
        sum(case when line_type = 'ancillary' then amount else 0 end) as calculated_ancillary_total,
        sum(case when line_type = 'discount' then amount else 0 end) as calculated_discount_total,
        sum(amount) as calculated_invoice_line_total
    from invoice_lines
    group by invoice_id

),

joined as (

    select
        invoices.invoice_id,
        invoices.booking_id,
        invoices.invoice_date_utc,
        invoices.currency,
        invoices.bill_to_type,
        invoices.bill_to_id,
        invoices.subtotal_amount as source_subtotal_amount,
        invoices.tax_amount as source_tax_amount,
        invoices.fee_amount as source_fee_amount,
        invoices.ancillary_amount as source_ancillary_amount,
        invoices.discount_amount as source_discount_amount,
        invoices.total_amount as source_invoice_total,
        coalesce(line_aggregates.line_count, 0) as line_count,
        coalesce(line_aggregates.calculated_base_fare_total, 0) as calculated_base_fare_total,
        coalesce(line_aggregates.calculated_tax_total, 0) as calculated_tax_total,
        coalesce(line_aggregates.calculated_fee_total, 0) as calculated_fee_total,
        coalesce(line_aggregates.calculated_ancillary_total, 0) as calculated_ancillary_total,
        coalesce(line_aggregates.calculated_discount_total, 0) as calculated_discount_total,
        coalesce(line_aggregates.calculated_invoice_line_total, 0) as calculated_invoice_line_total
    from invoices
    left join line_aggregates
        on invoices.invoice_id = line_aggregates.invoice_id

)

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
    cast(calculated_base_fare_total as decimal(18, 2)) as calculated_base_fare_total,
    cast(calculated_tax_total as decimal(18, 2)) as calculated_tax_total,
    cast(calculated_fee_total as decimal(18, 2)) as calculated_fee_total,
    cast(calculated_ancillary_total as decimal(18, 2)) as calculated_ancillary_total,
    cast(calculated_discount_total as decimal(18, 2)) as calculated_discount_total,
    cast(calculated_invoice_line_total as decimal(18, 2)) as calculated_invoice_line_total,
    cast(source_invoice_total - calculated_invoice_line_total as decimal(18, 2)) as invoice_total_variance
from joined
