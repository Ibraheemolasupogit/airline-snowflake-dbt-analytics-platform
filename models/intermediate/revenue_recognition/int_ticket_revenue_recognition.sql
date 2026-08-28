-- Grain is one row per ticket (ticket_id), matching Milestone 13's own ticket-scoped fare-pricing
-- grain (int_fare_component_calculation, fct_pricing_events) -- not ticket_segment_id. Milestone 13
-- established that no per-segment fare-apportionment rule exists anywhere in the Milestone 9
-- specification (a ticket's fare is priced once, using the booking's outbound route distance,
-- regardless of one-way vs round-trip); this model does not invent one either.
--
-- Recognition rule (approach 1 from this milestone's own scope): a ticket's fare is recognised
-- only when EVERY one of its ticket segments is fulfilled (int_fulfilled_flight_services.
-- fulfilment_indicator = true for all of them). A round-trip ticket with one flown leg and one
-- still-scheduled or cancelled leg is NOT eligible -- recognising half a round-trip fare would
-- require inventing a pro-rata split the source does not define, which this milestone's scope
-- boundary explicitly forbids.
--
-- priced_fare_amount is reused, not recomputed, from fct_pricing_events: sum(amount) where
-- component_type in ('base_fare', 'distance_fare') for this ticket_id -- the same combined base +
-- distance figure Milestone 14 already established as comparable to the source's single
-- 'base_fare' invoice line. booking_status = confirmed / ticket issued / invoice issued / payment
-- collected are deliberately NOT used as recognition triggers, per this milestone's policy.
--
-- recognition_date = max(flight_date) across the ticket's own ticket_segments -- the date the
-- LAST fulfilled leg actually flew, i.e. the date the whole itinerary became earned. It is null
-- whenever is_recognition_eligible is false, since nothing has been earned yet to date. No
-- "actual" flight timestamp exists in the source (only scheduled times and flight_date), so no
-- more precise date is fabricated.
with fulfilled_segments as (

    select
        ticket_id,
        booking_id,
        passenger_id,
        fulfilment_indicator
    from {{ ref('int_fulfilled_flight_services') }}

),

segment_flight_dates as (

    select
        ticket_segment_id,
        ticket_id,
        flight_date
    from {{ ref('int_ticketed_segments') }}

),

segment_aggregates as (

    select
        ticket_id,
        max(booking_id) as booking_id,
        max(passenger_id) as passenger_id,
        count(*) as total_segments,
        sum(case when fulfilment_indicator then 1 else 0 end) as fulfilled_segments
    from fulfilled_segments
    group by ticket_id

),

max_flight_date as (

    select
        ticket_id,
        max(flight_date) as max_flight_date
    from segment_flight_dates
    group by ticket_id

),

pricing as (

    select
        ticket_id,
        currency,
        max(route_id) as route_id,
        sum(amount) as priced_fare_amount
    from {{ ref('fct_pricing_events') }}
    where component_type in ('base_fare', 'distance_fare')
    group by ticket_id, currency

),

joined as (

    select
        segment_aggregates.ticket_id,
        segment_aggregates.booking_id,
        segment_aggregates.passenger_id,
        pricing.currency,
        pricing.route_id,
        pricing.priced_fare_amount,
        segment_aggregates.total_segments,
        segment_aggregates.fulfilled_segments,
        max_flight_date.max_flight_date,
        segment_aggregates.total_segments > 0
        and segment_aggregates.fulfilled_segments = segment_aggregates.total_segments
            as is_recognition_eligible
    from segment_aggregates
    left join pricing
        on segment_aggregates.ticket_id = pricing.ticket_id
    left join max_flight_date
        on segment_aggregates.ticket_id = max_flight_date.ticket_id

),

final as (

    select
        ticket_id,
        booking_id,
        passenger_id,
        currency,
        route_id,
        priced_fare_amount,
        total_segments,
        fulfilled_segments,
        is_recognition_eligible,
        case when is_recognition_eligible then priced_fare_amount else 0 end as recognised_amount,
        case when is_recognition_eligible then max_flight_date end as recognition_date
    from joined

)

select
    ticket_id,
    booking_id,
    passenger_id,
    currency,
    route_id,
    priced_fare_amount,
    total_segments,
    fulfilled_segments,
    is_recognition_eligible,
    cast(recognised_amount as decimal(18, 2)) as recognised_amount,
    recognition_date
from final
