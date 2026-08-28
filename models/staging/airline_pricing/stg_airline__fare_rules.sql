with source as (

    select *
    from {{ source('airline_pricing', 'fare_rules') }}

),

renamed as (

    select
        nullif(trim(cast(fare_rule_id as varchar)), '') as fare_rule_id,
        nullif(trim(cast(fare_class_code as varchar)), '') as fare_class_code,
        case
            when lower(nullif(trim(cast(refundable as varchar)), '')) = 'true' then true
            when lower(nullif(trim(cast(refundable as varchar)), '')) = 'false' then false
        end as refundable,
        try_to_decimal(nullif(trim(cast(change_fee_usd as varchar)), ''), 18, 2) as change_fee_usd,
        try_to_number(
            nullif(trim(cast(advance_purchase_days as varchar)), ''), 38, 0
        ) as advance_purchase_days,
        try_to_number(nullif(trim(cast(min_stay_nights as varchar)), ''), 38, 0) as min_stay_nights
    from source

)

select
    fare_rule_id,
    fare_class_code,
    refundable,
    change_fee_usd,
    advance_purchase_days,
    min_stay_nights
from renamed
