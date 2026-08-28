with flight_operations as (

    select
        flight_key,
        status,
        seats_available,
        passengers_carried,
        load_factor
    from {{ ref('fct_flight_operations') }}

),

flights as (

    select
        flight_key,
        route_key,
        route_id
    from {{ ref('dim_flight') }}

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

joined as (

    select
        flights.route_key,
        flights.route_id,
        flight_operations.status,
        flight_operations.seats_available,
        flight_operations.passengers_carried,
        flight_operations.load_factor
    from flight_operations
    left join flights
        on flight_operations.flight_key = flights.flight_key

),

aggregated as (

    select
        route_key,
        route_id,
        count(*) as scheduled_flight_count,
        sum(case when status = 'completed' then 1 else 0 end) as completed_flight_count,
        sum(case when status = 'cancelled' then 1 else 0 end) as cancelled_flight_count,
        sum(passengers_carried) as total_passengers_carried,
        sum(seats_available) as total_seats_available,
        avg(load_factor) as average_load_factor
    from joined
    group by route_key, route_id

)

select
    aggregated.route_key,
    aggregated.route_id,
    routes.origin_ident,
    routes.origin_airport_name,
    routes.destination_ident,
    routes.destination_airport_name,
    routes.distance_km,
    aggregated.scheduled_flight_count,
    aggregated.completed_flight_count,
    aggregated.cancelled_flight_count,
    aggregated.total_passengers_carried,
    aggregated.total_seats_available,
    cast(aggregated.average_load_factor as decimal(9, 6)) as average_load_factor,
    case
        when aggregated.scheduled_flight_count > 0
            then aggregated.completed_flight_count / aggregated.scheduled_flight_count
    end as completion_rate
from aggregated
left join routes
    on aggregated.route_key = routes.route_key
