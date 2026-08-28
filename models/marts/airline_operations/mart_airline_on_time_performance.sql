-- NOTE: this reports COMPLETION performance, not timeliness/delay performance. The Milestone 9
-- source has no actual/observed departure or arrival timestamp anywhere -- only scheduled times
-- and a final status -- so no on-time/delay measure can be honestly computed. This mart is named
-- to match the milestone's own suggested consumption contract, but every measure it exposes is a
-- completion-rate measure; see _airline_operations.yml for the explicit limitation.
with flight_operations as (

    select
        flight_key,
        status
    from {{ ref('fct_flight_operations') }}

),

flights as (

    select
        flight_key,
        airline_key,
        airline_code
    from {{ ref('dim_flight') }}

),

joined as (

    select
        flights.airline_key,
        flights.airline_code,
        flight_operations.status
    from flight_operations
    left join flights
        on flight_operations.flight_key = flights.flight_key

),

aggregated as (

    select
        airline_key,
        airline_code,
        count(*) as scheduled_flight_count,
        sum(case when status = 'completed' then 1 else 0 end) as completed_flight_count,
        sum(case when status = 'cancelled' then 1 else 0 end) as cancelled_flight_count
    from joined
    group by airline_key, airline_code

)

select
    airline_key,
    airline_code,
    scheduled_flight_count,
    completed_flight_count,
    cancelled_flight_count,
    case when scheduled_flight_count > 0 then completed_flight_count / scheduled_flight_count end
        as completion_rate,
    case when scheduled_flight_count > 0 then cancelled_flight_count / scheduled_flight_count end
        as cancellation_rate
from aggregated
