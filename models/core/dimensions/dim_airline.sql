-- Grain is one row per airline. Validates each airline's hub airport against the conformed
-- dim_airport, demonstrating (not just documenting) AirStats integration.
with airlines as (

    select
        airline_code,
        airline_name,
        home_country,
        hub_ident
    from {{ ref('stg_airline__airlines') }}

),

hub_airports as (

    select
        airport_key,
        airport_ident
    from {{ ref('dim_airport') }}

),

joined as (

    select
        airlines.airline_code,
        airlines.airline_name,
        airlines.home_country,
        airlines.hub_ident,
        hub_airports.airport_key as hub_airport_key
    from airlines
    left join hub_airports
        on airlines.hub_ident = hub_airports.airport_ident

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['airline_code']) }} as airline_key,
        airline_code,
        airline_name,
        home_country,
        hub_ident,
        hub_airport_key
    from joined

)

select
    airline_key,
    airline_code,
    airline_name,
    home_country,
    hub_ident,
    hub_airport_key
from final
