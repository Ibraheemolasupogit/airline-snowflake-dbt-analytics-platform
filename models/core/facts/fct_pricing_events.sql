-- Grain is one row per priced charge component (charge_component_key, generated from
-- component_key_natural -- the single generation point for this key). Reuses
-- int_booking_charge_components for all derivation/union logic and adds surrogate dimension keys,
-- following the established core-layer pattern (Milestone 11/12: intermediate models join/derive,
-- core models add keys).
--
-- charge_scope documents whether a row is priced per ticket ('ticket': base_fare, distance_fare,
-- tax, airport_fee, ancillary) or per booking ('booking': discount) -- see
-- int_booking_charge_components for why a single uniform grain would require inventing an
-- apportionment rule the source specification does not define.
--
-- Sign convention: amount/amount_usd are positive for every charge component and negative (or
-- zero) for discount. Summing amount for a booking_id yields that booking's net payable total in
-- its own currency, without needing to recompute any pricing -- this is the handoff surface for a
-- future Milestone 14 invoice-line generation model. No invoice_id, payment, refund, adjustment,
-- or revenue-recognition field exists on this fact; those remain out of scope until Milestone 14+.
--
-- fare_class_key/tax_key/service_key/discount_key/route_key/origin_airport_key are populated only
-- for the component types that natural key applies to (see int_booking_charge_components); all
-- others are null by construction, not missing data.
with charge_components as (

    select
        component_key_natural,
        component_type,
        charge_scope,
        booking_id,
        ticket_id,
        passenger_id,
        reference_code,
        description,
        currency,
        amount,
        amount_usd,
        fare_class_code,
        route_id,
        origin_ident,
        tax_id,
        airport_fee_id,
        fee_code,
        service_code,
        discount_code
    from {{ ref('int_booking_charge_components') }}

),

bookings as (

    select
        booking_key,
        booking_id
    from {{ ref('fct_bookings') }}

),

passengers as (

    select
        passenger_key,
        passenger_id
    from {{ ref('dim_passenger') }}

),

fare_classes as (

    select
        fare_class_key,
        fare_class_code
    from {{ ref('dim_fare_class') }}

),

routes as (

    select
        route_key,
        route_id
    from {{ ref('dim_route') }}

),

origin_airports as (

    select
        airport_key,
        airport_ident
    from {{ ref('dim_airport') }}

),

taxes as (

    select
        tax_key,
        tax_id
    from {{ ref('dim_tax') }}

),

services as (

    select
        service_key,
        service_code
    from {{ ref('dim_service') }}

),

discounts as (

    select
        discount_key,
        discount_code
    from {{ ref('dim_discount') }}

),

currencies as (

    select
        currency_key,
        currency_code
    from {{ ref('dim_currency') }}

),

joined as (

    select
        charge_components.component_key_natural,
        charge_components.component_type,
        charge_components.charge_scope,
        bookings.booking_key,
        charge_components.booking_id,
        charge_components.ticket_id,
        passengers.passenger_key,
        charge_components.passenger_id,
        charge_components.reference_code,
        charge_components.description,
        currencies.currency_key,
        charge_components.currency,
        charge_components.amount,
        charge_components.amount_usd,
        fare_classes.fare_class_key,
        charge_components.fare_class_code,
        routes.route_key,
        charge_components.route_id,
        origin_airports.airport_key as origin_airport_key,
        charge_components.origin_ident,
        taxes.tax_key,
        charge_components.tax_id,
        charge_components.airport_fee_id,
        charge_components.fee_code,
        services.service_key,
        charge_components.service_code,
        discounts.discount_key,
        charge_components.discount_code
    from charge_components
    left join bookings
        on charge_components.booking_id = bookings.booking_id
    left join passengers
        on charge_components.passenger_id = passengers.passenger_id
    left join fare_classes
        on charge_components.fare_class_code = fare_classes.fare_class_code
    left join routes
        on charge_components.route_id = routes.route_id
    left join origin_airports
        on charge_components.origin_ident = origin_airports.airport_ident
    left join taxes
        on charge_components.tax_id = taxes.tax_id
    left join services
        on charge_components.service_code = services.service_code
    left join discounts
        on charge_components.discount_code = discounts.discount_code
    left join currencies
        on charge_components.currency = currencies.currency_code

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['component_key_natural']) }} as charge_component_key,
        component_key_natural,
        component_type,
        charge_scope,
        booking_key,
        booking_id,
        ticket_id,
        passenger_key,
        passenger_id,
        reference_code,
        description,
        currency_key,
        currency,
        amount,
        amount_usd,
        fare_class_key,
        fare_class_code,
        route_key,
        route_id,
        origin_airport_key,
        origin_ident,
        tax_key,
        tax_id,
        airport_fee_id,
        fee_code,
        service_key,
        service_code,
        discount_key,
        discount_code
    from joined

)

select
    charge_component_key,
    component_key_natural,
    component_type,
    charge_scope,
    booking_key,
    booking_id,
    ticket_id,
    passenger_key,
    passenger_id,
    reference_code,
    description,
    currency_key,
    currency,
    amount,
    amount_usd,
    fare_class_key,
    fare_class_code,
    route_key,
    route_id,
    origin_airport_key,
    origin_ident,
    tax_key,
    tax_id,
    airport_fee_id,
    fee_code,
    service_key,
    service_code,
    discount_key,
    discount_code
from final
