-- Deterministic fare-component calculation. Grain is one row per issued ticket (ticket_id), NOT
-- one row per ticket_segment. Verified against scripts/airline_synth/build_billing.py
-- (_fare_amount_usd, and the `for ticket in booking_tickets` loop): the Milestone 9 generator
-- computes exactly one base-fare + distance component per ticket, using the booking's single
-- outbound route (booking.route_id) distance -- never a per-segment distance, and never the
-- return_route_id, even for round trips. There is no per-segment fare-apportionment rule anywhere
-- in the specification, so modelling this at ticket_segment_id grain would require inventing one,
-- which "do not invent airline-industry formulas that are absent from the synthetic
-- specification" (Milestone 13 scope) rules out. ticket_segment_id is therefore intentionally not
-- part of this grain; join fct_ticket_segments on ticket_id when segment-level display context
-- (cabin, flight timing) is needed alongside a priced ticket.
--
-- Formula (fare_usd = base_fare_usd + per_km_usd * distance_km) matches
-- build_billing.py::_fare_amount_usd exactly. pre_discount_fare_local is the same amount
-- converted into the booking's currency via the convert_currency macro, mirroring
-- build_billing.py's convert_usd(fare_usd, currency, ...) step. No tax, airport fee, ancillary,
-- or discount amount is included here -- see int_tax_calculation, int_airport_charge_calculation,
-- int_ancillary_charge_calculation, and int_booking_charge_components respectively.
--
-- discount_code/discount_type/discount_value are carried through from the parent booking as
-- informational context only (a booking-level attribute, not a per-ticket one -- see
-- int_booking_charge_components for the actual discount dollar amount, which requires summing
-- pre_discount_fare_local across every ticket in the booking, matching build_billing.py's
-- booking-level `subtotal`).
with tickets as (

    select
        ticket_id,
        ticket_number,
        booking_id,
        passenger_id,
        fare_class_code,
        ticket_status
    from {{ ref('stg_airline__tickets') }}

),

bookings as (

    select
        booking_id,
        route_id,
        trip_type,
        currency,
        booking_status,
        discount_code
    from {{ ref('int_booking_current_state') }}

),

fare_classes as (

    select
        fare_class_code,
        cabin,
        fare_basis_code,
        description,
        base_fare_usd,
        per_km_usd
    from {{ ref('stg_airline__fare_classes') }}

),

routes as (

    select
        route_id,
        origin_ident,
        destination_ident,
        distance_km
    from {{ ref('dim_route') }}

),

discounts as (

    select
        discount_code,
        discount_type,
        value as discount_value
    from {{ ref('stg_airline__discounts') }}

),

exchange_rates as (

    select
        currency_code,
        rate_to_usd
    from {{ ref('stg_airline__exchange_rates') }}

),

joined as (

    select
        tickets.ticket_id,
        tickets.ticket_number,
        tickets.booking_id,
        tickets.passenger_id,
        bookings.route_id,
        bookings.trip_type,
        routes.origin_ident,
        routes.destination_ident,
        routes.distance_km,
        tickets.fare_class_code,
        fare_classes.cabin,
        fare_classes.fare_basis_code,
        fare_classes.description as fare_class_description,
        fare_classes.base_fare_usd,
        fare_classes.per_km_usd,
        bookings.currency,
        bookings.booking_status,
        bookings.discount_code,
        discounts.discount_type,
        discounts.discount_value,
        exchange_rates.rate_to_usd as booking_currency_rate_to_usd
    from tickets
    left join bookings
        on tickets.booking_id = bookings.booking_id
    left join fare_classes
        on tickets.fare_class_code = fare_classes.fare_class_code
    left join routes
        on bookings.route_id = routes.route_id
    left join discounts
        on bookings.discount_code = discounts.discount_code
    left join exchange_rates
        on bookings.currency = exchange_rates.currency_code

),

calculated as (

    select
        ticket_id,
        ticket_number,
        booking_id,
        passenger_id,
        route_id,
        trip_type,
        origin_ident,
        destination_ident,
        distance_km,
        fare_class_code,
        cabin,
        fare_basis_code,
        fare_class_description,
        currency,
        booking_status,
        discount_code,
        discount_type,
        discount_value,
        booking_currency_rate_to_usd,
        base_fare_usd,
        per_km_usd * distance_km as distance_component_usd,
        base_fare_usd + (per_km_usd * distance_km) as pre_discount_fare_usd,
        {{ convert_currency(
            'base_fare_usd + (per_km_usd * distance_km)', '1.0', 'booking_currency_rate_to_usd'
        ) }} as pre_discount_fare_local
    from joined

)

select
    ticket_id,
    ticket_number,
    booking_id,
    passenger_id,
    route_id,
    trip_type,
    origin_ident,
    destination_ident,
    distance_km,
    fare_class_code,
    cabin,
    fare_basis_code,
    fare_class_description,
    currency,
    booking_status,
    discount_code,
    discount_type,
    discount_value,
    booking_currency_rate_to_usd,
    cast(base_fare_usd as decimal(18, 2)) as base_fare_usd,
    cast(distance_component_usd as decimal(18, 2)) as distance_component_usd,
    cast(pre_discount_fare_usd as decimal(18, 2)) as pre_discount_fare_usd,
    pre_discount_fare_local
from calculated
