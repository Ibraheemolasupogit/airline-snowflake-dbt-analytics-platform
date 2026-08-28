{{
    config(
        materialized='incremental',
        unique_key='airport_comment_source_id',
        incremental_strategy='merge',
        on_schema_change='append_new_columns'
    )
}}

with staged_comments as (

    select
        comments.airport_comment_source_id,
        comments.thread_source_id,
        comments.airport_source_id,
        comments.airport_ident,
        comments.comment_at,
        comments.member_nickname,
        comments.subject,
        comments.body
    from {{ ref('stg_airstats__airport_comments') }} as comments

    {% if is_incremental() %}
        where
            comments.comment_at is null
            or comments.comment_at >= (
                select dateadd(day, -7, coalesce(max(target.comment_at), '1900-01-01'::timestamp_ntz))
                from {{ this }} as target
            )
    {% endif %}

),

deduplicated as (

    select
        airport_comment_source_id,
        thread_source_id,
        airport_source_id,
        airport_ident,
        comment_at,
        member_nickname,
        subject,
        body
    from staged_comments
    qualify row_number() over (
        partition by airport_comment_source_id
        order by
            comment_at desc nulls last,
            thread_source_id desc nulls last
    ) = 1

),

final as (

    select
        airport_comment_source_id,
        thread_source_id,
        airport_source_id,
        airport_ident,
        comment_at,
        member_nickname,
        subject,
        body
    from deduplicated

)

select
    airport_comment_source_id,
    thread_source_id,
    airport_source_id,
    airport_ident,
    comment_at,
    member_nickname,
    subject,
    body
from final
