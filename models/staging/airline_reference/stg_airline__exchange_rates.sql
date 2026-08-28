with source as (

    select *
    from {{ source('airline_reference', 'exchange_rates') }}

),

renamed as (

    select
        nullif(trim(cast(currency_code as varchar)), '') as currency_code,
        try_to_decimal(nullif(trim(cast(rate_to_usd as varchar)), ''), 18, 6) as rate_to_usd,
        try_to_date(nullif(trim(cast(as_of_date as varchar)), '')) as as_of_date
    from source

)

select
    currency_code,
    rate_to_usd,
    as_of_date
from renamed
