with source as (

    select *
    from {{ source('airline_reference', 'aircraft_types') }}

),

renamed as (

    select
        nullif(trim(cast(aircraft_type_code as varchar)), '') as aircraft_type_code,
        nullif(trim(cast(type_name as varchar)), '') as type_name,
        nullif(trim(cast(body_type as varchar)), '') as body_type,
        try_to_number(nullif(trim(cast(typical_seats as varchar)), ''), 38, 0) as typical_seats,
        nullif(trim(cast(cabins as varchar)), '') as cabins,
        try_to_number(nullif(trim(cast(cruise_speed_kmh as varchar)), ''), 38, 0) as cruise_speed_kmh
    from source

)

select
    aircraft_type_code,
    type_name,
    body_type,
    typical_seats,
    cabins,
    cruise_speed_kmh
from renamed
