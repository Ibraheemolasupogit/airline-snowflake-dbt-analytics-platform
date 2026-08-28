-- Grain is one row per (route, currency). Reuses fct_revenue directly for recognised revenue; no
-- pricing or recognition logic is recomputed. Ancillary revenue (fct_revenue.route_id is null for
-- ancillary_revenue events by design -- ancillary sales are not tied to a specific flight) is
-- attributed to the same route used for that ticket's fare recognition
-- (int_ticket_revenue_recognition.route_id, Milestone 13/17's own "booking outbound route"
-- convention, reused unchanged, not re-derived).
with ticket_route as (

    select
        ticket_id,
        route_id
    from {{ ref('int_ticket_revenue_recognition') }}

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
        revenue_events.event_type,
        revenue_events.gross_recognised_amount,
        coalesce(revenue_events.route_id, ticket_route.route_id) as route_id
    from revenue_events
    left join ticket_route
        on revenue_events.ticket_id = ticket_route.ticket_id

),

revenue_by_route as (

    select
        route_id,
        currency,
        sum(case when event_type = 'ticket_revenue' then gross_recognised_amount else 0 end)
            as recognised_ticket_revenue,
        sum(case when event_type = 'ancillary_revenue' then gross_recognised_amount else 0 end)
            as recognised_ancillary_revenue,
        sum(gross_recognised_amount) as total_recognised_revenue
    from attributed_revenue
    group by route_id, currency

),

routes as (

    select
        route_key,
        route_id,
        origin_ident,
        origin_airport_name,
        destination_ident,
        destination_airport_name,
        distance_km
    from {{ ref('dim_route') }}

),

flight_operations as (

    select
        flight_key,
        passengers_carried,
        seats_available,
        status
    from {{ ref('fct_flight_operations') }}

),

flights as (

    select
        flight_key,
        route_id
    from {{ ref('dim_flight') }}

),

route_operations as (

    select
        flights.route_id,
        count(*) as flight_count,
        sum(flight_operations.passengers_carried) as total_passengers_carried,
        sum(flight_operations.seats_available) as total_seats_available
    from flight_operations
    left join flights
        on flight_operations.flight_key = flights.flight_key
    group by flights.route_id

)

select
    routes.route_key,
    revenue_by_route.route_id,
    routes.origin_ident,
    routes.origin_airport_name,
    routes.destination_ident,
    routes.destination_airport_name,
    routes.distance_km,
    revenue_by_route.currency,
    cast(revenue_by_route.recognised_ticket_revenue as decimal(18, 2)) as recognised_ticket_revenue,
    cast(revenue_by_route.recognised_ancillary_revenue as decimal(18, 2)) as recognised_ancillary_revenue,
    cast(revenue_by_route.total_recognised_revenue as decimal(18, 2)) as total_recognised_revenue,
    coalesce(route_operations.flight_count, 0) as flight_count,
    coalesce(route_operations.total_passengers_carried, 0) as total_passengers_carried,
    case
        when route_operations.total_passengers_carried > 0
            then cast(
                revenue_by_route.total_recognised_revenue / route_operations.total_passengers_carried
                as decimal(18, 2)
            )
    end as revenue_per_passenger,
    case
        when route_operations.flight_count > 0
            then cast(revenue_by_route.total_recognised_revenue / route_operations.flight_count as decimal(18, 2))
    end as revenue_per_flight,
    case
        when route_operations.total_seats_available > 0
            then cast(
                route_operations.total_passengers_carried / route_operations.total_seats_available
                as decimal(9, 6)
            )
    end as load_factor
from revenue_by_route
left join routes
    on revenue_by_route.route_id = routes.route_id
left join route_operations
    on revenue_by_route.route_id = route_operations.route_id
