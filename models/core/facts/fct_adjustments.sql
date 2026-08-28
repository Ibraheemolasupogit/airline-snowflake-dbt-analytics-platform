-- Grain is one row per adjustment (adjustment_id). Reuses int_adjustment_allocation rather than
-- re-deriving matching/sign-consistency logic, and adds surrogate dimension keys. No
-- revenue-recognition field exists on this fact -- that remains out of scope until Milestone 17+.
-- invoice_key/booking_key are null for the deliberately injected invalid_adjustment controlled
-- exception (has_invoice_match = false) -- preserved, not repaired or dropped.
with allocation as (

    select
        adjustment_id,
        invoice_id,
        booking_id,
        adjustment_type,
        amount,
        currency,
        reason,
        created_at_utc,
        has_invoice_match,
        has_supported_adjustment_type,
        is_currency_match,
        has_expected_sign_for_type
    from {{ ref('int_adjustment_allocation') }}

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
        allocation.adjustment_id,
        invoices.invoice_key,
        allocation.invoice_id,
        bookings.booking_key,
        allocation.booking_id,
        allocation.adjustment_type,
        currencies.currency_key,
        allocation.currency,
        allocation.amount,
        allocation.reason,
        allocation.created_at_utc,
        allocation.has_invoice_match,
        allocation.has_supported_adjustment_type,
        allocation.is_currency_match,
        allocation.has_expected_sign_for_type
    from allocation
    left join invoices
        on allocation.invoice_id = invoices.invoice_id
    left join bookings
        on allocation.booking_id = bookings.booking_id
    left join currencies
        on allocation.currency = currencies.currency_code

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['adjustment_id']) }} as adjustment_key,
        adjustment_id,
        invoice_key,
        invoice_id,
        booking_key,
        booking_id,
        adjustment_type,
        currency_key,
        currency,
        amount,
        reason,
        created_at_utc,
        has_invoice_match,
        has_supported_adjustment_type,
        is_currency_match,
        has_expected_sign_for_type
    from joined

)

select
    adjustment_key,
    adjustment_id,
    invoice_key,
    invoice_id,
    booking_key,
    booking_id,
    adjustment_type,
    currency_key,
    currency,
    amount,
    reason,
    created_at_utc,
    has_invoice_match,
    has_supported_adjustment_type,
    is_currency_match,
    has_expected_sign_for_type
from final
