-- Recomputes base_fare_usd + (per_km_usd * distance_km) directly from staging/dim_route,
-- bypassing int_fare_component_calculation entirely, and fails if it disagrees with that model's
-- own pre_discount_fare_usd output by more than a cent -- a regression guard on the deterministic
-- pricing formula, not a tautology.
with recomputed as (

    select
        tickets.ticket_id,
        fare_classes.base_fare_usd + (fare_classes.per_km_usd * routes.distance_km) as expected_fare_usd
    from {{ ref('stg_airline__tickets') }} as tickets
    left join {{ ref('int_booking_current_state') }} as bookings
        on tickets.booking_id = bookings.booking_id
    left join {{ ref('stg_airline__fare_classes') }} as fare_classes
        on tickets.fare_class_code = fare_classes.fare_class_code
    left join {{ ref('dim_route') }} as routes
        on bookings.route_id = routes.route_id

)

select
    recomputed.ticket_id,
    recomputed.expected_fare_usd,
    calc.pre_discount_fare_usd
from recomputed
inner join {{ ref('int_fare_component_calculation') }} as calc
    on recomputed.ticket_id = calc.ticket_id
where abs(recomputed.expected_fare_usd - calc.pre_discount_fare_usd) > 0.01
