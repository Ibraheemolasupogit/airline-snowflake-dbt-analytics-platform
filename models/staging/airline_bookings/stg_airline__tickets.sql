with source as (

    select *
    from {{ source('airline_bookings', 'tickets') }}

),

renamed as (

    select
        nullif(trim(cast(ticket_id as varchar)), '') as ticket_id,
        nullif(trim(cast(ticket_number as varchar)), '') as ticket_number,
        nullif(trim(cast(booking_id as varchar)), '') as booking_id,
        nullif(trim(cast(passenger_id as varchar)), '') as passenger_id,
        nullif(trim(cast(fare_class_code as varchar)), '') as fare_class_code,
        try_to_timestamp_ntz(nullif(trim(cast(issue_date_utc as varchar)), '')) as issue_date_utc,
        nullif(trim(cast(ticket_status as varchar)), '') as ticket_status
    from source

)

select
    ticket_id,
    ticket_number,
    booking_id,
    passenger_id,
    fare_class_code,
    issue_date_utc,
    ticket_status
from renamed
