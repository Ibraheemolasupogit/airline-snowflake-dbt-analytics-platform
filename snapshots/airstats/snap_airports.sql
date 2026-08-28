{% snapshot snap_airports %}

{{
    config(
        target_schema='snapshots',
        unique_key='ident',
        strategy='check',
        check_cols=[
            'airport_type',
            'airport_name',
            'latitude_deg',
            'longitude_deg',
            'elevation_ft',
            'continent_code',
            'iso_country',
            'iso_region',
            'municipality',
            'has_scheduled_service',
            'gps_code',
            'icao_code',
            'iata_code',
            'local_code'
        ],
        invalidate_hard_deletes=True
    )
}}

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
        has_scheduled_service,
        gps_code,
        icao_code,
        iata_code,
        local_code,
        home_link,
        wikipedia_link,
        keywords
    from {{ ref('stg_airstats__airports') }}

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
from airports

{% endsnapshot %}
