-- Grain is one row per sellable fare bundle. Natural key is product_code. This is a standalone
-- catalog dimension: no Milestone 9 booking/ticket table carries a product_code foreign key
-- (bookings and tickets reference fare_class_code directly), so no fact in this milestone joins
-- to dim_product. It is still implemented, per the Milestone 13 scope ("Products, Services, Prices
-- and Tariffs"), for catalog completeness and to document the source relationship between a
-- product and the fare class / services it bundles. included_service_codes is preserved as the
-- staged pipe-delimited text (not parsed into an array), matching stg_airline__products.
with products as (

    select
        product_code,
        product_name,
        fare_class_code,
        included_service_codes
    from {{ ref('stg_airline__products') }}

),

fare_classes as (

    select
        fare_class_key,
        fare_class_code
    from {{ ref('dim_fare_class') }}

),

joined as (

    select
        products.product_code,
        products.product_name,
        fare_classes.fare_class_key,
        products.fare_class_code,
        products.included_service_codes
    from products
    left join fare_classes
        on products.fare_class_code = fare_classes.fare_class_code

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['product_code']) }} as product_key,
        product_code,
        product_name,
        fare_class_key,
        fare_class_code,
        included_service_codes
    from joined

)

select
    product_key,
    product_code,
    product_name,
    fare_class_key,
    fare_class_code,
    included_service_codes
from final
