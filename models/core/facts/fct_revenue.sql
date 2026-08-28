-- Grain is one row per recognised revenue event (charge_component_key-style natural key:
-- event_type + source_event_id), a UNION ALL of the four Milestone 17 intermediate models:
-- int_ticket_revenue_recognition ('ticket_revenue'), int_ancillary_revenue_recognition
-- ('ancillary_revenue'), int_refund_revenue_reversal ('refund_reversal'), and
-- int_revenue_adjustments ('revenue_adjustment'). Every ticket and every ancillary sale produces
-- a row here regardless of whether it was actually recognised (gross_recognised_amount may be 0)
-- -- this fact documents the recognition DECISION for every eligible event, not only positive
-- outcomes, so "why wasn't this recognised" remains directly observable rather than a silent
-- absence.
--
-- Sign convention: gross_recognised_amount is always >= 0 (a positive new recognition, 0 when
-- ineligible/unfulfilled -- never negative). reversal_or_adjustment_amount is <= 0 for
-- 'refund_reversal' rows (a reversal always reduces recognised revenue) and carries the adjustment's
-- own native sign for 'revenue_adjustment' rows (credit = negative, debit = positive -- see
-- docs/data_models/airline_refunds_adjustments.md and int_revenue_adjustments' own comment).
-- net_recognised_amount = gross_recognised_amount + reversal_or_adjustment_amount is therefore the
-- single signed net effect on recognised revenue for that row, directly summable across the whole
-- fact without needing to know which event type produced it.
--
-- route_key/origin_airport_key are populated only for 'ticket_revenue' rows, via the booking's
-- outbound route (dim_route), matching Milestone 13's own established convention for ticket-scoped
-- pricing rows -- no single flight_key exists for a ticket (a round trip touches two flight
-- instances), so none is fabricated here either. passenger_key/ticket_id are populated for
-- 'ticket_revenue' and 'ancillary_revenue' rows only; 'refund_reversal' and 'revenue_adjustment'
-- rows are booking-scoped, not tied to one ticket or passenger, matching how fct_refunds/
-- fct_adjustments themselves are scoped.
--
-- No invoice_id, payment_id, outstanding-balance, or billing-exception field exists on this fact.
-- Payment collection is never a recognition trigger -- see the upstream intermediate models.
with ticket_revenue_rows as (

    select
        'ticket_revenue' as event_type,
        ticket_id as source_event_id,
        booking_id,
        ticket_id,
        passenger_id,
        route_id,
        currency,
        cast(recognition_date as timestamp_ntz) as event_date,
        recognised_amount as gross_recognised_amount,
        cast(0 as decimal(18, 2)) as reversal_or_adjustment_amount
    from {{ ref('int_ticket_revenue_recognition') }}

),

ancillary_revenue_rows as (

    select
        'ancillary_revenue' as event_type,
        ancillary_service_id as source_event_id,
        booking_id,
        ticket_id,
        passenger_id,
        cast(null as varchar) as route_id,
        currency,
        cast(purchase_date_utc as timestamp_ntz) as event_date,
        recognised_amount as gross_recognised_amount,
        cast(0 as decimal(18, 2)) as reversal_or_adjustment_amount
    from {{ ref('int_ancillary_revenue_recognition') }}

),

refund_reversal_rows as (

    select
        'refund_reversal' as event_type,
        refund_id as source_event_id,
        booking_id,
        cast(null as varchar) as ticket_id,
        cast(null as varchar) as passenger_id,
        cast(null as varchar) as route_id,
        currency,
        cast(refund_datetime_utc as timestamp_ntz) as event_date,
        cast(0 as decimal(18, 2)) as gross_recognised_amount,
        -1 * reversal_amount as reversal_or_adjustment_amount
    from {{ ref('int_refund_revenue_reversal') }}

),

revenue_adjustment_rows as (

    select
        'revenue_adjustment' as event_type,
        adjustment_id as source_event_id,
        booking_id,
        cast(null as varchar) as ticket_id,
        cast(null as varchar) as passenger_id,
        cast(null as varchar) as route_id,
        currency,
        cast(created_at_utc as timestamp_ntz) as event_date,
        cast(0 as decimal(18, 2)) as gross_recognised_amount,
        recognised_adjustment_amount as reversal_or_adjustment_amount
    from {{ ref('int_revenue_adjustments') }}

),

unioned as (

    select * from ticket_revenue_rows
    union all
    select * from ancillary_revenue_rows
    union all
    select * from refund_reversal_rows
    union all
    select * from revenue_adjustment_rows

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

routes as (

    select
        route_key,
        route_id,
        origin_airport_key
    from {{ ref('dim_route') }}

),

currencies as (

    select
        currency_key,
        currency_code
    from {{ ref('dim_currency') }}

),

joined as (

    select
        unioned.event_type,
        unioned.source_event_id,
        bookings.booking_key,
        unioned.booking_id,
        unioned.ticket_id,
        passengers.passenger_key,
        unioned.passenger_id,
        routes.route_key,
        unioned.route_id,
        routes.origin_airport_key,
        currencies.currency_key,
        unioned.currency,
        unioned.event_date,
        unioned.gross_recognised_amount,
        unioned.reversal_or_adjustment_amount
    from unioned
    left join bookings
        on unioned.booking_id = bookings.booking_id
    left join passengers
        on unioned.passenger_id = passengers.passenger_id
    left join routes
        on unioned.route_id = routes.route_id
    left join currencies
        on unioned.currency = currencies.currency_code

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['event_type', 'source_event_id']) }} as revenue_event_key,
        event_type,
        source_event_id,
        booking_key,
        booking_id,
        ticket_id,
        passenger_key,
        passenger_id,
        route_key,
        route_id,
        origin_airport_key,
        currency_key,
        currency,
        event_date,
        gross_recognised_amount,
        reversal_or_adjustment_amount,
        cast(
            gross_recognised_amount + reversal_or_adjustment_amount as decimal(18, 2)
        ) as net_recognised_amount
    from joined

)

select
    revenue_event_key,
    event_type,
    source_event_id,
    booking_key,
    booking_id,
    ticket_id,
    passenger_key,
    passenger_id,
    route_key,
    route_id,
    origin_airport_key,
    currency_key,
    currency,
    event_date,
    gross_recognised_amount,
    reversal_or_adjustment_amount,
    net_recognised_amount
from final
