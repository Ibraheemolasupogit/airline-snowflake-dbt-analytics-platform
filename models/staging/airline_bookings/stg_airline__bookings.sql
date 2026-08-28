with source as (

    select *
    from {{ source('airline_bookings', 'bookings') }}

),

renamed as (

    select
        nullif(trim(cast(booking_id as varchar)), '') as booking_id,
        nullif(trim(cast(booking_reference as varchar)), '') as booking_reference,
        nullif(trim(cast(airline_code as varchar)), '') as airline_code,
        nullif(trim(cast(route_id as varchar)), '') as route_id,
        nullif(trim(cast(return_route_id as varchar)), '') as return_route_id,
        nullif(trim(cast(trip_type as varchar)), '') as trip_type,
        nullif(trim(cast(booking_channel as varchar)), '') as booking_channel,
        try_to_timestamp_ntz(nullif(trim(cast(booking_date_utc as varchar)), '')) as booking_date_utc,
        nullif(trim(cast(point_of_sale_country as varchar)), '') as point_of_sale_country,
        nullif(trim(cast(currency as varchar)), '') as currency,
        nullif(trim(cast(status as varchar)), '') as status,
        nullif(trim(cast(corporate_account_id as varchar)), '') as corporate_account_id,
        nullif(trim(cast(travel_agent_id as varchar)), '') as travel_agent_id,
        nullif(trim(cast(discount_code as varchar)), '') as discount_code,
        nullif(trim(cast(outbound_flight_instance_id as varchar)), '') as outbound_flight_instance_id,
        nullif(trim(cast(return_flight_instance_id as varchar)), '') as return_flight_instance_id
    from source

)

select
    booking_id,
    booking_reference,
    airline_code,
    route_id,
    return_route_id,
    trip_type,
    booking_channel,
    booking_date_utc,
    point_of_sale_country,
    currency,
    status,
    corporate_account_id,
    travel_agent_id,
    discount_code,
    outbound_flight_instance_id,
    return_flight_instance_id
from renamed
