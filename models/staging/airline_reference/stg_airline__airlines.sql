with source as (

    select *
    from {{ source('airline_reference', 'airlines') }}

),

renamed as (

    select
        nullif(trim(cast(airline_code as varchar)), '') as airline_code,
        nullif(trim(cast(airline_name as varchar)), '') as airline_name,
        nullif(trim(cast(home_country as varchar)), '') as home_country,
        nullif(trim(cast(hub_ident as varchar)), '') as hub_ident
    from source

)

select
    airline_code,
    airline_name,
    home_country,
    hub_ident
from renamed
