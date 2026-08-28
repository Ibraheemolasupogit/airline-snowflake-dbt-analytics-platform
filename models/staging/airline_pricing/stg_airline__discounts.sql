with source as (

    select *
    from {{ source('airline_pricing', 'discounts') }}

),

renamed as (

    select
        nullif(trim(cast(discount_code as varchar)), '') as discount_code,
        nullif(trim(cast(discount_name as varchar)), '') as discount_name,
        nullif(trim(cast(discount_type as varchar)), '') as discount_type,
        try_to_decimal(nullif(trim(cast(value as varchar)), ''), 18, 6) as value,
        nullif(trim(cast(corporate_account_id as varchar)), '') as corporate_account_id
    from source

)

select
    discount_code,
    discount_name,
    discount_type,
    value,
    corporate_account_id
from renamed
