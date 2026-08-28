# AirStats Capstone Completion Evidence

## Purpose

This document maps the original AirStats capstone requirements to the repository files that
implement them, and states plainly what is offline-validated versus what requires live Snowflake
execution. It covers Milestones 2-8 only. It does not cover synthetic airline data, bookings,
billing, revenue, reconciliation, or commercial reporting, which remain planned for Milestone 9
onward.

## Requirement-to-File Mapping

### Snowflake-oriented AirStats sources

- Raw schema convention: `RAW_AIRSTATS`, documented in `models/staging/airstats/_airstats_sources.yml`
  (source `meta.raw_data_path`, `meta.source_provenance`) and `docs/data_models/airstats_sources.md`.
- Source tables: `models/staging/airstats/_airstats_sources.yml` defines `airports`, `runways`,
  `airport_comments`, `countries`, `regions` with column-level tests.

### Airports

- Source: `models/staging/airstats/_airstats_sources.yml` (`airstats.airports`).
- Staging (bronze equivalent): `models/staging/airstats/stg_airstats__airports.sql`.
- Intermediate (silver equivalent): `models/intermediate/airport_intelligence/int_airport_geography.sql`,
  `int_airport_runway_profile.sql`, `int_airport_operational_status.sql`.
- Snapshot: `snapshots/airstats/snap_airports.sql`.
- Marts: `models/marts/airport_operations/mart_airport_capacity_profile.sql`,
  `mart_airport_geographic_coverage.sql`, `mart_airport_operational_status.sql`.

### Runways

- Source: `models/staging/airstats/_airstats_sources.yml` (`airstats.runways`).
- Staging: `models/staging/airstats/stg_airstats__runways.sql`.
- Intermediate: `models/intermediate/airport_intelligence/int_runway_capability.sql`,
  `int_airport_runway_profile.sql`.
- Snapshot: `snapshots/airstats/snap_runways.sql`.
- Mart: `models/marts/airport_operations/mart_airport_runway_capability.sql`.

### Airport comments

- Source: `models/staging/airstats/_airstats_sources.yml` (`airstats.airport_comments`).
- Staging: `models/staging/airstats/stg_airstats__airport_comments.sql`.
- Intermediate: `models/intermediate/airport_intelligence/int_airport_comment_activity.sql`,
  `int_airport_comment_quality.sql`.
- Incremental model: `models/intermediate/airport_intelligence/int_airport_comments_incremental.sql`.
- Marts: `models/marts/airport_operations/mart_airport_comment_activity.sql`,
  `mart_airport_data_quality.sql`.

### Staging/bronze equivalent

- All five files under `models/staging/airstats/`, documented in
  `models/staging/airstats/_airstats_staging.yml` and `docs/data_models/airstats_sources.md`.

### Intermediate/silver equivalent

- All six files under `models/intermediate/airport_intelligence/`, documented in
  `models/intermediate/airport_intelligence/_airport_intelligence.yml`.

### Incremental model

- `models/intermediate/airport_intelligence/int_airport_comments_incremental.sql`: incremental
  materialization, Snowflake `merge` strategy, unique key `airport_comment_source_id`, `comment_at`
  watermark with a seven-day lookback, null-timestamp reprocessing, `on_schema_change: append_new_columns`.
  Strategy documented via the `incremental_airport_comments_strategy` doc block in
  `models/docs/_airstats_docs.md`.

### Airport snapshot

- `snapshots/airstats/snap_airports.sql`: `check` strategy, unique key `ident`,
  `invalidate_hard_deletes=True`.

### Runway snapshot

- `snapshots/airstats/snap_runways.sql`: `check` strategy, unique key `runway_source_id`,
  `invalidate_hard_deletes=True`.

### Generic tests

- Present throughout `models/staging/airstats/_airstats_staging.yml`,
  `models/intermediate/airport_intelligence/_airport_intelligence.yml`,
  `snapshots/airstats/_airstats_snapshots.yml`, and
  `models/marts/airport_operations/_airport_operations.yml`: `not_null`, `unique`, `accepted_values`,
  numeric range checks.

### Relationship tests

- Cross-model `relationships` tests in the same YAML files above, for example
  `stg_airstats__runways.airport_ident -> stg_airstats__airports.ident` and every AirStats mart's
  `ident`/`airport_ident`/`runway_source_id` back to its staging natural key.

### Singular tests

- `tests/business_rules/airstats_airport_runway_profile_count_consistency.sql`
- `tests/data_quality/airstats_comment_quality_ratio_consistency.sql`
- `tests/incremental_integrity/airstats_incremental_comments_no_duplicate_keys.sql`
- `tests/incremental_integrity/airstats_incremental_comments_timestamp_sanity.sql`
- `tests/referential_integrity/airstats_intermediate_geography_reference_join_integrity.sql`
- `tests/singular/airstats_snapshot_valid_intervals.sql`
- `tests/snapshot_integrity/airstats_snapshots_active_version_uniqueness.sql`
- `tests/snapshot_integrity/airstats_snapshots_no_overlapping_intervals.sql`
- `tests/source_quality/airstats_staging_required_business_keys.sql`

