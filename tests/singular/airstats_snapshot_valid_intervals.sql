with invalid_airport_intervals as (

    select
        'snap_airports' as snapshot_name,
        ident as business_key,
        dbt_valid_from,
        dbt_valid_to
    from {{ ref('snap_airports') }}
    where dbt_valid_to < dbt_valid_from

),

invalid_runway_intervals as (

    select
        'snap_runways' as snapshot_name,
        cast(runway_source_id as varchar) as business_key,
        dbt_valid_from,
        dbt_valid_to
    from {{ ref('snap_runways') }}
    where dbt_valid_to < dbt_valid_from

),

final as (

    select
        snapshot_name,
        business_key,
        dbt_valid_from,
        dbt_valid_to
    from invalid_airport_intervals

    union all

    select
        snapshot_name,
        business_key,
        dbt_valid_from,
        dbt_valid_to
    from invalid_runway_intervals

)

select
    snapshot_name,
    business_key,
    dbt_valid_from,
    dbt_valid_to
from final
