with source as (

    select *
    from {{ source('airline_operations', 'routes') }}

),

renamed as (

    select
        nullif(trim(cast(route_id as varchar)), '') as route_id,
        nullif(trim(cast(airline_code as varchar)), '') as airline_code,
        nullif(trim(cast(origin_ident as varchar)), '') as origin_ident,
        nullif(trim(cast(destination_ident as varchar)), '') as destination_ident,
        try_to_decimal(nullif(trim(cast(distance_km as varchar)), ''), 18, 1) as distance_km
    from source

)

select
    route_id,
    airline_code,
    origin_ident,
    destination_ident,
    distance_km
from renamed
