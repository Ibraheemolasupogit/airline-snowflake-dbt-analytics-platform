with airports as (

    select
        ident,
        airport_source_id
    from {{ ref('stg_airstats__airports') }}

),

comments as (

    select
        airport_comment_source_id,
        thread_source_id,
        airport_ident,
        comment_at,
        member_nickname,
        body
    from {{ ref('stg_airstats__airport_comments') }}

),

comment_activity as (

    select
        airport_ident,
        count(airport_comment_source_id) as comment_count,
        min(comment_at) as first_comment_at,
        max(comment_at) as latest_comment_at,
        count(distinct thread_source_id) as distinct_thread_count,
        count(distinct member_nickname) as distinct_member_count,
        count_if(body is not null) as comments_with_text_count
    from comments
    group by airport_ident

),

final as (

    select
        airports.airport_source_id,
        airports.ident,
        comment_activity.first_comment_at,
        comment_activity.latest_comment_at,
        coalesce(comment_activity.comment_count, 0) as comment_count,
        coalesce(comment_activity.distinct_thread_count, 0) as distinct_thread_count,
        coalesce(comment_activity.distinct_member_count, 0) as distinct_member_count,
        coalesce(comment_activity.comments_with_text_count, 0) as comments_with_text_count
    from airports
    left join comment_activity
        on airports.ident = comment_activity.airport_ident

)

select
    airport_source_id,
    ident,
    comment_count,
    first_comment_at,
    latest_comment_at,
    distinct_thread_count,
    distinct_member_count,
    comments_with_text_count
from final
