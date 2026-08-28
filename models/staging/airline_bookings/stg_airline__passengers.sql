-- All passenger attributes in this model are synthetic (Milestone 9 generator output).
-- No real individuals are represented.
with source as (

    select *
    from {{ source('airline_bookings', 'passengers') }}

),

renamed as (

    select
        nullif(trim(cast(passenger_id as varchar)), '') as passenger_id,
        nullif(trim(cast(first_name as varchar)), '') as first_name,
        nullif(trim(cast(last_name as varchar)), '') as last_name,
        try_to_date(nullif(trim(cast(date_of_birth as varchar)), '')) as date_of_birth,
        nullif(trim(cast(nationality as varchar)), '') as nationality,
        nullif(trim(cast(email as varchar)), '') as email,
        nullif(trim(cast(loyalty_tier as varchar)), '') as loyalty_tier
    from source

)

select
    passenger_id,
    first_name,
    last_name,
    date_of_birth,
    nationality,
    email,
    loyalty_tier
from renamed
