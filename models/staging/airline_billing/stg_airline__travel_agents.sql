with source as (

    select *
    from {{ source('airline_billing', 'travel_agents') }}

),

renamed as (

    select
        nullif(trim(cast(travel_agent_id as varchar)), '') as travel_agent_id,
        nullif(trim(cast(agency_name as varchar)), '') as agency_name,
        nullif(trim(cast(iata_number as varchar)), '') as iata_number,
        nullif(trim(cast(country as varchar)), '') as country,
        try_to_decimal(nullif(trim(cast(commission_pct as varchar)), ''), 18, 6) as commission_pct
    from source

)

select
    travel_agent_id,
    agency_name,
    iata_number,
    country,
    commission_pct
from renamed
