{% docs airstats_overview %}
AirStats is the conformed airport and runway reference foundation for this platform. It is
sourced from public-domain OurAirports-style CSV extracts landed in the `RAW_AIRSTATS` Snowflake
schema, then modelled through dbt sources, staging, intermediate transformations, an incremental
airport-comments model, and SCD Type 2 snapshots before being exposed through the AirStats marts
in `models/marts/airport_operations/`. All AirStats attributes are source-derived analytical
descriptions of reference data; they are not live operational status, regulatory approval, or
real-time flight-suitability conclusions.
{% enddocs %}

{% docs airport_identifier %}
The AirStats airport natural identifier (`ident`). It is the stable public airport code used to
join airports to runways, airport comments, and every downstream AirStats intermediate model,
snapshot, and mart. It is distinct from `airport_source_id`, which is the provider's internal
persistent identifier retained purely for source lineage.
{% enddocs %}

{% docs runway_capability_definition %}
Runway capability categories (length, width, surface, and endpoint completeness) are deterministic
buckets derived only from staged AirStats runway attributes. They describe the shape of the source
data, not runway certification, regulatory approval, landing clearance, or aircraft compatibility.
{% enddocs %}

{% docs snapshot_semantics %}
AirStats snapshots (`snap_airports`, `snap_runways`) use dbt's `check` strategy because the source
does not expose a trustworthy row-level `updated_at` timestamp. Each snapshot row represents one
historical version of a business key over time, bounded by `dbt_valid_from` and `dbt_valid_to`; a
null `dbt_valid_to` marks the currently active version. `invalidate_hard_deletes=True` means a
business key that disappears from a source load closes its active version rather than deleting
prior history. These are warehouse-observed change records, not confirmation that a real airport
or runway ceased to exist operationally.
{% enddocs %}

{% docs incremental_airport_comments_strategy %}
`int_airport_comments_incremental` merges new and changed AirStats airport comments using
`airport_comment_source_id` as the unique key. Because the source has no reliable update
timestamp, the model watermarks on `comment_at` with a seven-day lookback to tolerate
late-arriving or reloaded rows, and always reprocesses comments with a null `comment_at`. Schema
changes append new columns without dropping existing ones. A full refresh rebuilds the model from
all staged comments; corrected historical comments older than the lookback window require a full
refresh or a deliberately widened lookback to be captured.
{% enddocs %}

{% docs airstats_assurance_strategy %}
AirStats assurance combines generic dbt schema tests (not-null, unique, accepted values,
relationships, numeric ranges via `dbt-expectations`) with singular tests organised into
`source_quality`, `referential_integrity`, `business_rules`, `incremental_integrity`,
`snapshot_integrity`, and `data_quality` folders. Assurance folders are configured with
`store_failures: true` against the logical `DBT_TEST_FAILURES` schema so failing rows can be
retained during warehouse-backed `dbt test` execution. This documents the intended stored-failure
configuration; it does not claim that failure tables already exist without live Snowflake runs.
{% enddocs %}
