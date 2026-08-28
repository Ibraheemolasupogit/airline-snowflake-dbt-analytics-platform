select
    ident,
    comment_count,
    complete_comment_record_count,
    complete_comment_record_ratio,
    comment_completeness_status
from {{ ref('int_airport_comment_quality') }}
where
    complete_comment_record_ratio < 0
    or complete_comment_record_ratio > 1
    or (
        comment_count = 0
        and (
            complete_comment_record_ratio is not null
            or comment_completeness_status != 'no_comments'
        )
    )
    or (
        comment_count > 0
        and complete_comment_record_count > comment_count
    )
