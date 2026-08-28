with comment_activity as (

    select
        ident,
        airport_source_id,
        comment_count,
        first_comment_at,
        latest_comment_at,
        distinct_thread_count,
        distinct_member_count,
        comments_with_text_count
    from {{ ref('int_airport_comment_activity') }}

),

geography as (

    select
        ident,
        airport_name,
        country_code,
        country_name
    from {{ ref('int_airport_geography') }}

),

final as (

    select
        comment_activity.ident,
        comment_activity.airport_source_id,
        geography.airport_name,
        geography.country_code,
        geography.country_name,
        comment_activity.comment_count,
        comment_activity.first_comment_at,
        comment_activity.latest_comment_at,
        comment_activity.distinct_thread_count,
        comment_activity.distinct_member_count,
        comment_activity.comments_with_text_count
    from comment_activity
    left join geography
        on comment_activity.ident = geography.ident

)

select
    ident,
    airport_source_id,
    airport_name,
    country_code,
    country_name,
    comment_count,
    first_comment_at,
    latest_comment_at,
    distinct_thread_count,
    distinct_member_count,
    comments_with_text_count
from final
