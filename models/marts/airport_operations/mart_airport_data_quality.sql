with comment_quality as (

    select
        ident,
        airport_source_id,
        comment_count,
        comments_missing_text_count,
        comments_missing_timestamp_count,
        complete_comment_record_ratio,
        comment_completeness_status
    from {{ ref('int_airport_comment_quality') }}

),

geography as (

    select
        ident,
        region_code,
        region_source_id,
        country_code,
        country_source_id
    from {{ ref('int_airport_geography') }}

),

runway_profile as (

    select
        ident,
        runway_count,
        open_runway_count,
        closed_runway_count,
        lighted_runway_count
    from {{ ref('int_airport_runway_profile') }}

),

combined as (

    select
        comment_quality.ident,
        comment_quality.airport_source_id,
        comment_quality.comment_count,
        comment_quality.comments_missing_text_count,
        comment_quality.comments_missing_timestamp_count,
        comment_quality.complete_comment_record_ratio,
        comment_quality.comment_completeness_status,
        geography.region_code,
        geography.region_source_id,
        geography.country_code,
        geography.country_source_id,
        runway_profile.runway_count,
        runway_profile.open_runway_count,
        runway_profile.closed_runway_count,
        runway_profile.lighted_runway_count
    from comment_quality
    left join geography
        on comment_quality.ident = geography.ident
    left join runway_profile
        on comment_quality.ident = runway_profile.ident

),

final as (

    select
        ident,
        airport_source_id,
        comment_count,
        comments_missing_text_count,
        comments_missing_timestamp_count,
        complete_comment_record_ratio,
        comment_completeness_status,
        region_code,
        region_source_id,
        country_code,
        country_source_id,
        runway_count,
        open_runway_count,
        closed_runway_count,
        lighted_runway_count,
        (region_code is null or region_source_id is not null) as has_valid_region_reference,
        (country_code is null or country_source_id is not null) as has_valid_country_reference,
        (
            open_runway_count + closed_runway_count <= runway_count
            and lighted_runway_count <= runway_count
        ) as has_consistent_runway_profile_counts
    from combined

)

select
    ident,
    airport_source_id,
    comment_count,
    comments_missing_text_count,
    comments_missing_timestamp_count,
    complete_comment_record_ratio,
    comment_completeness_status,
    region_code,
    region_source_id,
    has_valid_region_reference,
    country_code,
    country_source_id,
    has_valid_country_reference,
    runway_count,
    open_runway_count,
    closed_runway_count,
    lighted_runway_count,
    has_consistent_runway_profile_counts
from final
