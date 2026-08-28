with active_airport_versions as (

    select
        'snap_airports' as snapshot_name,
        ident as business_key,
        count(*) as active_version_count
    from {{ ref('snap_airports') }}
    where dbt_valid_to is null
    group by ident
    having count(*) > 1

),

active_runway_versions as (

    select
        'snap_runways' as snapshot_name,
        cast(runway_source_id as varchar) as business_key,
        count(*) as active_version_count
    from {{ ref('snap_runways') }}
    where dbt_valid_to is null
    group by runway_source_id
    having count(*) > 1

),

final as (

    select
        snapshot_name,
        business_key,
        active_version_count
    from active_airport_versions

    union all

    select
        snapshot_name,
        business_key,
        active_version_count
    from active_runway_versions

)

select
    snapshot_name,
    business_key,
    active_version_count
from final
