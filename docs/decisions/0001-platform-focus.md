# ADR 0001: Platform Focus

## Status

Accepted

## Context

The project is intended to demonstrate specialist analytics engineering for airline operations and commercial reporting. The foundation must support realistic data modelling, testing, lineage, and financial-control practices.

## Decision

This repository is intentionally centred on:

- Snowflake
- dbt
- SQL
- analytics engineering
- airline operations
- commercial analytics
- billing and reconciliation

The repository deliberately avoids becoming dominated by:

- machine learning
- Dataiku
- Fabric
- Airflow
- Terraform-heavy infrastructure
- feature stores
- multi-cloud architecture

## Consequences

Design choices should prioritise dbt modelling quality, Snowflake-oriented SQL, testability, documentation, lineage, and business controls. Supporting tools may be added later, but they should not dilute the core analytics-engineering focus.
