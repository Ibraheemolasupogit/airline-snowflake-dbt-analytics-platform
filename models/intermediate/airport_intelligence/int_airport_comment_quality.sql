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
        subject,
        body
    from {{ ref('stg_airstats__airport_comments') }}

),

comment_quality as (

    select
        airport_ident,
        count(airport_comment_source_id) as comment_count,
        count_if(body is null) as comments_missing_text_count,
        count_if(comment_at is null) as comments_missing_timestamp_count,
        count_if(
            airport_comment_source_id is not null
            and airport_ident is not null
            and comment_at is not null
            and body is not null
        ) as complete_comment_record_count,
        count_if(thread_source_id is null) as comments_missing_thread_count,
        count_if(member_nickname is null) as comments_missing_member_count,
        count_if(subject is null) as comments_missing_subject_count
    from comments
    group by airport_ident

),

scored as (

    select
        airports.airport_source_id,
        airports.ident,
        coalesce(comment_quality.comment_count, 0) as comment_count,
        coalesce(comment_quality.comments_missing_text_count, 0) as comments_missing_text_count,
        coalesce(comment_quality.comments_missing_timestamp_count, 0) as comments_missing_timestamp_count,
        coalesce(comment_quality.complete_comment_record_count, 0) as complete_comment_record_count,
        coalesce(comment_quality.comments_missing_thread_count, 0) as comments_missing_thread_count,
        coalesce(comment_quality.comments_missing_member_count, 0) as comments_missing_member_count,
        coalesce(comment_quality.comments_missing_subject_count, 0) as comments_missing_subject_count
    from airports
    left join comment_quality
        on airports.ident = comment_quality.airport_ident

),

final as (

    select
        airport_source_id,
        ident,
        comment_count,
        comments_missing_text_count,
        comments_missing_timestamp_count,
        complete_comment_record_count,
        comments_missing_thread_count,
        comments_missing_member_count,
        comments_missing_subject_count,
        case
            when comment_count = 0 then null
            else complete_comment_record_count / nullif(comment_count, 0)
        end as complete_comment_record_ratio,
        case
            when comment_count = 0 then 'no_comments'
            when complete_comment_record_count = comment_count then 'complete'
            when complete_comment_record_count > 0 then 'partially_complete'
            else 'incomplete'
        end as comment_completeness_status
    from scored

)

select
    airport_source_id,
    ident,
    comment_count,
    comments_missing_text_count,
    comments_missing_timestamp_count,
    complete_comment_record_count,
    comments_missing_thread_count,
    comments_missing_member_count,
    comments_missing_subject_count,
    complete_comment_record_ratio,
    comment_completeness_status
from final
