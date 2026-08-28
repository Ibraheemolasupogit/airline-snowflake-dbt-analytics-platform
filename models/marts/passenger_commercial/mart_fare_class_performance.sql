with ticket_segments as (

    select
        fare_class_key,
        fare_class_code,
        segment_status
    from {{ ref('fct_ticket_segments') }}

),

aggregated as (

    select
        fare_class_key,
        fare_class_code,
        count(*) as ticket_segment_count,
        sum(case when segment_status = 'flown' then 1 else 0 end) as flown_segment_count,
        sum(case when segment_status = 'cancelled' then 1 else 0 end) as cancelled_segment_count
    from ticket_segments
    group by fare_class_key, fare_class_code

)

select
    fare_class_key,
    fare_class_code,
    ticket_segment_count,
    flown_segment_count,
    cancelled_segment_count,
    case when ticket_segment_count > 0 then cancelled_segment_count / ticket_segment_count end
        as cancellation_rate
from aggregated
