with source as (

    select *
    from {{ source('airstats', 'countries') }}

),

renamed as (

    select
        try_to_number(nullif(trim(cast(id as varchar)), ''), 38, 0) as country_source_id,
        nullif(trim(cast(code as varchar)), '') as country_code,
        nullif(trim(cast(name as varchar)), '') as country_name,
        nullif(trim(cast(continent as varchar)), '') as continent_code,
        nullif(trim(cast(wikipedia_link as varchar)), '') as wikipedia_link,
        nullif(trim(cast(keywords as varchar)), '') as keywords
    from source

)

select
    country_source_id,
    country_code,
    country_name,
    continent_code,
    wikipedia_link,
    keywords
from renamed
