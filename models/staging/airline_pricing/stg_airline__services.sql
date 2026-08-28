with source as (

    select *
    from {{ source('airline_pricing', 'services') }}

),

renamed as (

    select
        nullif(trim(cast(service_code as varchar)), '') as service_code,
        nullif(trim(cast(service_name as varchar)), '') as service_name,
        nullif(trim(cast(category as varchar)), '') as category,
        try_to_decimal(nullif(trim(cast(base_price_usd as varchar)), ''), 18, 2) as base_price_usd
    from source

)

select
    service_code,
    service_name,
    category,
    base_price_usd
from renamed
