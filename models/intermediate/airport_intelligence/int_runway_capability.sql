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
        he_ident,
        he_latitude_deg,
        he_longitude_deg
    from {{ ref('stg_airstats__runways') }}

),

classified as (

    select
        runway_source_id,
        airport_source_id,
        airport_ident,
        length_ft,
        width_ft,
        surface,
        is_lighted,
        is_closed,
        case
            when is_closed = true then false
            when is_closed = false then true
        end as is_source_usable,
        case
            when length_ft is null then 'unknown'
            when length_ft < 4000 then 'short_lt_4000_ft'
            when length_ft < 8000 then 'medium_4000_to_7999_ft'
            else 'long_8000_ft_plus'
        end as runway_length_category,
        case
            when width_ft is null then 'unknown'
            when width_ft < 75 then 'narrow_lt_75_ft'
            when width_ft < 150 then 'standard_75_to_149_ft'
            else 'wide_150_ft_plus'
        end as runway_width_category,
        case
            when surface is null then 'unknown'
            when lower(surface) like '%water%' then 'water'
            when lower(surface) like '%asphalt%' then 'hard_surface'
            when lower(surface) like '%concrete%' then 'hard_surface'
            when lower(surface) like '%paved%' then 'hard_surface'
            when lower(surface) like '%bituminous%' then 'hard_surface'
            when lower(surface) like '%macadam%' then 'hard_surface'
            when lower(surface) like '%grass%' then 'soft_surface'
            when lower(surface) like '%turf%' then 'soft_surface'
            when lower(surface) like '%gravel%' then 'soft_surface'
            when lower(surface) like '%dirt%' then 'soft_surface'
            when lower(surface) like '%sand%' then 'soft_surface'
            else 'other'
        end as runway_surface_category,
        case
            when
                le_ident is not null
                and le_latitude_deg is not null
                and le_longitude_deg is not null
                and he_ident is not null
                and he_latitude_deg is not null
                and he_longitude_deg is not null
                then 'complete'
            when
                le_ident is null
                and le_latitude_deg is null
                and le_longitude_deg is null
                and he_ident is null
                and he_latitude_deg is null
                and he_longitude_deg is null
                then 'missing'
            else 'partial'
        end as endpoint_completeness_status
    from runways

),

final as (

    select
        runway_source_id,
        airport_source_id,
        airport_ident,
        length_ft,
        width_ft,
        surface,
        is_lighted,
        is_closed,
        is_source_usable,
        runway_length_category,
        runway_width_category,
        runway_surface_category,
        endpoint_completeness_status
    from classified

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
    is_source_usable,
    runway_length_category,
    runway_width_category,
    runway_surface_category,
    endpoint_completeness_status
from final
