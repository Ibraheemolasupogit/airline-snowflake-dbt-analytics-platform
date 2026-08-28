# AirStats Capstone Summary

## What this is

A complete Snowflake + dbt analytics-engineering pipeline for airport and runway reference data,
built end to end: source definitions, staging, reusable transformations, an incremental model, SCD
Type 2 history, assurance testing, consumption-ready marts, documentation, and analysis queries.
This is the first of two capstones in this repository; airline operational, booking, billing, and
revenue data are planned for later milestones (see the README roadmap).

## Pipeline

```text
RAW_AIRSTATS (Snowflake raw schema)
  -> dbt sources (airports, runways, airport_comments, countries, regions)
  -> staging views (typed, cleaned, source-aligned)
  -> intermediate transformations (geography, runway profile, operational status,
     comment activity, comment quality, runway capability)
  -> incremental airport comments (merge, watermarked, 7-day lookback)
  -> SCD Type 2 snapshots (snap_airports, snap_runways)
  -> AirStats marts (models/marts/airport_operations/)
  -> curated analyses (analyses/)
```

## What's implemented

| Layer | Models |
|---|---|
| Sources | 1 source, 5 tables |
| Staging | 5 views |
| Intermediate | 7 models (6 transformations + 1 incremental) |
| Snapshots | 2 (airports, runways) |
| Marts | 6 (`mart_airport_capacity_profile`, `mart_airport_runway_capability`, `mart_airport_geographic_coverage`, `mart_airport_operational_status`, `mart_airport_comment_activity`, `mart_airport_data_quality`) |
| Analyses | 4 curated queries |
| Data tests | 184 (175 generic/relationship + 9 singular), spanning source quality, referential integrity, business rules, incremental integrity, snapshot integrity, and data quality |

Every mart has an explicit grain, a documented primary key, and reuses intermediate logic rather
than duplicating it. Reusable `doc()` blocks (`models/docs/_airstats_docs.md`) keep key concepts —
the airport identifier, runway capability categories, snapshot semantics, the incremental strategy,
and the assurance strategy — defined once and referenced from YAML.

## What's validated, and how

Offline, without live Snowflake credentials: YAML validity, `dbt deps`, `dbt parse`, `dbt ls`
resource discovery, SQLFluff linting (jinja templater), `git diff --check`, a secret scan, and
applicable pre-commit hooks. Full detail and exact commands are in
`docs/data_models/airstats_capstone_completion_evidence.md`.

Not run, and not claimed: `dbt run`, `dbt test`, `dbt snapshot`, `dbt docs generate`, or any query
against a live warehouse. This repository is honest about that boundary throughout.

## Known limitations

- All AirStats "status," "capability," and "quality" attributes are source-derived analytical
  categories — not live operational status, regulatory approval, or certification.
- The AirStats source has no reliable row-level `updated_at`, so snapshots use dbt's `check`
  strategy and the incremental model uses a comment-timestamp watermark with a lookback window
  rather than a true CDC feed.
- No warehouse-backed execution has occurred; row counts, test pass/fail results, and generated
  documentation catalogs do not yet exist.

## Next milestone

Milestone 9 introduces deterministic synthetic airline operational data (airlines, aircraft,
routes, flights, passengers, bookings, tickets, fares, invoices, payments, refunds) that references
the AirStats airport layer as its conformed airport foundation — see the README roadmap for scope.
