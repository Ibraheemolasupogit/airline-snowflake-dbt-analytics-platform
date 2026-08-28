-- Aircraft-type assignment consistency, aggregated to the flight-schedule grain. Grain is one
-- row per flight schedule.
--
-- The Milestone 9 generator prefers an aircraft matching the schedule's assigned
-- aircraft_type_code but falls back to any aircraft in the airline's fleet when no exact-type
-- match is available, so the aircraft that actually operates a given schedule's instances can
-- genuinely differ from the type the schedule was planned around. That is the only aircraft/
-- route compatibility signal the source data defensibly supports: there is no distinct
-- "scheduled capacity" field to compare against aircraft seat capacity, and no documented
-- aircraft range attribute to compare against route distance, so those checks are not
-- implemented here. This does not imply certified runway compatibility, regulatory approval,
-- airport operating approval, or dispatch suitability.
with operated_segments as (

    select
        schedule_id,
        route_id,
        airline_code,
        scheduled_aircraft_type_code,
        is_assigned_aircraft_type_consistent
    from {{ ref('int_operated_flight_segments') }}
    where is_assigned_aircraft_type_consistent is not null

),

aggregated as (

    select
        schedule_id,
        route_id,
        airline_code,
        scheduled_aircraft_type_code,
        count(*) as operated_instance_count,
        count_if(is_assigned_aircraft_type_consistent) as consistent_instance_count,
        count_if(not is_assigned_aircraft_type_consistent) as inconsistent_instance_count
    from operated_segments
    group by schedule_id, route_id, airline_code, scheduled_aircraft_type_code

),

final as (

    select
        schedule_id,
        route_id,
        airline_code,
        scheduled_aircraft_type_code,
        operated_instance_count,
        consistent_instance_count,
        inconsistent_instance_count,
        consistent_instance_count / nullif(operated_instance_count, 0) as consistent_ratio,
        inconsistent_instance_count = 0 as is_fully_consistent
    from aggregated

)

select
    schedule_id,
    route_id,
    airline_code,
    scheduled_aircraft_type_code,
    operated_instance_count,
    consistent_instance_count,
    inconsistent_instance_count,
    consistent_ratio,
    is_fully_consistent
from final
