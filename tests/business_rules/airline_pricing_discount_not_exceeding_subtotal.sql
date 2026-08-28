-- Fails if any booking's discount component magnitude exceeds the pre-tax fare subtotal it was
-- computed from -- the same cap scripts/airline_synth/build_billing.py applies via
-- min(discount_amount, subtotal). int_booking_charge_components already enforces this by
-- construction (least(...)); this test guards the invariant directly.
with discounts as (

    select
        booking_id,
        amount
    from {{ ref('int_booking_charge_components') }}
    where component_type = 'discount'

),

subtotals as (

    select
        booking_id,
        sum(pre_discount_fare_local) as subtotal_booking_currency
    from {{ ref('int_fare_component_calculation') }}
    group by booking_id

)

select
    discounts.booking_id,
    discounts.amount,
    subtotals.subtotal_booking_currency
from discounts
left join subtotals
    on discounts.booking_id = subtotals.booking_id
where abs(discounts.amount) > subtotals.subtotal_booking_currency + 0.01
