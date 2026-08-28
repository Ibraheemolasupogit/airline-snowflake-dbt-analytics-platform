-- Mirrors tests/snapshot_integrity/airstats_snapshots_no_overlapping_intervals.sql for the four
-- Milestone 21 airline snapshots: no business key may have two versions with overlapping
-- [dbt_valid_from, dbt_valid_to) intervals.
with fare_rule_versions as (

    select
        fare_rule_id as business_key,
        dbt_scd_id,
        dbt_valid_from,
        coalesce(dbt_valid_to, cast('9999-12-31' as timestamp_ntz)) as dbt_valid_to
    from {{ ref('snap_fare_rules') }}

),

overlapping_fare_rule_versions as (

    select
        'snap_fare_rules' as snapshot_name,
        current_version.business_key,
        current_version.dbt_scd_id as current_dbt_scd_id,
        compared_version.dbt_scd_id as compared_dbt_scd_id
    from fare_rule_versions as current_version
    inner join fare_rule_versions as compared_version
        on
            current_version.business_key = compared_version.business_key
            and current_version.dbt_scd_id < compared_version.dbt_scd_id
            and current_version.dbt_valid_from < compared_version.dbt_valid_to
            and current_version.dbt_valid_to > compared_version.dbt_valid_from

),

airport_fee_versions as (

    select
        airport_fee_id as business_key,
        dbt_scd_id,
        dbt_valid_from,
        coalesce(dbt_valid_to, cast('9999-12-31' as timestamp_ntz)) as dbt_valid_to
    from {{ ref('snap_airport_fees') }}

),

overlapping_airport_fee_versions as (

    select
        'snap_airport_fees' as snapshot_name,
        current_version.business_key,
        current_version.dbt_scd_id as current_dbt_scd_id,
        compared_version.dbt_scd_id as compared_dbt_scd_id
    from airport_fee_versions as current_version
    inner join airport_fee_versions as compared_version
        on
            current_version.business_key = compared_version.business_key
            and current_version.dbt_scd_id < compared_version.dbt_scd_id
            and current_version.dbt_valid_from < compared_version.dbt_valid_to
            and current_version.dbt_valid_to > compared_version.dbt_valid_from

),

tax_versions as (

    select
        tax_id as business_key,
        dbt_scd_id,
        dbt_valid_from,
        coalesce(dbt_valid_to, cast('9999-12-31' as timestamp_ntz)) as dbt_valid_to
    from {{ ref('snap_taxes') }}

),

overlapping_tax_versions as (

    select
        'snap_taxes' as snapshot_name,
        current_version.business_key,
        current_version.dbt_scd_id as current_dbt_scd_id,
        compared_version.dbt_scd_id as compared_dbt_scd_id
    from tax_versions as current_version
    inner join tax_versions as compared_version
        on
            current_version.business_key = compared_version.business_key
            and current_version.dbt_scd_id < compared_version.dbt_scd_id
            and current_version.dbt_valid_from < compared_version.dbt_valid_to
            and current_version.dbt_valid_to > compared_version.dbt_valid_from

),

corporate_account_versions as (

    select
        corporate_account_id as business_key,
        dbt_scd_id,
        dbt_valid_from,
        coalesce(dbt_valid_to, cast('9999-12-31' as timestamp_ntz)) as dbt_valid_to
    from {{ ref('snap_corporate_accounts') }}

),

overlapping_corporate_account_versions as (

    select
        'snap_corporate_accounts' as snapshot_name,
        current_version.business_key,
        current_version.dbt_scd_id as current_dbt_scd_id,
        compared_version.dbt_scd_id as compared_dbt_scd_id
    from corporate_account_versions as current_version
    inner join corporate_account_versions as compared_version
        on
            current_version.business_key = compared_version.business_key
            and current_version.dbt_scd_id < compared_version.dbt_scd_id
            and current_version.dbt_valid_from < compared_version.dbt_valid_to
            and current_version.dbt_valid_to > compared_version.dbt_valid_from

),

final as (

    select * from overlapping_fare_rule_versions
    union all
    select * from overlapping_airport_fee_versions
    union all
    select * from overlapping_tax_versions
    union all
    select * from overlapping_corporate_account_versions

)

select
    snapshot_name,
    business_key,
    current_dbt_scd_id,
    compared_dbt_scd_id
from final
