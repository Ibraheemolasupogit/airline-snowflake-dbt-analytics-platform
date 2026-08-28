-- The first true conformed airport dimension. Grain is one row per current airport identifier.
-- AirStats is the sole authoritative source: this reuses the existing AirStats marts
-- (mart_airport_geographic_coverage, mart_airport_capacity_profile) rather than rebuilding
-- airport logic, and never joins the synthetic data/synthetic/reference/airports.csv fixture.
with geographic_coverage as (

    select
        ident,
        airport_type,
        airport_name,
        municipality,
        region_code,
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
    from {{ ref('mart_airport_geographic_coverage') }}

),

capacity_profile as (

    select
        ident,
        has_scheduled_service,
        runway_count,
        open_runway_count
    from {{ ref('mart_airport_capacity_profile') }}

),

joined as (

    select
        geographic_coverage.ident as airport_ident,
        geographic_coverage.airport_name,
        geographic_coverage.airport_type,
        geographic_coverage.country_code,
        geographic_coverage.country_name,
        geographic_coverage.region_code,
        geographic_coverage.region_name,
        geographic_coverage.municipality,
        geographic_coverage.continent_code,
        geographic_coverage.latitude_deg,
        geographic_coverage.longitude_deg,
        geographic_coverage.elevation_ft,
        geographic_coverage.gps_code,
        geographic_coverage.icao_code,
        geographic_coverage.iata_code,
        geographic_coverage.local_code,
        capacity_profile.has_scheduled_service,
        capacity_profile.runway_count,
        capacity_profile.open_runway_count
    from geographic_coverage
    left join capacity_profile
        on geographic_coverage.ident = capacity_profile.ident

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['airport_ident']) }} as airport_key,
        airport_ident,
        airport_name,
        airport_type,
        country_code,
        country_name,
        region_code,
        region_name,
        municipality,
        continent_code,
        latitude_deg,
        longitude_deg,
        elevation_ft,
        gps_code,
        icao_code,
        iata_code,
        local_code,
        has_scheduled_service,
        runway_count,
        open_runway_count
    from joined

)

select
    airport_key,
    airport_ident,
    airport_name,
    airport_type,
    country_code,
    country_name,
    region_code,
    region_name,
    municipality,
    continent_code,
    latitude_deg,
    longitude_deg,
    elevation_ft,
    gps_code,
    icao_code,
    iata_code,
    local_code,
    has_scheduled_service,
    runway_count,
    open_runway_count
from final
