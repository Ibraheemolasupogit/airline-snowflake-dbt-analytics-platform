# Documentation Index

The root `README.md` is the public project overview. Everything below is the detailed technical
reference it links out to.

## Architecture

- [`architecture/overview.md`](architecture/overview.md) -- layers, the AirStats conformance role, control principles.
- [`architecture/development_standards.md`](architecture/development_standards.md) -- naming conventions, layer responsibilities, testing/documentation/incremental/financial-control standards.

## Data Models

One design document per business domain, in build order. Each covers grain/key decisions,
sign conventions, and an explicit scope boundary at the time it was written.

- [`data_models/airstats_sources.md`](data_models/airstats_sources.md) -- AirStats raw source layer.
- [`data_models/airstats_testing_assurance.md`](data_models/airstats_testing_assurance.md) -- AirStats testing/assurance design.
- [`data_models/airstats_capstone_completion_evidence.md`](data_models/airstats_capstone_completion_evidence.md) -- AirStats capstone requirement-to-file mapping.
- [`data_models/airline_synthetic_source_data.md`](data_models/airline_synthetic_source_data.md) -- the deterministic synthetic-data generator design.
- [`data_models/airline_synthetic_exception_catalogue.md`](data_models/airline_synthetic_exception_catalogue.md) -- the 14 controlled data-quality/financial-control exceptions.
- [`data_models/airline_staging_layer.md`](data_models/airline_staging_layer.md) -- source/staging layer design.
- [`data_models/airline_core_operations.md`](data_models/airline_core_operations.md) -- routes, airlines, aircraft, flight schedules/instances.
- [`data_models/airline_booking_ticketing.md`](data_models/airline_booking_ticketing.md) -- bookings, passengers, tickets, journeys.
- [`data_models/airline_pricing_tariffs.md`](data_models/airline_pricing_tariffs.md) -- fares, taxes, airport fees, discounts, ancillaries, currency handling.
- [`data_models/airline_invoices.md`](data_models/airline_invoices.md) -- invoice/invoice-line architecture and pricing-to-invoice comparison.
- [`data_models/airline_payments.md`](data_models/airline_payments.md) -- payment attempts, successful payments, allocation.
- [`data_models/airline_refunds_adjustments.md`](data_models/airline_refunds_adjustments.md) -- refunds, adjustments, credit notes.
- [`data_models/airline_revenue_recognition.md`](data_models/airline_revenue_recognition.md) -- fulfilment-driven recognition policy.
- [`data_models/airline_outstanding_balances_exceptions.md`](data_models/airline_outstanding_balances_exceptions.md) -- balance formula and the 14-type exception-detection framework.
- [`data_models/airline_reconciliation_controls.md`](data_models/airline_reconciliation_controls.md) -- source-to-warehouse reconciliation, business-anomaly-vs-ETL-failure distinction.
- [`data_models/airline_commercial_marts.md`](data_models/airline_commercial_marts.md) -- commercial mart architecture, KPI definitions, currency handling, the profitability exclusion.

## Engineering

- [`engineering/dbt_production_engineering.md`](engineering/dbt_production_engineering.md) -- contracts, incremental strategy, snapshot strategy, source-freshness decision, macro policy, exposures, metric governance, offline-vs-warehouse CI, state/defer, artifact handling, test governance, performance considerations.

## Business Metrics

- [`business_glossary/metric_definitions.md`](business_glossary/metric_definitions.md) -- the governed metric-definition convention (ten metrics, each pinned to its exact source column and currency-handling rule).

## Runbooks

- [`runbooks/dbt_production_runbook.md`](runbooks/dbt_production_runbook.md) -- environment setup, every dbt command, full-refresh, incremental/snapshot recovery, state/defer usage, CI artifact review, rollback principles.

## Decisions

- [`decisions/0001-platform-focus.md`](decisions/0001-platform-focus.md) -- why this repository stays focused on Snowflake/dbt/SQL analytics engineering rather than expanding into ML, orchestration, or infrastructure tooling.

## Reports and Evidence

Not documentation, but the concrete offline evidence this platform produces -- see the root
README's "Analytical Outputs" section, or browse directly:

- [`../reports/`](../reports/) -- analytical summary reports (reconciliation, payment/refund assurance, revenue recognition).
- [`../outputs/`](../outputs/) -- offline reconciliation-evidence CSV fixtures.
