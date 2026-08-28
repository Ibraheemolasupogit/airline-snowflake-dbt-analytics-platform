select
    ticket_id,
    flight_instance_id,
    count(*) as segment_count
from {{ ref('stg_airline__ticket_segments') }}
group by ticket_id, flight_instance_id
having count(*) > 1
