-- Curated AirStats airport data-quality analysis: airports failing one or more structural
-- quality checks (comment completeness, region/country reference validity, runway profile
-- count consistency). Structural completeness only; not a linguistic or semantic quality score.

with data_quality as (

    select
        ident,
        comment_count,
        comment_completeness_status,
        has_valid_region_reference,
        has_valid_country_reference,
        has_consistent_runway_profile_counts
    from {{ ref('mart_airport_data_quality') }}

),

flagged as (

    select
        ident,
        comment_count,
        comment_completeness_status,
        has_valid_region_reference,
        has_valid_country_reference,
        has_consistent_runway_profile_counts,
        (
            comment_completeness_status = 'incomplete'
            or not has_valid_region_reference
            or not has_valid_country_reference
            or not has_consistent_runway_profile_counts
        ) as has_data_quality_issue
    from data_quality

)

select
    ident,
    comment_count,
    comment_completeness_status,
    has_valid_region_reference,
    has_valid_country_reference,
    has_consistent_runway_profile_counts
from flagged
where has_data_quality_issue
order by ident
