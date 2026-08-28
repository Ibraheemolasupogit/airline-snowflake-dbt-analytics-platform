with airport_versions as (

    select
        ident as business_key,
        dbt_scd_id,
        dbt_valid_from,
        coalesce(dbt_valid_to, cast('9999-12-31' as timestamp_ntz)) as dbt_valid_to
    from {{ ref('snap_airports') }}

),

overlapping_airport_versions as (

    select
        'snap_airports' as snapshot_name,
        current_version.business_key,
        current_version.dbt_scd_id as current_dbt_scd_id,
        compared_version.dbt_scd_id as compared_dbt_scd_id
    from airport_versions as current_version
    inner join airport_versions as compared_version
        on
            current_version.business_key = compared_version.business_key
            and current_version.dbt_scd_id < compared_version.dbt_scd_id
            and current_version.dbt_valid_from < compared_version.dbt_valid_to
            and current_version.dbt_valid_to > compared_version.dbt_valid_from

),

runway_versions as (

    select
        cast(runway_source_id as varchar) as business_key,
        dbt_scd_id,
        dbt_valid_from,
        coalesce(dbt_valid_to, cast('9999-12-31' as timestamp_ntz)) as dbt_valid_to
    from {{ ref('snap_runways') }}

),

overlapping_runway_versions as (

    select
        'snap_runways' as snapshot_name,
        current_version.business_key,
        current_version.dbt_scd_id as current_dbt_scd_id,
        compared_version.dbt_scd_id as compared_dbt_scd_id
    from runway_versions as current_version
    inner join runway_versions as compared_version
        on
            current_version.business_key = compared_version.business_key
            and current_version.dbt_scd_id < compared_version.dbt_scd_id
            and current_version.dbt_valid_from < compared_version.dbt_valid_to
            and current_version.dbt_valid_to > compared_version.dbt_valid_from

),

final as (

    select
        snapshot_name,
        business_key,
        current_dbt_scd_id,
        compared_dbt_scd_id
    from overlapping_airport_versions

    union all

    select
        snapshot_name,
        business_key,
        current_dbt_scd_id,
        compared_dbt_scd_id
    from overlapping_runway_versions

)

select
    snapshot_name,
    business_key,
    current_dbt_scd_id,
    compared_dbt_scd_id
from final
