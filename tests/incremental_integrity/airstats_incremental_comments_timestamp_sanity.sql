select
    airport_comment_source_id,
    comment_at
from {{ ref('int_airport_comments_incremental') }}
where comment_at > current_timestamp()
