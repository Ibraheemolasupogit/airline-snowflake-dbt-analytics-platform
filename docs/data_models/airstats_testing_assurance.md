# AirStats Testing and Assurance

## Purpose

Milestone 7 strengthens AirStats assurance across the existing source, staging, intermediate,
incremental, and snapshot layers. It does not add dimensions, facts, marts, dashboards, or
warehouse infrastructure.

## Test Strategy

AirStats tests are organized around these logical categories:

- `source_quality`: source and staging key expectations.
- `referential_integrity`: cross-model relationship and join-integrity checks.
- `business_rules`: deterministic model-level business rules.
- `incremental_integrity`: incremental airport-comment key and watermark checks.
- `snapshot_integrity`: SCD active-version, interval, and overlap checks.
- `data_quality`: derived-ratio and structural quality checks.

Generic schema tests remain the default for simple column guarantees such as not-null, unique,
accepted values, relationships, and numeric ranges. Singular tests are used where the rule spans
rows, models, or SCD intervals.

## dbt-expectations

The project uses `dbt-expectations` selectively for numeric range checks, including coordinate
bounds, positive runway measurements where populated, aggregate count non-negativity, and ratio
bounds. Built-in dbt tests remain in place for simple uniqueness, not-null, relationship, and
accepted-value assertions.

## Snapshot Assurance

Snapshot integrity tests cover `snap_airports` and `snap_runways`:

- active-version uniqueness: at most one `dbt_valid_to is null` version per business key.
- interval validity: `dbt_valid_from` must be populated and `dbt_valid_to` must not precede it.
- overlap detection: historical intervals for the same business key must not overlap, treating a
  null `dbt_valid_to` as the current open-ended interval.

These tests validate warehouse-observed SCD history. They do not assert live operational airport
or runway status.

## Incremental Assurance

`int_airport_comments_incremental` is checked for unique source comment keys, valid airport
relationships, duplicate-key protection after deduplication, and timestamp sanity. The tests do
not require non-null `comment_at` because the incremental design explicitly supports null comment
timestamps.

## Stored Failures

AirStats assurance test folders are configured with `store_failures: true` and logical schema
`DBT_TEST_FAILURES`. This configuration declares where failed rows should be retained during
warehouse-backed `dbt test` execution. No failure tables are created by this milestone because no
live Snowflake execution is performed.

## Offline Validation

Credential-free checks can validate YAML, package installation, dbt parsing, dbt resource
discovery, static SQL style, and secret hygiene. Warehouse-backed `dbt test`, snapshot execution,
and stored-failure table creation require real Snowflake credentials and are intentionally not
claimed by this repository state.
