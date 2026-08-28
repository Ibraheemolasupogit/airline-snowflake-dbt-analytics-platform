-- Grain is one row per discount code. Natural key is discount_code. discount_type governs how
-- value is interpreted (percentage fraction, or fixed USD amount) -- see int_booking_charge_
-- components for the exact application formula. corporate_account_id restricts a CORP-* discount
-- to one corporate account; generic discounts (WELCOME10, SUMMER25, LOYALTY5) leave it null.
-- Eligibility (a booking may only use a corporate discount matching its own corporate_account_id)
-- is guaranteed by construction in scripts/airline_synth/build_bookings.py, so no additional
-- eligibility-enforcement logic is invented here.
with discounts as (

    select
        discount_code,
        discount_name,
        discount_type,
        value,
        corporate_account_id
    from {{ ref('stg_airline__discounts') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['discount_code']) }} as discount_key,
        discount_code,
        discount_name,
        discount_type,
        value,
        corporate_account_id
    from discounts

)

select
    discount_key,
    discount_code,
    discount_name,
    discount_type,
    value,
    corporate_account_id
from final
