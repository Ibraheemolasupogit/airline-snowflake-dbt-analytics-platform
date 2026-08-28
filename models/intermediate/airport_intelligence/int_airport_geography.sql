with airports as (

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
        gps_code,
        icao_code,
        iata_code,
        local_code,
        home_link,
        wikipedia_link
    from {{ ref('stg_airstats__airports') }}

),

regions as (

    select
        region_source_id,
        region_code,
        local_region_code,
        region_name,
        continent_code as region_continent_code,
        country_code as region_country_code
    from {{ ref('stg_airstats__regions') }}

),

countries as (

    select
        country_source_id,
        country_code,
        country_name,
        continent_code as country_continent_code
    from {{ ref('stg_airstats__countries') }}

),

joined as (

    select
        airports.airport_source_id,
        airports.ident,
        airports.airport_type,
        airports.airport_name,
        airports.municipality,
        airports.iso_region as region_code,
        regions.local_region_code,
        regions.region_name,
        airports.iso_country as country_code,
        countries.country_name,
        airports.latitude_deg,
        airports.longitude_deg,
        airports.elevation_ft,
        airports.gps_code,
        airports.icao_code,
        airports.iata_code,
        airports.local_code,
        airports.home_link,
        airports.wikipedia_link,
        regions.region_source_id,
        countries.country_source_id,
        coalesce(
            airports.continent_code,
            regions.region_continent_code,
            countries.country_continent_code
        ) as continent_code
    from airports
    left join regions
        on airports.iso_region = regions.region_code
    left join countries
        on airports.iso_country = countries.country_code

),

final as (

    select
        airport_source_id,
        ident,
        airport_type,
        airport_name,
        municipality,
        region_code,
        local_region_code,
        region_name,
        country_code,
        country_name,
        continent_code,
        latitude_deg,
        longitude_deg,
        elevation_ft,
        gps_code,
        icao_code,
        iata_code,
        local_code,
        home_link,
        wikipedia_link,
        region_source_id,
        country_source_id
    from joined

)

select
    airport_source_id,
    ident,
    airport_type,
    airport_name,
    municipality,
    region_code,
    local_region_code,
    region_name,
    country_code,
    country_name,
    continent_code,
    latitude_deg,
    longitude_deg,
    elevation_ft,
    gps_code,
    icao_code,
    iata_code,
    local_code,
    home_link,
    wikipedia_link,
    region_source_id,
    country_source_id
from final
