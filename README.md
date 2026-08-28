# Airline Snowflake dbt Analytics Platform

Production-style analytics engineering portfolio project for airline operations and commercial analytics, centred on Snowflake, dbt, SQL, testing, lineage, and financial control.

## Purpose

This repository is being developed as an airline analytics-engineering platform that can model airport reference data, flights, bookings, ticketing, billing, revenue, reconciliation, and commercial reporting in later milestones.

Milestone 1 established the repository foundation. Milestone 2 adds AirStats raw-data conventions and dbt source metadata only; it does not yet include staging models, synthetic airline data, billing models, marts, dashboards, or Snowflake deployment.

## Core Stack

- Snowflake for the analytical warehouse
- dbt Core with the Snowflake adapter for SQL transformation
- SQLFluff for Snowflake/dbt SQL linting
- Python tooling for local development checks
- GitHub Actions for credential-free CI foundation

## Intended Analytical Flow

AirStats airport/runway reference -> routes and flights -> bookings and tickets -> fares/products/services -> invoices and payments -> refunds and adjustments -> revenue recognition -> balances and billing exceptions -> reconciliation -> commercial reporting.

## Repository Structure

- `models/`: dbt model layers: staging, intermediate, core, and marts
- `macros/`, `snapshots/`, `seeds/`, `analyses/`: standard dbt project areas
- `data/`: raw, synthetic, seed, and sample data landing areas for local development artifacts
- `tests/`: generic, singular, reconciliation, business-rule, and source-quality tests
- `docs/`: architecture, glossary, data-model, billing, reconciliation, runbook, and decision records
- `.github/workflows/`: CI checks that can run without live Snowflake credentials

## Current Status

Implementation status:

- Milestone 1 - complete
- Milestone 2 - complete
- Milestone 3 and later milestones - planned

Implemented:

- dbt project configuration with logical modelling layers
- dependency and Python development configuration
- Snowflake profile example using environment variables only
- SQLFluff and pre-commit configuration
- GitHub Actions foundation for static validation
- initial architecture, development standards, and ADR documentation
- AirStats raw-data convention for airport-reference CSV sources
- dbt source metadata and source-level tests for AirStats raw tables

Not yet implemented:

- AirStats staging models or Snowflake ingestion automation
- airline operational or commercial models
- billing, revenue-recognition, reconciliation, or mart logic
- credential-backed Snowflake dbt runs
- dashboards or reporting outputs

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

## Roadmap

1. Repository Foundation - complete
2. AirStats Source Setup - complete
3. AirStats Staging Layer - planned
4. Airline Operational Source Modelling
5. Bookings, Ticketing, and Commercial Data Modelling
6. Billing, Revenue Recognition, and Reconciliation Controls
7. Core Dimensions and Facts
8. Commercial Marts and Reporting Outputs
9. Documentation, Quality Gates, and Portfolio Polish
