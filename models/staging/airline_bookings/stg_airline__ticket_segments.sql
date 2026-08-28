with source as (

    select *
    from {{ source('airline_bookings', 'ticket_segments') }}

),

renamed as (

    select
        nullif(trim(cast(ticket_segment_id as varchar)), '') as ticket_segment_id,
        nullif(trim(cast(ticket_id as varchar)), '') as ticket_id,
        try_to_number(nullif(trim(cast(segment_sequence as varchar)), ''), 38, 0) as segment_sequence,
        nullif(trim(cast(flight_instance_id as varchar)), '') as flight_instance_id,
        nullif(trim(cast(cabin as varchar)), '') as cabin,
        nullif(trim(cast(fare_basis_code as varchar)), '') as fare_basis_code,
        nullif(trim(cast(segment_status as varchar)), '') as segment_status
    from source

)

select
    ticket_segment_id,
    ticket_id,
    segment_sequence,
    flight_instance_id,
    cabin,
    fare_basis_code,
    segment_status
from renamed
