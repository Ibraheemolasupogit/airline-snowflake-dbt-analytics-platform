{% snapshot snap_runways %}

{{
    config(
        target_schema='snapshots',
        unique_key='runway_source_id',
        strategy='check',
        check_cols=[
            'airport_ident',
            'length_ft',
            'width_ft',
            'surface',
            'is_lighted',
            'is_closed',
            'le_ident',
            'le_latitude_deg',
            'le_longitude_deg',
            'le_elevation_ft',
            'le_heading_degt',
            'le_displaced_threshold_ft',
            'he_ident',
            'he_latitude_deg',
            'he_longitude_deg',
            'he_elevation_ft',
            'he_heading_degt',
            'he_displaced_threshold_ft'
        ],
        invalidate_hard_deletes=True
    )
}}

with runways as (

    select
        runway_source_id,
        airport_source_id,
        airport_ident,
        length_ft,
        width_ft,
        surface,
        is_lighted,
        is_closed,
        le_ident,
        le_latitude_deg,
        le_longitude_deg,
        le_elevation_ft,
        le_heading_degt,
        le_displaced_threshold_ft,
        he_ident,
        he_latitude_deg,
        he_longitude_deg,
        he_elevation_ft,
        he_heading_degt,
        he_displaced_threshold_ft
    from {{ ref('stg_airstats__runways') }}

)

select
    runway_source_id,
    airport_source_id,
    airport_ident,
    length_ft,
    width_ft,
    surface,
    is_lighted,
    is_closed,
    le_ident,
    le_latitude_deg,
    le_longitude_deg,
    le_elevation_ft,
    le_heading_degt,
    le_displaced_threshold_ft,
    he_ident,
    he_latitude_deg,
    he_longitude_deg,
    he_elevation_ft,
    he_heading_degt,
    he_displaced_threshold_ft
from runways

{% endsnapshot %}