### dbt-expectations

- `packages.yml` pins `metaplane/dbt_expectations`. Used for coordinate bounds, positive
  measurement checks, non-negative aggregate counts, and ratio bounds across staging, intermediate,
  and mart YAML (for example `dbt_expectations.expect_column_values_to_be_between` on
  `mart_airport_capacity_profile.runway_count` and `mart_airport_data_quality.complete_comment_record_ratio`).

### Stored failures

- `dbt_project.yml` sets `store_failures: true` and `+schema: DBT_TEST_FAILURES` for the
  `business_rules`, `data_quality`, `incremental_integrity`, `referential_integrity`, `singular`,
  `snapshot_integrity`, and `source_quality` test folders.

### dbt documentation

- Model, snapshot, and source YAML descriptions across every AirStats layer, including the new
  `models/marts/airport_operations/_airport_operations.yml`.
- Narrative docs: `docs/data_models/airstats_sources.md`,
  `docs/data_models/airstats_testing_assurance.md`, `docs/architecture/overview.md`.

### `doc()` blocks

- `models/docs/_airstats_docs.md` defines `airstats_overview`, `airport_identifier`,
  `runway_capability_definition`, `snapshot_semantics`, `incremental_airport_comments_strategy`, and
  `airstats_assurance_strategy`.
- Referenced from `snapshots/airstats/_airstats_snapshots.yml`,
  `models/intermediate/airport_intelligence/_airport_intelligence.yml`, and
  `models/marts/airport_operations/_airport_operations.yml`.

### Analysis queries

- `analyses/airstats_airport_capacity_analysis.sql`
- `analyses/airstats_runway_capability_analysis.sql`
- `analyses/airstats_data_quality_analysis.sql`
- `analyses/airstats_comment_activity_analysis.sql`

### Generated-doc readiness

- All models, snapshots, sources, and columns carry `description` fields, including `doc()`
  references, so `dbt docs generate` would produce a populated documentation site once run against
  a real warehouse connection. This repository does not run `dbt docs generate` because that
  requires a live Snowflake connection to resolve catalog metadata.

### GitHub/CI delivery

- `.github/workflows/ci.yml` runs YAML validation, `dbt deps`, `dbt parse`, `dbt ls --resource-type test`,
  and offline `sqlfluff lint` on every pull request and push to `main`, without live Snowflake
  credentials.

## Implemented and Offline Validated

- `dbt deps`: package installation succeeds (`dbt_utils`, `dbt_expectations`, transitive `dbt_date`).
- `dbt parse`: the full project, including the six new marts and `doc()` blocks, parses without
  error using placeholder Snowflake environment variables.
- `dbt ls --resource-type model` / `--resource-type test`: resource discovery succeeds; see counts
  below.
- YAML validation: every project YAML file (excluding `target`, `dbt_packages`, and local caches)
  parses as valid YAML.
- SQLFluff: `sqlfluff lint --dialect snowflake --templater jinja models tests analyses macros` and
  the equivalent snapshot invocation report no offline-detectable style violations.
- `git diff --check`: no whitespace errors introduced.
- Secret scan: no private keys, passwords, or API-key-shaped strings found in the diff.
- Applicable pre-commit hooks (`trailing-whitespace`, `end-of-file-fixer`, `check-yaml`,
  `check-added-large-files`, `check-merge-conflict`, `mixed-line-ending`) pass on every changed file.

## Requires Live Snowflake Execution (Not Claimed)

- `dbt run` / `dbt build` for any AirStats model or mart.
- `dbt test` execution and materialization of failing rows into `DBT_TEST_FAILURES`.
- `dbt snapshot` execution for `snap_airports` / `snap_runways`.
- `dbt docs generate` and hosted documentation catalog metadata.
- `dbt compile` for a specific model beyond parse (dbt 1.9 attempts a warehouse connection during
  compile's node-selection phase; this fails offline with the placeholder private-key path, which
  is the same documented limitation noted for the dbt SQLFluff templater in Milestone 7).
- Any query result, row count, or data value from `RAW_AIRSTATS`.

## Resource Counts (as of this milestone, offline `dbt ls`)

- Models: 18 (5 staging, 7 intermediate, 6 marts).
- Snapshots: 2.
- Analyses: 4.
- Sources: 5 tables under 1 source (`airstats`).
- Data tests: 184 total - 9 singular test files plus 175 generic/relationship schema tests
  generated from YAML, an increase of 58 generic tests contributed by the new marts.

## Judgement

The AirStats foundation is functionally complete for local validation without live Snowflake
credentials: source-to-mart lineage, incremental processing, SCD history, assurance testing,
documentation, and analysis queries are all present and offline-validated. It is not "deployed" in
the sense of having run against a real Snowflake account, and no claim to that effect is made
anywhere in this repository.
