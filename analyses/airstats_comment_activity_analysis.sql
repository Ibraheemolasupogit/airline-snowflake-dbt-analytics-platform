-- Curated AirStats airport comment-activity analysis: most-commented airports with their
-- activity window. Counts and timestamps only; no sentiment, NLP, or relevance scoring.

with comment_activity as (

    select
        ident,
        airport_name,
        country_code,
        country_name,
        comment_count,
        first_comment_at,
        latest_comment_at,
        distinct_thread_count,
        distinct_member_count
    from {{ ref('mart_airport_comment_activity') }}

)

select
    ident,
    airport_name,
    country_code,
    country_name,
    comment_count,
    distinct_thread_count,
    distinct_member_count,
    first_comment_at,
    latest_comment_at,
    datediff('day', first_comment_at, latest_comment_at) as activity_span_days
from comment_activity
where comment_count > 0
order by comment_count desc
limit 100
