with source as (

    select *
    from {{ source('airline_pricing', 'fare_classes') }}

),

renamed as (

    select
        nullif(trim(cast(fare_class_code as varchar)), '') as fare_class_code,
        nullif(trim(cast(cabin as varchar)), '') as cabin,
        nullif(trim(cast(fare_basis_code as varchar)), '') as fare_basis_code,
        case
            when lower(nullif(trim(cast(refundable as varchar)), '')) = 'true' then true
            when lower(nullif(trim(cast(refundable as varchar)), '')) = 'false' then false
        end as refundable,
        try_to_decimal(nullif(trim(cast(change_fee_usd as varchar)), ''), 18, 2) as change_fee_usd,
        try_to_decimal(nullif(trim(cast(base_fare_usd as varchar)), ''), 18, 2) as base_fare_usd,
        try_to_decimal(nullif(trim(cast(per_km_usd as varchar)), ''), 18, 6) as per_km_usd,
        nullif(trim(cast(description as varchar)), '') as description
    from source

)

select
    fare_class_code,
    cabin,
    fare_basis_code,
    refundable,
    change_fee_usd,
    base_fare_usd,
    per_km_usd,
    description
from renamed
