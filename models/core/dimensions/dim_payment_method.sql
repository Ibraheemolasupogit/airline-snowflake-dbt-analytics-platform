-- Grain is one row per payment method. No standalone payment-method source table exists, so this
-- is derived from the distinct values staged in stg_airline__payment_attempts.method and
-- stg_airline__payments.method -- the same "derived from distinct values" pattern Milestone 12
-- used for dim_booking_channel/dim_cabin, justified here because method is reused across both
-- fct_payment_attempts and fct_payments. scripts/airline_synth/reference.py::PAYMENT_METHODS
-- defines three values ("card", "bank_transfer", "voucher"), but
-- scripts/airline_synth/build_billing.py's actual payment flow only ever uses the first two
-- ("card" for the initial attempt, "bank_transfer" for a retry); "voucher" is a defined-but-unused
-- domain value in the current dataset, included here only if it actually appears in the staged
-- distinct values, never fabricated.
with distinct_methods as (

    select method
    from {{ ref('stg_airline__payment_attempts') }}
    where method is not null

    union distinct

    select method
    from {{ ref('stg_airline__payments') }}
    where method is not null

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['method']) }} as payment_method_key,
        method
    from distinct_methods

)

select
    payment_method_key,
    method
from final
