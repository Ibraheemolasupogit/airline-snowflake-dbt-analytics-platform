with source as (

    select *
    from {{ source('airline_pricing', 'products') }}

),

renamed as (

    select
        nullif(trim(cast(product_code as varchar)), '') as product_code,
        nullif(trim(cast(product_name as varchar)), '') as product_name,
        nullif(trim(cast(fare_class_code as varchar)), '') as fare_class_code,
        nullif(trim(cast(included_service_codes as varchar)), '') as included_service_codes
    from source

)

select
    product_code,
    product_name,
    fare_class_code,
    included_service_codes
from renamed
