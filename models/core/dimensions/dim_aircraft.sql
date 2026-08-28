-- Grain is one row per aircraft registration.
with aircraft as (

    select
        aircraft_registration,
        airline_code,
        aircraft_type_code,
        manufactured_year
    from {{ ref('stg_airline__aircraft') }}

),

airlines as (

    select
        airline_key,
        airline_code
    from {{ ref('dim_airline') }}

),

aircraft_types as (

    select
        aircraft_type_key,
        aircraft_type_code
    from {{ ref('dim_aircraft_type') }}

),

joined as (

    select
        aircraft.aircraft_registration,
        aircraft.airline_code,
        airlines.airline_key,
        aircraft.aircraft_type_code,
        aircraft_types.aircraft_type_key,
        aircraft.manufactured_year
    from aircraft
    left join airlines
        on aircraft.airline_code = airlines.airline_code
    left join aircraft_types
        on aircraft.aircraft_type_code = aircraft_types.aircraft_type_code

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['aircraft_registration']) }} as aircraft_key,
        aircraft_registration,
        airline_key,
        airline_code,
        aircraft_type_key,
        aircraft_type_code,
        manufactured_year
    from joined

)

select
    aircraft_key,
    aircraft_registration,
    airline_key,
    airline_code,
    aircraft_type_key,
    aircraft_type_code,
    manufactured_year
from final
