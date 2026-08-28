select
    airport_comment_source_id,
    count(*) as row_count
from {{ ref('int_airport_comments_incremental') }}
group by airport_comment_source_id
having count(*) > 1
