-- Mirrors tests/snapshot_integrity/airstats_snapshots_active_version_uniqueness.sql for the four
-- Milestone 21 airline snapshots: every business key must have at most one currently-active
-- (dbt_valid_to is null) version.
with active_fare_rule_versions as (

    select
        'snap_fare_rules' as snapshot_name,
        fare_rule_id as business_key,
        count(*) as active_version_count
    from {{ ref('snap_fare_rules') }}
    where dbt_valid_to is null
    group by fare_rule_id
    having count(*) > 1

),

active_airport_fee_versions as (

    select
        'snap_airport_fees' as snapshot_name,
        airport_fee_id as business_key,
        count(*) as active_version_count
    from {{ ref('snap_airport_fees') }}
    where dbt_valid_to is null
    group by airport_fee_id
    having count(*) > 1

),

active_tax_versions as (

    select
        'snap_taxes' as snapshot_name,
        tax_id as business_key,
        count(*) as active_version_count
    from {{ ref('snap_taxes') }}
    where dbt_valid_to is null
    group by tax_id
    having count(*) > 1

),

active_corporate_account_versions as (

    select
        'snap_corporate_accounts' as snapshot_name,
        corporate_account_id as business_key,
        count(*) as active_version_count
    from {{ ref('snap_corporate_accounts') }}
    where dbt_valid_to is null
    group by corporate_account_id
    having count(*) > 1

),

final as (

    select * from active_fare_rule_versions
    union all
    select * from active_airport_fee_versions
    union all
    select * from active_tax_versions
    union all
    select * from active_corporate_account_versions

)

select
    snapshot_name,
    business_key,
    active_version_count
from final
