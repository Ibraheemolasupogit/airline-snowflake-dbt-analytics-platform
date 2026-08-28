-- Grain is one row per reconciliation control. Primary key is control_id. Upstream models are
-- seed_synthetic_control_totals (source side, mechanically derived from data/synthetic/
-- control_totals.json by scripts/generate_reconciliation_evidence.py -- never hand-typed) and
-- fct_bookings/fct_ticket_segments/fct_flight_operations (warehouse side, reused unchanged --
-- no booking, ticketing, or flight-operations logic is recomputed here).
--
-- ticket_count uses count(distinct ticket_id) from fct_ticket_segments (segment grain), not a
-- ticket-grain model, so this control genuinely cross-checks segment-to-ticket coverage rather
-- than trivially re-reading a value already at ticket grain.
--
-- flight_instance_*_count controls compare against fct_flight_operations.status (the raw,
-- unmodified status column), not operational_completion_status (Milestone 11's derived recode) --
-- the source-side control_totals.json counts the raw generated status field exactly, so an exact
-- semantic match requires the same raw column on the warehouse side.
--
-- control_status = 'pass' when variance_count = 0, else 'fail' -- exact equality, no tolerance:
-- every control here compares an unmodified passthrough/count against its own source definition,
-- so any nonzero variance would indicate a genuine modelling defect, not a legitimate business
-- anomaly (see docs/data_models/airline_reconciliation_controls.md).
with source_controls as (

    select
        metric_name,
        cast(metric_value as decimal(38, 6)) as metric_value,
        as_of_date
    from {{ ref('seed_synthetic_control_totals') }}

),

warehouse_bookings as (

    select
        count(*) as booking_count,
        sum(case when not is_cancelled then 1 else 0 end) as booking_confirmed_count,
        sum(case when is_cancelled then 1 else 0 end) as booking_cancelled_count
    from {{ ref('fct_bookings') }}

),

warehouse_tickets as (

    select count(distinct ticket_id) as ticket_count
    from {{ ref('fct_ticket_segments') }}

),

warehouse_flight_operations as (

    select
        count(*) as flight_instance_count,
        sum(case when status = 'completed' then 1 else 0 end) as flight_instance_completed_count,
        sum(case when status = 'cancelled' then 1 else 0 end) as flight_instance_cancelled_count,
        sum(case when status = 'scheduled' then 1 else 0 end) as flight_instance_scheduled_count
    from {{ ref('fct_flight_operations') }}

),

controls as (

    select
        'booking.booking_count' as control_id,
        'booking' as control_domain,
        'booking_count' as control_name,
        source_controls.metric_value as source_measure,
        warehouse_bookings.booking_count as warehouse_measure,
        warehouse_bookings.booking_count - source_controls.metric_value as variance_count,
        source_controls.as_of_date,
        'fct_bookings row count (1:1 with bookings.csv).' as notes
    from source_controls
    cross join warehouse_bookings
    where source_controls.metric_name = 'booking_count'

    union all

    select
        'booking.booking_confirmed_count' as control_id,
        'booking' as control_domain,
        'booking_confirmed_count' as control_name,
        source_controls.metric_value as source_measure,
        warehouse_bookings.booking_confirmed_count as warehouse_measure,
        warehouse_bookings.booking_confirmed_count - source_controls.metric_value as variance_count,
        source_controls.as_of_date,
        'count(*) from fct_bookings where not is_cancelled.' as notes
    from source_controls
    cross join warehouse_bookings
    where source_controls.metric_name = 'booking_confirmed_count'

    union all

    select
        'booking.booking_cancelled_count' as control_id,
        'booking' as control_domain,
        'booking_cancelled_count' as control_name,
        source_controls.metric_value as source_measure,
        warehouse_bookings.booking_cancelled_count as warehouse_measure,
        warehouse_bookings.booking_cancelled_count - source_controls.metric_value as variance_count,
        source_controls.as_of_date,
        'count(*) from fct_bookings where is_cancelled.' as notes
    from source_controls
    cross join warehouse_bookings
    where source_controls.metric_name = 'booking_cancelled_count'

    union all

    select
        'ticket.ticket_count' as control_id,
        'ticket' as control_domain,
        'ticket_count' as control_name,
        source_controls.metric_value as source_measure,
        warehouse_tickets.ticket_count as warehouse_measure,
        warehouse_tickets.ticket_count - source_controls.metric_value as variance_count,
        source_controls.as_of_date,
        'count(distinct ticket_id) from fct_ticket_segments.' as notes
    from source_controls
    cross join warehouse_tickets
    where source_controls.metric_name = 'ticket_count'

    union all

    select
        'flight_operations.flight_instance_count' as control_id,
        'flight_operations' as control_domain,
        'flight_instance_count' as control_name,
        source_controls.metric_value as source_measure,
        warehouse_flight_operations.flight_instance_count as warehouse_measure,
        warehouse_flight_operations.flight_instance_count - source_controls.metric_value
            as variance_count,
        source_controls.as_of_date,
        'fct_flight_operations row count (1:1 with flight_instances.csv).' as notes
    from source_controls
    cross join warehouse_flight_operations
    where source_controls.metric_name = 'flight_instance_count'

    union all

    select
        'flight_operations.flight_instance_completed_count' as control_id,
        'flight_operations' as control_domain,
        'flight_instance_completed_count' as control_name,
        source_controls.metric_value as source_measure,
        warehouse_flight_operations.flight_instance_completed_count as warehouse_measure,
        warehouse_flight_operations.flight_instance_completed_count - source_controls.metric_value
            as variance_count,
        source_controls.as_of_date,
        'count(*) from fct_flight_operations where status = ''completed'' (raw status).' as notes
    from source_controls
    cross join warehouse_flight_operations
    where source_controls.metric_name = 'flight_instance_completed_count'

    union all

    select
        'flight_operations.flight_instance_cancelled_count' as control_id,
        'flight_operations' as control_domain,
        'flight_instance_cancelled_count' as control_name,
        source_controls.metric_value as source_measure,
        warehouse_flight_operations.flight_instance_cancelled_count as warehouse_measure,
        warehouse_flight_operations.flight_instance_cancelled_count - source_controls.metric_value
            as variance_count,
        source_controls.as_of_date,
        'count(*) from fct_flight_operations where status = ''cancelled''.' as notes
    from source_controls
    cross join warehouse_flight_operations
    where source_controls.metric_name = 'flight_instance_cancelled_count'

    union all

    select
        'flight_operations.flight_instance_scheduled_count' as control_id,
        'flight_operations' as control_domain,
        'flight_instance_scheduled_count' as control_name,
        source_controls.metric_value as source_measure,
        warehouse_flight_operations.flight_instance_scheduled_count as warehouse_measure,
        warehouse_flight_operations.flight_instance_scheduled_count - source_controls.metric_value
            as variance_count,
        source_controls.as_of_date,
        'count(*) from fct_flight_operations where status = ''scheduled''.' as notes
    from source_controls
    cross join warehouse_flight_operations
    where source_controls.metric_name = 'flight_instance_scheduled_count'

)

select
    control_id,
    control_domain,
    control_name,
    source_measure,
    warehouse_measure,
    cast(null as decimal(18, 2)) as variance_amount,
    cast(variance_count as number(38, 0)) as variance_count,
    cast(0 as decimal(18, 2)) as materiality_threshold,
    as_of_date,
    notes,
    case when variance_count = 0 then 'pass' else 'fail' end as control_status
from controls
