with source as (

    select *
    from {{ source('airline_billing', 'corporate_accounts') }}

),

renamed as (

    select
        nullif(trim(cast(corporate_account_id as varchar)), '') as corporate_account_id,
        nullif(trim(cast(company_name as varchar)), '') as company_name,
        nullif(trim(cast(country as varchar)), '') as country,
        try_to_decimal(
            nullif(trim(cast(negotiated_discount_pct as varchar)), ''), 18, 6
        ) as negotiated_discount_pct,
        nullif(trim(cast(default_currency as varchar)), '') as default_currency
    from source

)

select
    corporate_account_id,
    company_name,
    country,
    negotiated_discount_pct,
    default_currency
from renamed
