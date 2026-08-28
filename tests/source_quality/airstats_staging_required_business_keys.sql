select
    'stg_airstats__airports' as model_name,
    cast(ident as varchar) as business_key
from {{ ref('stg_airstats__airports') }}
where ident is null

union all

select
    'stg_airstats__runways' as model_name,
    cast(runway_source_id as varchar) as business_key
from {{ ref('stg_airstats__runways') }}
where runway_source_id is null or airport_ident is null

union all

select
    'stg_airstats__airport_comments' as model_name,
    cast(airport_comment_source_id as varchar) as business_key
from {{ ref('stg_airstats__airport_comments') }}
where airport_comment_source_id is null or airport_ident is null
