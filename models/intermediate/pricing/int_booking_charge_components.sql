-- Unified, deterministic charge-component structure. Grain is one row per priced charge
-- component (component_key_natural), a UNION ALL of the five upstream pricing calculations plus
-- one booking-level discount calculation computed here. component_type is one of: base_fare,
-- distance_fare, tax, airport_fee, ancillary, discount.
--
-- Grain is deliberately NOT "one row per ticket_segment" for base_fare/distance_fare/tax/
-- airport_fee/ancillary (all are ticket-scoped, charge_scope = 'ticket' -- see
-- int_fare_component_calculation for why) nor a single uniform grain across every component type:
-- discount is booking-scoped (charge_scope = 'booking'), because scripts/airline_synth/
-- build_billing.py computes exactly one discount line per booking, off a subtotal summed across
-- every ticket in that booking, not per ticket. Forcing every component onto one identical grain
-- would require inventing an apportionment rule the source specification does not define.
--
-- Sign convention: amount and amount_usd are POSITIVE for every charge component (base_fare,
-- distance_fare, tax, airport_fee, ancillary) and NEGATIVE (or zero) for discount -- a discount
-- reduces the total. Summing amount for a given booking_id/ticket_id therefore yields a net
-- payable total directly, matching build_billing.py's own
-- `subtotal + tax_total + fee_total + ancillary_total - discount_amount` arithmetic.
--
-- currency/amount are always in the booking's own currency (int_booking_current_state.currency),
-- matching how build_billing.py denominates every invoice_line. amount_usd is the same amount
-- re-expressed in USD for currency-independent comparison/audit; it is not itself a separate
-- charge.
--
-- Discount calculation: discount_type = 'percentage' -> subtotal_booking_currency * value;
-- discount_type = 'fixed_amount' -> value (documented as a fixed USD amount) converted into the
-- booking's currency. Either way the result is capped at subtotal_booking_currency (never a
-- negative total), matching build_billing.py's `min(discount_amount, subtotal)` exactly.
-- subtotal_booking_currency here is the sum of pre_discount_fare_local across every ticket in the
-- booking (base + distance fare only -- excludes tax/airport_fee/ancillary), matching
-- build_billing.py's `subtotal` variable precisely. A booking with no discount_code produces no
-- discount row at all, matching `if booking["discount_code"]:`.
with base_fare_rows as (

    select
        'base_fare:' || ticket_id as component_key_natural,
        'base_fare' as component_type,
        'ticket' as charge_scope,
        booking_id,
        ticket_id,
        passenger_id,
        fare_class_code as reference_code,
        'Base fare: ' || fare_class_description as description,
        currency,
        base_fare_usd as amount,
        base_fare_usd as amount_usd,
        fare_class_code,
        route_id,
        origin_ident,
        cast(null as varchar) as tax_id,
        cast(null as varchar) as airport_fee_id,
        cast(null as varchar) as fee_code,
        cast(null as varchar) as service_code,
        cast(null as varchar) as discount_code
    from {{ ref('int_fare_component_calculation') }}

),

distance_fare_rows as (

    select
        'distance_fare:' || ticket_id as component_key_natural,
        'distance_fare' as component_type,
        'ticket' as charge_scope,
        booking_id,
        ticket_id,
        passenger_id,
        fare_class_code as reference_code,
        'Distance component: ' || fare_class_description as description,
        currency,
        distance_component_usd as amount,
        distance_component_usd as amount_usd,
        fare_class_code,
        route_id,
        origin_ident,
        cast(null as varchar) as tax_id,
        cast(null as varchar) as airport_fee_id,
        cast(null as varchar) as fee_code,
        cast(null as varchar) as service_code,
        cast(null as varchar) as discount_code
    from {{ ref('int_fare_component_calculation') }}

),

tax_rows as (

    select
        'tax:' || ticket_id || ':' || tax_id as component_key_natural,
        'tax' as component_type,
        'ticket' as charge_scope,
        booking_id,
        ticket_id,
        passenger_id,
        tax_code as reference_code,
        tax_name as description,
        booking_currency as currency,
        tax_amount_booking_currency as amount,
        tax_amount_usd as amount_usd,
        cast(null as varchar) as fare_class_code,
        cast(null as varchar) as route_id,
        origin_ident,
        tax_id,
        cast(null as varchar) as airport_fee_id,
        cast(null as varchar) as fee_code,
        cast(null as varchar) as service_code,
        cast(null as varchar) as discount_code
    from {{ ref('int_tax_calculation') }}

),

