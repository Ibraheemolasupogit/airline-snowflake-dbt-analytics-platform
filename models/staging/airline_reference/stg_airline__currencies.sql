with source as (

    select *
    from {{ source('airline_reference', 'currencies') }}

),

renamed as (

    select
        nullif(trim(cast(currency_code as varchar)), '') as currency_code,
        nullif(trim(cast(currency_name as varchar)), '') as currency_name,
        try_to_number(nullif(trim(cast(minor_unit_digits as varchar)), ''), 38, 0) as minor_unit_digits
    from source

)

select
    currency_code,
    currency_name,
    minor_unit_digits
from renamed
