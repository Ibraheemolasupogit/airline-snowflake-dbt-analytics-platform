with source as (

    select *
    from {{ source('airline_operations', 'aircraft') }}

),

renamed as (

    select
        nullif(trim(cast(aircraft_registration as varchar)), '') as aircraft_registration,
        nullif(trim(cast(airline_code as varchar)), '') as airline_code,
        nullif(trim(cast(aircraft_type_code as varchar)), '') as aircraft_type_code,
        try_to_number(nullif(trim(cast(manufactured_year as varchar)), ''), 38, 0) as manufactured_year
    from source

)

select
    aircraft_registration,
    airline_code,
    aircraft_type_code,
    manufactured_year
from renamed
