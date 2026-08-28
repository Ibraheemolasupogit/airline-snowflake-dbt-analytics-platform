with source as (

    select *
    from {{ source('airstats', 'airports') }}

),

renamed as (

    select
        try_to_number(nullif(trim(cast(id as varchar)), ''), 38, 0) as airport_source_id,
        nullif(trim(cast(ident as varchar)), '') as ident,
        nullif(trim(cast(type as varchar)), '') as airport_type,
        nullif(trim(cast(name as varchar)), '') as airport_name,
        try_to_double(nullif(trim(cast(latitude_deg as varchar)), '')) as latitude_deg,
        try_to_double(nullif(trim(cast(longitude_deg as varchar)), '')) as longitude_deg,
        try_to_number(nullif(trim(cast(elevation_ft as varchar)), ''), 38, 0) as elevation_ft,
        nullif(trim(cast(continent as varchar)), '') as continent_code,
        nullif(trim(cast(iso_country as varchar)), '') as iso_country,
        nullif(trim(cast(iso_region as varchar)), '') as iso_region,
        nullif(trim(cast(municipality as varchar)), '') as municipality,
        case
            when lower(nullif(trim(cast(scheduled_service as varchar)), '')) = 'yes' then true
            when lower(nullif(trim(cast(scheduled_service as varchar)), '')) = 'no' then false
        end as has_scheduled_service,
        nullif(trim(cast(gps_code as varchar)), '') as gps_code,
        nullif(trim(cast(icao_code as varchar)), '') as icao_code,
        nullif(trim(cast(iata_code as varchar)), '') as iata_code,
        nullif(trim(cast(local_code as varchar)), '') as local_code,
        nullif(trim(cast(home_link as varchar)), '') as home_link,
        nullif(trim(cast(wikipedia_link as varchar)), '') as wikipedia_link,
        nullif(trim(cast(keywords as varchar)), '') as keywords
    from source

)

select
    airport_source_id,
    ident,
    airport_type,
    airport_name,
    latitude_deg,
    longitude_deg,
    elevation_ft,
    continent_code,
    iso_country,
    iso_region,
    municipality,
    has_scheduled_service,
    gps_code,
    icao_code,
    iata_code,
    local_code,
    home_link,
    wikipedia_link,
    keywords
from renamed
