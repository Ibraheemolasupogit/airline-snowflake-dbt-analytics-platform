-- Grain is one row per fare class. Reuses stg_airline__fare_classes but deliberately excludes
-- its monetary columns (base_fare_usd, per_km_usd, change_fee_usd) -- fare/pricing calculations
-- are out of scope until Milestone 13 (Products, Services, Prices and Tariffs). refundable is a
-- fare-rule attribute, not a monetary value, so it is retained.
with fare_classes as (

    select
        fare_class_code,
        cabin,
        fare_basis_code,
        refundable,
        description
    from {{ ref('stg_airline__fare_classes') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['fare_class_code']) }} as fare_class_key,
        fare_class_code,
        cabin,
        fare_basis_code,
        refundable,
        description
    from fare_classes

)

select
    fare_class_key,
    fare_class_code,
    cabin,
    fare_basis_code,
    refundable,
    description
from final
