-- Grain is one row per airline route. Uses conformed dim_airport keys for origin and
-- destination, reusing int_route_airport_pair rather than rebuilding the AirStats join.
with routes as (

    select
        route_id,
        airline_code,
        origin_ident,
        origin_airport_name,
        destination_ident,
        destination_airport_name,
        distance_km
    from {{ ref('int_route_airport_pair') }}

),

airlines as (

    select
        airline_key,
        airline_code
    from {{ ref('dim_airline') }}

),

origin_airports as (

    select
        airport_key,
        airport_ident
    from {{ ref('dim_airport') }}

),

destination_airports as (

    select
        airport_key,
        airport_ident
    from {{ ref('dim_airport') }}

),

joined as (

    select
        routes.route_id,
        routes.airline_code,
        airlines.airline_key,
        routes.origin_ident,
        origin_airports.airport_key as origin_airport_key,
        routes.origin_airport_name,
        routes.destination_ident,
        destination_airports.airport_key as destination_airport_key,
        routes.destination_airport_name,
        routes.distance_km
    from routes
    left join airlines
        on routes.airline_code = airlines.airline_code
    left join origin_airports
        on routes.origin_ident = origin_airports.airport_ident
    left join destination_airports
        on routes.destination_ident = destination_airports.airport_ident

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['route_id']) }} as route_key,
        route_id,
        airline_key,
        airline_code,
        origin_airport_key,
        origin_ident,
        origin_airport_name,
        destination_airport_key,
        destination_ident,
        destination_airport_name,
        distance_km
    from joined

)

select
    route_key,
    route_id,
    airline_key,
    airline_code,
    origin_airport_key,
    origin_ident,
    origin_airport_name,
    destination_airport_key,
    destination_ident,
    destination_airport_name,
    distance_km
from final
