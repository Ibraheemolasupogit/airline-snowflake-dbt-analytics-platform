-- Verifies the seed (mechanically derived from data/synthetic/control_totals.json) remains
-- internally consistent with the Milestone 9 generator's own arithmetic: booking_confirmed_count
-- + booking_cancelled_count should equal booking_count, and the three flight_instance_* status
-- counts should sum to flight_instance_count. A failure here would mean the seed has drifted from
-- what scripts/generate_control_totals.py actually computes, not a warehouse-side issue.
with pivoted as (

    select
        max(case when metric_name = 'booking_count' then metric_value end) as booking_count,
        max(case when metric_name = 'booking_confirmed_count' then metric_value end)
            as booking_confirmed_count,
        max(case when metric_name = 'booking_cancelled_count' then metric_value end)
            as booking_cancelled_count,
        max(case when metric_name = 'flight_instance_count' then metric_value end)
            as flight_instance_count,
        max(case when metric_name = 'flight_instance_completed_count' then metric_value end)
            as flight_instance_completed_count,
        max(case when metric_name = 'flight_instance_cancelled_count' then metric_value end)
            as flight_instance_cancelled_count,
        max(case when metric_name = 'flight_instance_scheduled_count' then metric_value end)
            as flight_instance_scheduled_count
    from {{ ref('seed_synthetic_control_totals') }}

)

select *
from pivoted
where
    booking_confirmed_count + booking_cancelled_count != booking_count
    or flight_instance_completed_count + flight_instance_cancelled_count + flight_instance_scheduled_count
    != flight_instance_count
