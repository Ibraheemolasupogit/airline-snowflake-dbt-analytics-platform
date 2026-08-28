-- Grain is one row per aircraft type.
with aircraft_types as (

    select
        aircraft_type_code,
        type_name,
        body_type,
        typical_seats,
        cabins,
        cruise_speed_kmh
    from {{ ref('stg_airline__aircraft_types') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['aircraft_type_code']) }} as aircraft_type_key,
        aircraft_type_code,
        type_name,
        body_type,
        typical_seats,
        cabins,
        cruise_speed_kmh
    from aircraft_types

)

select
    aircraft_type_key,
    aircraft_type_code,
    type_name,
    body_type,
    typical_seats,
    cabins,
    cruise_speed_kmh
from final
