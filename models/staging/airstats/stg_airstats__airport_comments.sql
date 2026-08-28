with source as (

    select *
    from {{ source('airstats', 'airport_comments') }}

),

renamed as (

    select
        try_to_number(nullif(trim(cast(id as varchar)), ''), 38, 0) as airport_comment_source_id,
        try_to_number(nullif(trim(cast(thread_ref as varchar)), ''), 38, 0) as thread_source_id,
        try_to_number(nullif(trim(cast(airport_ref as varchar)), ''), 38, 0) as airport_source_id,
        nullif(trim(cast(airport_ident as varchar)), '') as airport_ident,
        try_to_timestamp_ntz(nullif(trim(cast(comment_date as varchar)), '')) as comment_at,
        nullif(trim(cast(member_nickname as varchar)), '') as member_nickname,
        nullif(trim(cast(subject as varchar)), '') as subject,
        nullif(trim(cast(body as varchar)), '') as body
    from source

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
from renamed
