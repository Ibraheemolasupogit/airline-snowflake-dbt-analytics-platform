-- Conforms airline route origin/destination airport identifiers to the AirStats airport
-- reference layer. This is the first genuine join between the airline domain and AirStats;
-- it reuses AirStats' own intermediate geography model rather than re-deriving airport
-- attributes, and does not touch the synthetic reference/airports.csv fixture.
with routes as (

    select
        route_id,
        airline_code,
        origin_ident,
        destination_ident,
        distance_km
    from {{ ref('stg_airline__routes') }}

),

origin_airport as (

    select
        ident,
        airport_name,
        country_code,
        country_name,
        region_code,
        region_name
    from {{ ref('int_airport_geography') }}

),

destination_airport as (

    select
        ident,
        airport_name,
        country_code,
        country_name,
        region_code,
        region_name
    from {{ ref('int_airport_geography') }}

),

joined as (

    select
        routes.route_id,
        routes.airline_code,
        routes.origin_ident,
        origin_airport.airport_name as origin_airport_name,
        origin_airport.country_code as origin_country_code,
        origin_airport.country_name as origin_country_name,
        origin_airport.region_code as origin_region_code,
        origin_airport.region_name as origin_region_name,
        routes.destination_ident,
        destination_airport.airport_name as destination_airport_name,
        destination_airport.country_code as destination_country_code,
        destination_airport.country_name as destination_country_name,
        destination_airport.region_code as destination_region_code,
        destination_airport.region_name as destination_region_name,
        routes.distance_km
    from routes
    left join origin_airport
        on routes.origin_ident = origin_airport.ident
    left join destination_airport
        on routes.destination_ident = destination_airport.ident

)

select
    route_id,
    airline_code,
    origin_ident,
    origin_airport_name,
    origin_country_code,
    origin_country_name,
    origin_region_code,
    origin_region_name,
    destination_ident,
    destination_airport_name,
    destination_country_code,
    destination_country_name,
    destination_region_code,
    destination_region_name,
    distance_km
from joined
