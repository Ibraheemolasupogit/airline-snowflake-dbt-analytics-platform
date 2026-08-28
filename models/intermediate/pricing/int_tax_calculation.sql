-- Deterministic government passenger tax calculation. Grain is one row per issued ticket
-- (ticket_id), matching int_fare_component_calculation and build_billing.py's own per-ticket tax
-- line (`tax_usd = fare_usd * rate`, inside the `for ticket in booking_tickets` loop -- never per
-- ticket_segment).
--
-- Country applicability: stg_airline__taxes.country_code has no documented directionality, but
-- stg_airline__airport_fees.amount is explicitly documented as "applied per departing
-- passenger" (departure-country semantics). For internal consistency this model applies the same
-- departure-country convention to tax: the tax charged is the one belonging to the country of the
-- booking's outbound route origin airport (dim_airport.country_code via dim_route.origin_ident),
-- the same route/airport context int_fare_component_calculation already uses for the fare
-- distance calculation. This is an inferred-but-documented assumption, not an invented field --
-- the source has exactly one tax type per country (COUNTRY_TAX_TYPES has a single entry,
-- replicated per country by scripts/airline_synth/build_pricing.py::build_taxes), so the choice
-- of directionality does not change which row is selected in the current dataset, only how the
-- join is justified.
--
-- percentage_rate is applied against int_fare_component_calculation.pre_discount_fare_usd (the
-- full base + distance fare, in USD) -- matching build_billing.py's `fare_usd * rate` exactly,
-- where fare_usd is the same base+distance amount, not merely fare_classes.base_fare_usd alone.
with fare_components as (

    select
        ticket_id,
        booking_id,
        passenger_id,
        origin_ident,
        currency,
        pre_discount_fare_usd,
        booking_status
    from {{ ref('int_fare_component_calculation') }}

),

origin_airports as (

    select
        airport_ident,
        country_code
    from {{ ref('dim_airport') }}

),

taxes as (

    select
        tax_id,
        country_code,
        tax_code,
        tax_name,
        percentage_rate,
        currency_code as tax_currency_code
    from {{ ref('stg_airline__taxes') }}

),

exchange_rates as (

    select
        currency_code,
        rate_to_usd
    from {{ ref('stg_airline__exchange_rates') }}

),

joined as (

    select
        fare_components.ticket_id,
        fare_components.booking_id,
        fare_components.passenger_id,
        fare_components.origin_ident,
        origin_airports.country_code as origin_country_code,
        fare_components.currency as booking_currency,
        fare_components.pre_discount_fare_usd,
        taxes.tax_id,
        taxes.tax_code,
        taxes.tax_name,
        taxes.percentage_rate,
        taxes.tax_currency_code,
        booking_rates.rate_to_usd as booking_currency_rate_to_usd,
        tax_rates.rate_to_usd as tax_currency_rate_to_usd
    from fare_components
    left join origin_airports
        on fare_components.origin_ident = origin_airports.airport_ident
    left join taxes
        on origin_airports.country_code = taxes.country_code
    left join exchange_rates as booking_rates
        on fare_components.currency = booking_rates.currency_code
    left join exchange_rates as tax_rates
        on taxes.tax_currency_code = tax_rates.currency_code

),

calculated as (

    select
        ticket_id,
        booking_id,
        passenger_id,
        origin_ident,
        origin_country_code,
        booking_currency,
        tax_id,
        tax_code,
        tax_name,
        percentage_rate,
        tax_currency_code,
        pre_discount_fare_usd * percentage_rate as tax_amount_usd,
        {{ convert_currency(
            'pre_discount_fare_usd * percentage_rate', '1.0', 'tax_currency_rate_to_usd'
        ) }} as tax_amount_tax_currency,
        {{ convert_currency(
            'pre_discount_fare_usd * percentage_rate', '1.0', 'booking_currency_rate_to_usd'
        ) }} as tax_amount_booking_currency
    from joined

)

select
    ticket_id,
    booking_id,
    passenger_id,
    origin_ident,
    origin_country_code,
    booking_currency,
    tax_id,
    tax_code,
    tax_name,
    percentage_rate,
    tax_currency_code,
    cast(tax_amount_usd as decimal(18, 2)) as tax_amount_usd,
    tax_amount_tax_currency,
    tax_amount_booking_currency
from calculated
