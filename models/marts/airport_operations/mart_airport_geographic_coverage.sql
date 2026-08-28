with geography as (

    select
        ident,
        airport_source_id,
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
        local_code
    from {{ ref('int_airport_geography') }}

),

final as (

    select
        ident,
        airport_source_id,
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
        region_code is not null as has_region_coverage,
        country_code is not null as has_country_coverage,
        latitude_deg is not null and longitude_deg is not null as has_coordinate_coverage
    from geography

)

select
    ident,
    airport_source_id,
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
    has_region_coverage,
    has_country_coverage,
    has_coordinate_coverage
from final
