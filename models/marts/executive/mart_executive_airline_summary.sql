-- Grain is one row (company-wide, no dimension). A deliberately narrow executive consumption
-- contract: reuses mart_daily_flight_operations (already-aggregated flight counts) rather than
-- re-aggregating fct_flight_operations. No currency-denominated measure appears on this mart, so
-- no cross-currency aggregation risk exists here.
with daily_operations as (

    select
        scheduled_flight_count,
        completed_flight_count,
        cancelled_flight_count,
        total_passengers_carried,
        total_seats_available
    from {{ ref('mart_daily_flight_operations') }}

),

aggregated as (

    select
        sum(scheduled_flight_count) as total_scheduled_flights,
        sum(completed_flight_count) as total_completed_flights,
        sum(cancelled_flight_count) as total_cancelled_flights,
        sum(total_passengers_carried) as total_passengers_carried,
        sum(total_seats_available) as total_seats_available
    from daily_operations

)

select
    total_scheduled_flights,
    total_completed_flights,
    total_cancelled_flights,
    total_passengers_carried,
    case
        when total_scheduled_flights > 0
            then cast(total_completed_flights / total_scheduled_flights as decimal(9, 6))
    end as completion_rate,
    case
        when total_seats_available > 0
            then cast(total_passengers_carried / total_seats_available as decimal(9, 6))
    end as average_load_factor
from aggregated
