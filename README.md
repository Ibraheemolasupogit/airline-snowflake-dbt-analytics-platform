# Airline Snowflake dbt Analytics Platform

Production-style analytics engineering portfolio project for airline operations and commercial analytics, centred on Snowflake, dbt, SQL, testing, lineage, and financial control.

## Purpose

This repository is being developed as an airline analytics-engineering platform that can model airport reference data, flights, bookings, ticketing, billing, revenue, reconciliation, and commercial reporting in later milestones.

Milestone 1 established the repository foundation. Milestone 2 added AirStats raw-data conventions and dbt source metadata. Milestone 3 added AirStats staging views. Milestone 4 added AirStats intermediate transformations. Milestone 5 added an AirStats incremental airport-comments model. Milestone 6 added AirStats SCD Type 2 snapshots. Milestone 7 added AirStats testing and assurance. Milestone 8 completed the AirStats capstone with consumption-ready marts, reusable `doc()` blocks, curated analyses, and capstone completion evidence. Milestone 9 adds a deterministic synthetic airline operational/commercial source dataset — airlines, aircraft, routes, flights, bookings, tickets, fares, invoices, payments, and refunds — that later milestones will model. It does not add airline dbt staging models, core dimensions/facts, booking/pricing/billing transformations, revenue recognition, reconciliation, commercial marts, dashboards, or Snowflake deployment — those remain planned for later milestones.

See `reports/airstats_capstone_summary.md` for a concise AirStats capstone summary, `docs/data_models/airstats_capstone_completion_evidence.md` for the full AirStats requirement-to-file mapping, and `docs/data_models/airline_synthetic_source_data.md` for the Milestone 9 synthetic-data design.

## Core Stack

- Snowflake for the analytical warehouse
- dbt Core with the Snowflake adapter for SQL transformation
- SQLFluff for Snowflake/dbt SQL linting
- Python tooling for local development checks
- GitHub Actions for credential-free CI foundation

## Intended Analytical Flow

AirStats airport/runway reference -> routes and flights -> bookings and tickets -> fares/products/services -> invoices and payments -> refunds and adjustments -> revenue recognition -> balances and billing exceptions -> reconciliation -> commercial reporting.

## Repository Structure

- `models/`: dbt model layers: staging, intermediate, core, and marts (AirStats marts under `models/marts/airport_operations/`); reusable `doc()` blocks live in `models/docs/`
- `macros/`, `snapshots/`, `seeds/`, `analyses/`: standard dbt project areas (AirStats analyses under `analyses/`)
- `data/`: raw, synthetic, seed, and sample data landing areas; `data/synthetic/` holds the generated Milestone 9 airline dataset (reference/operations/bookings/pricing/billing)
- `scripts/`: standard-library Python tooling, including `generate_airline_data.py`, `generate_control_totals.py`, and `validate_source_data.py`
- `tests/`: generic, singular, reconciliation, business-rule, and source-quality dbt tests, plus lightweight Python tests under `tests/python/`
- `docs/`: architecture, glossary, data-model, billing, reconciliation, runbook, and decision records
- `reports/`: portfolio-facing summary reports, such as `airstats_capstone_summary.md`
- `.github/workflows/`: CI checks that can run without live Snowflake credentials

## Current Status

Implementation status:

- Milestone 1 - complete
- Milestone 2 - complete
- Milestone 3 - complete
- Milestone 4 - complete
- Milestone 5 - complete
- Milestone 6 - complete
- Milestone 7 - complete
- Milestone 8 - complete
- Milestone 9 - complete
- Milestone 10 and later milestones - planned

Implemented (AirStats capstone, Milestones 1-8):

