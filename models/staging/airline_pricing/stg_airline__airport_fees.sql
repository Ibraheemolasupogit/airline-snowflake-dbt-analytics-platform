with source as (

    select *
    from {{ source('airline_pricing', 'airport_fees') }}

),

renamed as (

    select
        nullif(trim(cast(airport_fee_id as varchar)), '') as airport_fee_id,
        nullif(trim(cast(airport_ident as varchar)), '') as airport_ident,
        nullif(trim(cast(fee_code as varchar)), '') as fee_code,
        nullif(trim(cast(fee_name as varchar)), '') as fee_name,
        nullif(trim(cast(currency_code as varchar)), '') as currency_code,
        try_to_decimal(nullif(trim(cast(amount as varchar)), ''), 18, 2) as amount
    from source

)

select
    airport_fee_id,
    airport_ident,
    fee_code,
    fee_name,
    currency_code,
    amount
from renamed
