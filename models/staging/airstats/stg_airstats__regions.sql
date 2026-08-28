with source as (

    select *
    from {{ source('airstats', 'regions') }}

),

renamed as (

    select
        try_to_number(nullif(trim(cast(id as varchar)), ''), 38, 0) as region_source_id,
        nullif(trim(cast(code as varchar)), '') as region_code,
        nullif(trim(cast(local_code as varchar)), '') as local_region_code,
        nullif(trim(cast(name as varchar)), '') as region_name,
        nullif(trim(cast(continent as varchar)), '') as continent_code,
        nullif(trim(cast(iso_country as varchar)), '') as country_code,
        nullif(trim(cast(wikipedia_link as varchar)), '') as wikipedia_link,
        nullif(trim(cast(keywords as varchar)), '') as keywords
    from source

)

select
    region_source_id,
    region_code,
    local_region_code,
    region_name,
    continent_code,
    country_code,
    wikipedia_link,
    keywords
from renamed
