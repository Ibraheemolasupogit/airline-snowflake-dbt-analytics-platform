with passenger_journeys as (

    select journey_completion_status
    from {{ ref('fct_passenger_journeys') }}

),

aggregated as (

    select
        journey_completion_status,
        count(*) as journey_leg_count
    from passenger_journeys
    group by journey_completion_status

),

total as (

    select sum(journey_leg_count) as total_journey_leg_count
    from aggregated

)

select
    aggregated.journey_completion_status,
    aggregated.journey_leg_count,
    case
        when total.total_journey_leg_count > 0
            then aggregated.journey_leg_count / total.total_journey_leg_count
    end as share_of_journey_legs
from aggregated
cross join total
