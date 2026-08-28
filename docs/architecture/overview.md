# Architecture Overview

This repository is designed as a Snowflake and dbt analytics-engineering platform for airline operations and commercial analytics.

The intended analytical flow is:

AirStats airport/runway reference -> routes and flights -> bookings and tickets -> fares/products/services -> invoices and payments -> refunds and adjustments -> revenue recognition -> balances and billing exceptions -> reconciliation -> commercial reporting.

Milestone 2 establishes AirStats as the authoritative raw airport-reference source for later
airport and runway analytical reference modelling. The implemented scope is limited to raw/source
metadata; route, flight, operational, billing, revenue, and commercial models remain planned for
later milestones.

## Layers

- `raw`: Snowflake source schemas such as `RAW_AIRSTATS` that preserve provider-aligned records
  before dbt transformation.
- `staging`: source-aligned models with light cleaning, naming standardisation, type casting, and source quality checks.
- `intermediate`: reusable business transformations, joins, and derived entities that are not final reporting interfaces.
- `core`: governed dimensions and facts with explicit grain, tested keys, and documented lineage.
- `marts`: business-facing reporting models for operations, billing, reconciliation, revenue, and commercial analysis.

## AirStats Source Role

The AirStats source layer supplies airport and runway reference data that later milestones will
prepare for route and flight modelling. Downstream operational and commercial analytics should use
the conformed airport layer once implemented, rather than duplicating airport-reference logic.

## Control Principles

Financial and commercial models must preserve auditable lineage from source records through final reporting outputs. Revenue, balances, invoices, payments, refunds, and adjustments should include reconciliation tests and clear grain declarations when implemented in later milestones.