- dbt project configuration with logical modelling layers
- dependency and Python development configuration
- Snowflake profile example using environment variables only
- SQLFluff and pre-commit configuration
- GitHub Actions foundation for static validation
- initial architecture, development standards, and ADR documentation
- AirStats raw-data convention for airport-reference CSV sources
- dbt source metadata and source-level tests for AirStats raw tables
- AirStats staging views with typing, minimal cleanup, and lineage-preserving identifiers
- AirStats intermediate transformations for geography, runway profile, source-derived status, comment activity, comment quality, and runway capability
- AirStats incremental airport-comments model using comment timestamp watermarking and merge semantics
- AirStats SCD Type 2 snapshot definitions for airport and runway reference history
- AirStats testing and assurance checks with targeted stored-failure configuration (184 discoverable dbt data tests)
- AirStats consumption-ready marts under `models/marts/airport_operations/`: capacity profile, runway capability, geographic coverage, operational status, comment activity, and data quality
- reusable dbt `doc()` blocks in `models/docs/_airstats_docs.md`, referenced from model/snapshot YAML
- curated AirStats analysis queries under `analyses/`
- capstone completion evidence (`docs/data_models/airstats_capstone_completion_evidence.md`) and summary report (`reports/airstats_capstone_summary.md`)

Implemented (Milestone 9, synthetic airline source data):

- a deterministic synthetic-data generator (`scripts/generate_airline_data.py`) covering all 31 entities across reference/operations, passenger/booking, products/pricing, and billing/payments domains — standard library only, fixed seed, no live Snowflake connection
- an AirStats-consistent airport-reference fixture used by routes, flight schedules, flight instances, ticket segments, and airport fees
- a documented catalogue of 14 deliberately injected data-quality/financial-control exceptions with a machine-readable manifest (`data/synthetic/exception_manifest.csv`)
- synthetic source-level control totals (`scripts/generate_control_totals.py`, `data/synthetic/control_totals.json`)
- an offline validator (`scripts/validate_source_data.py`) and pytest suite (`tests/python/`) that check keys, relationships, currencies, exception fingerprints, and generator determinism without dbt or Snowflake
- full design documentation (`docs/data_models/airline_synthetic_source_data.md`, `docs/data_models/airline_synthetic_exception_catalogue.md`)

Planned (Milestone 10 onward):

- airline dbt staging models and core dimensions/facts
- booking-lifecycle, pricing, and billing transformations
- invoices, payments, refunds, and adjustments modelling
- revenue recognition
- outstanding balances and billing exceptions
- reconciliation controls
- commercial reporting marts
- credential-backed Snowflake dbt runs, `dbt docs generate`, and dashboards

## Local Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
dbt deps
dbt parse --profiles-dir .
pre-commit install
pre-commit run --all-files
```

For local dbt connectivity, copy `profiles.example.yml` to the ignored local `profiles.yml` file or to another private dbt profile location:

```bash
cp profiles.example.yml profiles.yml
export SNOWFLAKE_ACCOUNT="<account_identifier>"
export SNOWFLAKE_USER="<user>"
export SNOWFLAKE_ROLE="<role>"
export SNOWFLAKE_WAREHOUSE="<warehouse>"
export SNOWFLAKE_DATABASE="<database>"
export SNOWFLAKE_SCHEMA="<schema>"
export SNOWFLAKE_PRIVATE_KEY_PATH="<local_private_key_path>"
dbt parse --profiles-dir .
```

Real credentials, private keys, local profiles, and environment files must not be committed.

To regenerate the synthetic airline dataset and validate it offline:

```bash
python scripts/generate_airline_data.py
python scripts/generate_control_totals.py
python scripts/validate_source_data.py
python -m pytest tests/python
```

## Roadmap

1. Repository Foundation - complete
2. AirStats Source Setup - complete
3. AirStats Staging Layer - complete
4. AirStats Transformations - complete
5. AirStats Incremental Airport Comments - complete
6. AirStats SCD Type 2 Snapshots - complete
7. AirStats Testing and Assurance - complete
8. AirStats Documentation, Analysis Queries, Airport Marts, and Capstone Completion Evidence - complete
9. Synthetic Airline Data Foundation - complete
10. Airline Staging Models - planned
11. Core Airline Operations Model - planned
12. Booking and Ticketing - planned
13. Products, Services, Prices and Tariffs - planned
14. Invoices and Invoice Lines - planned
15. Payments and Failed Payments - planned
16. Refunds and Adjustments - planned
17. Revenue Recognition - planned
18. Outstanding Balances and Billing Exceptions - planned
19. Reconciliation Controls - planned
20. Commercial Reporting Marts - planned
21. Production dbt Engineering - planned
22. Final Portfolio Polish - planned
