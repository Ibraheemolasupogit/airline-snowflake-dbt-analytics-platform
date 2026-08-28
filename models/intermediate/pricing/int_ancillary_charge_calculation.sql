-- Deterministic ancillary-service charge calculation. Grain is one row per ancillary service sold
-- (ancillary_service_id), matching stg_airline__ancillary_services' own grain exactly -- no
-- aggregation or re-grouping. Ancillary services are sold against a ticket
-- (stg_airline__ancillary_services.ticket_id), never a specific ticket_segment
-- (docs/data_models/airline_synthetic_source_data.md's Relational Flow: "ticket -> ancillary_service
-- (0-2 sold per issued ticket)"), so this model is ticket-scoped like
-- int_fare_component_calculation, not segment-scoped.
--
-- amount = unit_price * quantity, in ancillary_services.currency as staged (no invented
-- calculation). scripts/airline_synth/build_bookings.py::build_ancillary_services always sets
-- this currency equal to the parent booking's currency and quantity to 1 in the current dataset,
-- so amount is already denominated in the booking's currency by construction; the join to the
-- booking's currency below is still performed explicitly (not assumed) so this model keeps working
-- correctly if that generator behaviour ever changes.
--
-- amount_usd = quantity * stg_airline__services.base_price_usd -- the service catalog's own USD
-- list price, not a currency conversion of amount (unit_price itself was derived from
-- base_price_usd at sale time; see build_ancillary_services), giving a stable, source-grounded
-- USD figure for cross-currency comparison consistent with the other components' amount_usd.
--
-- fulfilment_status is preserved unchanged, including the two deliberately injected controlled
-- exceptions (ancillary_sold_but_not_fulfilled, ancillary_fulfilled_but_not_billed -- see
-- docs/data_models/airline_synthetic_exception_catalogue.md). No fulfilment-driven revenue
-- recognition is derived here; that is out of scope until a later milestone.
with ancillary_services as (

    select
        ancillary_service_id,
        ticket_id,
        service_code,
        quantity,
        unit_price,
        currency,
        fulfilment_status,
        purchase_date_utc
    from {{ ref('stg_airline__ancillary_services') }}

),

services as (

    select
        service_code,
        service_name,
        category,
        base_price_usd
    from {{ ref('stg_airline__services') }}

),

tickets as (

    select
        ticket_id,
        booking_id,
        passenger_id
    from {{ ref('stg_airline__tickets') }}

),

bookings as (

    select
        booking_id,
        currency as booking_currency
    from {{ ref('int_booking_current_state') }}

),

joined as (

    select
        ancillary_services.ancillary_service_id,
        ancillary_services.ticket_id,
        tickets.booking_id,
        tickets.passenger_id,
        ancillary_services.service_code,
        services.service_name,
        services.category as service_category,
        services.base_price_usd,
        ancillary_services.quantity,
        ancillary_services.unit_price,
        ancillary_services.currency,
        bookings.booking_currency,
        ancillary_services.fulfilment_status,
        ancillary_services.purchase_date_utc
    from ancillary_services
    left join services
        on ancillary_services.service_code = services.service_code
    left join tickets
        on ancillary_services.ticket_id = tickets.ticket_id
    left join bookings
        on tickets.booking_id = bookings.booking_id

)

select
    ancillary_service_id,
    ticket_id,
    booking_id,
    passenger_id,
    service_code,
    service_name,
    service_category,
    quantity,
    unit_price,
    cast(unit_price * quantity as decimal(18, 2)) as amount,
    cast(base_price_usd * quantity as decimal(18, 2)) as amount_usd,
    currency,
    booking_currency,
    fulfilment_status,
    purchase_date_utc
from joined
