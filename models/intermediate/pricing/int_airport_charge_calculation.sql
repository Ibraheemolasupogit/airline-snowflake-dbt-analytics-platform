-- Deterministic airport-charge calculation. Grain is one row per (ticket_id, fee_code) -- two
-- rows per ticket in the current dataset (PSC, SEC; scripts/airline_synth/reference.py's
-- AIRPORT_FEE_TYPES), matching int_fare_component_calculation's per-ticket grain.
--
-- Only ORIGIN (departure) airport charges are modelled: stg_airline__airport_fees.amount is
-- documented as "applied per departing passenger," and no destination/arrival-fee semantics exist
-- anywhere in the Milestone 9 specification, so a destination charge would be invented. The origin
-- airport used is the booking's outbound route origin (the same route/airport context
-- int_fare_component_calculation and int_tax_calculation already use), never the return leg's
-- origin, consistent with build_billing.py, which never varies airport-fee amounts by route or
-- airport at all (it applies a flat global USD amount per ticket, ignoring airport_ident
-- entirely). This model deliberately does NOT replicate that flattened invoice-line
-- simplification -- it uses the real stg_airline__airport_fees per-airport, per-fee-code amounts
-- (already denominated in that airport's own local currency by
-- scripts/airline_synth/build_pricing.py::build_airport_fees), which is the more granular,
-- source-data-driven "list" charge this milestone's pricing layer is meant to produce.
-- airport_ident is preserved exactly as staged (AirStats-conformed, joined to dim_airport here for
-- the first time per stg_airline__airport_fees' own staging-layer note).
with fare_components as (

    select
        ticket_id,
        booking_id,
        passenger_id,
        origin_ident,
        currency,
        booking_status
    from {{ ref('int_fare_component_calculation') }}

),

airport_fees as (

    select
        airport_fee_id,
        airport_ident,
        fee_code,
        fee_name,
        currency_code as fee_currency_code,
        amount as fee_amount
    from {{ ref('stg_airline__airport_fees') }}

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
        fare_components.currency as booking_currency,
        airport_fees.airport_fee_id,
        airport_fees.fee_code,
        airport_fees.fee_name,
        airport_fees.fee_currency_code,
        airport_fees.fee_amount,
        booking_rates.rate_to_usd as booking_currency_rate_to_usd,
        fee_rates.rate_to_usd as fee_currency_rate_to_usd
    from fare_components
    left join airport_fees
        on fare_components.origin_ident = airport_fees.airport_ident
    left join exchange_rates as booking_rates
        on fare_components.currency = booking_rates.currency_code
    left join exchange_rates as fee_rates
        on airport_fees.fee_currency_code = fee_rates.currency_code

),

calculated as (

    select
        ticket_id,
        booking_id,
        passenger_id,
        origin_ident,
        booking_currency,
        airport_fee_id,
        fee_code,
        fee_name,
        fee_currency_code,
        fee_amount,
        {{ convert_currency(
            'fee_amount', 'fee_currency_rate_to_usd', '1.0'
        ) }} as fee_amount_usd,
        {{ convert_currency(
            'fee_amount', 'fee_currency_rate_to_usd', 'booking_currency_rate_to_usd'
        ) }} as fee_amount_booking_currency
    from joined

)

select
    ticket_id,
    booking_id,
    passenger_id,
    origin_ident,
    booking_currency,
    airport_fee_id,
    fee_code,
    fee_name,
    fee_currency_code,
    fee_amount,
    fee_amount_usd,
    fee_amount_booking_currency
from calculated
