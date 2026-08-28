with flight_operations as (

    select
        flight_date,
        status,
        seats_available,
        passengers_carried,
        load_factor
    from {{ ref('fct_flight_operations') }}

),

aggregated as (

    select
        flight_date,
        count(*) as scheduled_flight_count,
        sum(case when status = 'completed' then 1 else 0 end) as completed_flight_count,
        sum(case when status = 'cancelled' then 1 else 0 end) as cancelled_flight_count,
        sum(case when status = 'scheduled' then 1 else 0 end) as still_scheduled_flight_count,
        sum(passengers_carried) as total_passengers_carried,
        sum(seats_available) as total_seats_available,
        avg(load_factor) as average_load_factor
    from flight_operations
    group by flight_date

)

select
    flight_date,
    scheduled_flight_count,
    completed_flight_count,
    cancelled_flight_count,
    still_scheduled_flight_count,
    total_passengers_carried,
    total_seats_available,
    cast(average_load_factor as decimal(9, 6)) as average_load_factor,
    case when scheduled_flight_count > 0 then completed_flight_count / scheduled_flight_count end
        as completion_rate
from aggregated
