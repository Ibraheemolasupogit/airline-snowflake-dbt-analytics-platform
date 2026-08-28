with source as (

    select *
    from {{ source('airline_pricing', 'taxes') }}

),

renamed as (

    select
        nullif(trim(cast(tax_id as varchar)), '') as tax_id,
        nullif(trim(cast(country_code as varchar)), '') as country_code,
        nullif(trim(cast(tax_code as varchar)), '') as tax_code,
        nullif(trim(cast(tax_name as varchar)), '') as tax_name,
        try_to_decimal(nullif(trim(cast(percentage_rate as varchar)), ''), 18, 6) as percentage_rate,
        nullif(trim(cast(currency_code as varchar)), '') as currency_code
    from source

)

select
    tax_id,
    country_code,
    tax_code,
    tax_name,
    percentage_rate,
    currency_code
from renamed
