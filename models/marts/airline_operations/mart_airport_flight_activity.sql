-- Grain is one row per (airport, attribution) -- attribution is either 'origin' or 'destination',
-- as two separate rows per airport, never summed together into one "total" row. This avoids
-- accidentally double-counting a flight (which has exactly one origin and one destination) as a
-- single airport's activity.
with flight_operations as (

    select
        origin_airport_key,
        destination_airport_key,
        status,
        passengers_carried,
        seats_available
    from {{ ref('fct_flight_operations') }}

),

airports as (

    select
        airport_key,
        airport_ident,
        airport_name,
        country_code
    from {{ ref('dim_airport') }}

),

origin_activity as (

    select
        origin_airport_key as airport_key,
        'origin' as attribution,
        count(*) as scheduled_flight_count,
        sum(case when status = 'completed' then 1 else 0 end) as completed_flight_count,
        sum(case when status = 'cancelled' then 1 else 0 end) as cancelled_flight_count,
        sum(passengers_carried) as total_passengers_carried,
        sum(seats_available) as total_seats_available
    from flight_operations
    group by origin_airport_key

),

destination_activity as (

    select
        destination_airport_key as airport_key,
        'destination' as attribution,
        count(*) as scheduled_flight_count,
        sum(case when status = 'completed' then 1 else 0 end) as completed_flight_count,
        sum(case when status = 'cancelled' then 1 else 0 end) as cancelled_flight_count,
        sum(passengers_carried) as total_passengers_carried,
        sum(seats_available) as total_seats_available
    from flight_operations
    group by destination_airport_key

),

unioned as (

    select * from origin_activity
    union all
    select * from destination_activity

)

select
    unioned.airport_key,
    airports.airport_ident,
    airports.airport_name,
    airports.country_code,
    unioned.attribution,
    unioned.scheduled_flight_count,
    unioned.completed_flight_count,
    unioned.cancelled_flight_count,
    unioned.total_passengers_carried,
    unioned.total_seats_available
from unioned
left join airports
    on unioned.airport_key = airports.airport_key
