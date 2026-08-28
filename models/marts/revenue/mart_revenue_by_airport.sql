-- Grain is one row per (airport, attribution, currency) -- attribution is either 'origin' or
-- 'destination', as two separate rows, never summed into one "total" row per airport. This avoids
-- double-counting: a single ticket's revenue is attributed once as origin activity and once as
-- destination activity, by design, not added together.
--
-- Ancillary revenue (fct_revenue.route_id/origin_airport_key are null for ancillary_revenue
-- events) is attributed via the same ticket's route (int_ticket_revenue_recognition.route_id,
-- Milestone 13/17's own convention, reused unchanged).
with ticket_route as (

    select
        ticket_id,
        route_id
    from {{ ref('int_ticket_revenue_recognition') }}

),

routes as (

    select
        route_id,
        origin_airport_key,
        destination_airport_key
    from {{ ref('dim_route') }}

),

revenue_events as (

    select
        event_type,
        ticket_id,
        route_id,
        currency,
        gross_recognised_amount
    from {{ ref('fct_revenue') }}
    where event_type in ('ticket_revenue', 'ancillary_revenue')

),

attributed_revenue as (

    select
        revenue_events.currency,
        revenue_events.gross_recognised_amount,
        coalesce(revenue_events.route_id, ticket_route.route_id) as route_id
    from revenue_events
    left join ticket_route
        on revenue_events.ticket_id = ticket_route.ticket_id

),

joined_routes as (

    select
        attributed_revenue.currency,
        attributed_revenue.gross_recognised_amount,
        routes.origin_airport_key,
        routes.destination_airport_key
    from attributed_revenue
    left join routes
        on attributed_revenue.route_id = routes.route_id

),

origin_revenue as (

    select
        origin_airport_key as airport_key,
        'origin' as attribution,
        currency,
        sum(gross_recognised_amount) as total_recognised_revenue
    from joined_routes
    group by origin_airport_key, currency

),

destination_revenue as (

    select
        destination_airport_key as airport_key,
        'destination' as attribution,
        currency,
        sum(gross_recognised_amount) as total_recognised_revenue
    from joined_routes
    group by destination_airport_key, currency

),

unioned as (

    select * from origin_revenue
    union all
    select * from destination_revenue

),

airports as (

    select
        airport_key,
        airport_ident,
        airport_name,
        country_code
    from {{ ref('dim_airport') }}

)

select
    unioned.airport_key,
    airports.airport_ident,
    airports.airport_name,
    airports.country_code,
    unioned.attribution,
    unioned.currency,
    cast(unioned.total_recognised_revenue as decimal(18, 2)) as total_recognised_revenue
from unioned
left join airports
    on unioned.airport_key = airports.airport_key