airport_fee_rows as (

    select
        'airport_fee:' || ticket_id || ':' || fee_code as component_key_natural,
        'airport_fee' as component_type,
        'ticket' as charge_scope,
        booking_id,
        ticket_id,
        passenger_id,
        fee_code as reference_code,
        fee_name as description,
        booking_currency as currency,
        fee_amount_booking_currency as amount,
        fee_amount_usd as amount_usd,
        cast(null as varchar) as fare_class_code,
        cast(null as varchar) as route_id,
        origin_ident,
        cast(null as varchar) as tax_id,
        airport_fee_id,
        fee_code,
        cast(null as varchar) as service_code,
        cast(null as varchar) as discount_code
    from {{ ref('int_airport_charge_calculation') }}

),

ancillary_rows as (

    select
        'ancillary:' || ancillary_service_id as component_key_natural,
        'ancillary' as component_type,
        'ticket' as charge_scope,
        booking_id,
        ticket_id,
        passenger_id,
        service_code as reference_code,
        'Ancillary service: ' || coalesce(service_name, service_code) as description,
        currency,
        amount,
        amount_usd,
        cast(null as varchar) as fare_class_code,
        cast(null as varchar) as route_id,
        cast(null as varchar) as origin_ident,
        cast(null as varchar) as tax_id,
        cast(null as varchar) as airport_fee_id,
        cast(null as varchar) as fee_code,
        service_code,
        cast(null as varchar) as discount_code
    from {{ ref('int_ancillary_charge_calculation') }}

),

booking_subtotals as (

    select
        booking_id,
        sum(pre_discount_fare_local) as subtotal_booking_currency
    from {{ ref('int_fare_component_calculation') }}
    group by booking_id

),

booking_discount_context as (

    select
        booking_id,
        currency,
        discount_code
    from {{ ref('int_booking_current_state') }}
    where discount_code is not null

),

discounts as (

    select
        discount_code,
        discount_name,
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

discount_calc as (

    select
        booking_discount_context.booking_id,
        booking_discount_context.currency,
        discounts.discount_code,
        discounts.discount_name,
        discounts.discount_type,
        booking_subtotals.subtotal_booking_currency,
        least(
            case
                when discounts.discount_type = 'percentage'
                    then booking_subtotals.subtotal_booking_currency * discounts.discount_value
                when discounts.discount_type = 'fixed_amount'
                    then {{ convert_currency(
                        'discounts.discount_value', '1.0', 'exchange_rates.rate_to_usd'
                    ) }}
            end,
            booking_subtotals.subtotal_booking_currency
        ) as discount_amount_booking_currency
    from booking_discount_context
    left join discounts
        on booking_discount_context.discount_code = discounts.discount_code
    left join booking_subtotals
        on booking_discount_context.booking_id = booking_subtotals.booking_id
    left join exchange_rates
        on booking_discount_context.currency = exchange_rates.currency_code

),

discount_rows as (

    select
        'discount:' || booking_id || ':' || discount_code as component_key_natural,
        'discount' as component_type,
        'booking' as charge_scope,
        booking_id,
        cast(null as varchar) as ticket_id,
        cast(null as varchar) as passenger_id,
        discount_code as reference_code,
        'Discount: ' || discount_name as description,
        currency,
        -1 * discount_amount_booking_currency as amount,
        cast(null as decimal(18, 2)) as amount_usd,
        cast(null as varchar) as fare_class_code,
        cast(null as varchar) as route_id,
        cast(null as varchar) as origin_ident,
        cast(null as varchar) as tax_id,
        cast(null as varchar) as airport_fee_id,
        cast(null as varchar) as fee_code,
        cast(null as varchar) as service_code,
        discount_code
    from discount_calc

),

unioned as (

    select * from base_fare_rows
    union all
    select * from distance_fare_rows
    union all
    select * from tax_rows
    union all
    select * from airport_fee_rows
    union all
    select * from ancillary_rows
    union all
    select * from discount_rows

)

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
    cast(amount as decimal(18, 2)) as amount,
    cast(amount_usd as decimal(18, 2)) as amount_usd,
    fare_class_code,
    route_id,
    origin_ident,
    tax_id,
    airport_fee_id,
    fee_code,
    service_code,
    discount_code
from unioned
