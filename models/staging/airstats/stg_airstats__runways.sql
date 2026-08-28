with source as (

    select *
    from {{ source('airstats', 'runways') }}

),

renamed as (

    select
        try_to_number(nullif(trim(cast(id as varchar)), ''), 38, 0) as runway_source_id,
        try_to_number(nullif(trim(cast(airport_ref as varchar)), ''), 38, 0) as airport_source_id,
        nullif(trim(cast(airport_ident as varchar)), '') as airport_ident,
        try_to_number(nullif(trim(cast(length_ft as varchar)), ''), 38, 0) as length_ft,
        try_to_number(nullif(trim(cast(width_ft as varchar)), ''), 38, 0) as width_ft,
        nullif(trim(cast(surface as varchar)), '') as surface,
        case
            when try_to_number(nullif(trim(cast(lighted as varchar)), ''), 1, 0) = 1 then true
            when try_to_number(nullif(trim(cast(lighted as varchar)), ''), 1, 0) = 0 then false
        end as is_lighted,
        case
            when try_to_number(nullif(trim(cast(closed as varchar)), ''), 1, 0) = 1 then true
            when try_to_number(nullif(trim(cast(closed as varchar)), ''), 1, 0) = 0 then false
        end as is_closed,
        nullif(trim(cast(le_ident as varchar)), '') as le_ident,
        try_to_double(nullif(trim(cast(le_latitude_deg as varchar)), '')) as le_latitude_deg,
        try_to_double(nullif(trim(cast(le_longitude_deg as varchar)), '')) as le_longitude_deg,
        try_to_number(nullif(trim(cast(le_elevation_ft as varchar)), ''), 38, 0) as le_elevation_ft,
        try_to_double(nullif(trim(cast(le_heading_degt as varchar)), '')) as le_heading_degt,
        try_to_number(
            nullif(trim(cast(le_displaced_threshold_ft as varchar)), ''), 38, 0
        ) as le_displaced_threshold_ft,
        nullif(trim(cast(he_ident as varchar)), '') as he_ident,
        try_to_double(nullif(trim(cast(he_latitude_deg as varchar)), '')) as he_latitude_deg,
        try_to_double(nullif(trim(cast(he_longitude_deg as varchar)), '')) as he_longitude_deg,
        try_to_number(nullif(trim(cast(he_elevation_ft as varchar)), ''), 38, 0) as he_elevation_ft,
        try_to_double(nullif(trim(cast(he_heading_degt as varchar)), '')) as he_heading_degt,
        try_to_number(
            nullif(trim(cast(he_displaced_threshold_ft as varchar)), ''), 38, 0
        ) as he_displaced_threshold_ft
    from source

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
from renamed
