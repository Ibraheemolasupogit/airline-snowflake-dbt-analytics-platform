# Architecture Overview

This repository is a Snowflake and dbt analytics-engineering platform for airline operations and
commercial analytics, built end to end: airport reference data, flight operations, bookings and
ticketing, pricing, invoicing, payments, refunds and adjustments, fulfilment-driven revenue
recognition, outstanding balances, rule-based billing-exception detection, source-to-warehouse
reconciliation, commercial reporting marts, and production-style dbt engineering (contracts,
incremental models, snapshots, exposures, governed metrics, two-lane CI).

The end-to-end analytical flow:

AirStats airport/runway reference -> routes and flights -> bookings and tickets ->
fares/products/services -> invoices and payments -> refunds and adjustments -> service fulfilment
-> recognised revenue -> outstanding balances -> billing exceptions -> reconciliation ->
commercial reporting.

See the root `README.md` for the public project overview, and `docs/README.md` for the full
documentation index. This document remains the architecture-first reference.

## Layers

- `staging`: source-aligned models with light cleaning, naming standardisation, type casting, and source quality checks.
- `intermediate`: reusable business transformations, joins, and derived entities that are not final reporting interfaces.
- `core`: governed dimensions and facts with explicit grain, tested keys, documented lineage, and (for nine of them) an enforced dbt model contract.
- `marts`: business-facing reporting models for airline/airport operations, passenger and commercial analytics, billing assurance, recognised revenue, and executive summaries.

## AirStats Source Role

AirStats is this project's own conformed layer over real, open OurAirports-style airport/runway
reference data (staged, tested, snapshotted, and exposed as consumption-ready marts under
`models/marts/airport_operations/`). It is the **sole authoritative source** for airport identity
and geography in this platform: `dim_airport` is built directly from the AirStats marts, and every
airline route/hub/operational airport identifier is conformed to it via `int_route_airport_pair`
and `dim_airport` itself. The synthetic airline dataset carries airport identifiers styled the way
AirStats/OurAirports represents them, but the synthetic fixture itself is never treated as an
authoritative airport reference -- only AirStats is.

## Control Principles

Financial and commercial models preserve auditable lineage from source records through final
reporting outputs. Revenue, balances, invoices, payments, refunds, and adjustments carry
reconciliation tests, explicit grain declarations, and (where a model is a governed contract or
an incremental/SCD2 resource) a documented production-engineering rationale -- see
`docs/engineering/dbt_production_engineering.md`.
