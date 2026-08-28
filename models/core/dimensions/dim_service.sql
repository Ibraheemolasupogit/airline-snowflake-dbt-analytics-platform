-- Grain is one row per sellable ancillary/service catalog entry. Natural key is service_code.
-- category is retained on this dimension directly (baggage/seat/meal/lounge/upgrade-style
-- groupings) rather than split into a separate dim_ancillary_type: the source has no standalone
-- "ancillary type" table, category is only ever an attribute of a service row, and no other fact
-- in this milestone references it independently of service_code, so a separate dimension would add
-- a join hop with no additional source authority.
with services as (

    select
        service_code,
        service_name,
        category,
        base_price_usd
    from {{ ref('stg_airline__services') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['service_code']) }} as service_key,
        service_code,
        service_name,
        category,
        base_price_usd
    from services

)

select
    service_key,
    service_code,
    service_name,
    category,
    base_price_usd
from final
