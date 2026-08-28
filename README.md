# Airline Snowflake dbt Analytics Platform

Production-style analytics engineering portfolio project for airline operations and commercial analytics, centred on Snowflake, dbt, SQL, testing, lineage, and financial control.

## Purpose

This repository is being developed as an airline analytics-engineering platform that can model airport reference data, flights, bookings, ticketing, billing, revenue, reconciliation, and commercial reporting in later milestones.

Milestone 1 established the repository foundation. Milestone 2 added AirStats raw-data conventions and dbt source metadata. Milestone 3 added AirStats staging views. Milestone 4 added AirStats intermediate transformations. Milestone 5 added an AirStats incremental airport-comments model. Milestone 6 added AirStats SCD Type 2 snapshots. Milestone 7 added AirStats testing and assurance. Milestone 8 completed the AirStats capstone with consumption-ready marts, reusable `doc()` blocks, curated analyses, and capstone completion evidence. Milestone 9 added a deterministic synthetic airline operational/commercial source dataset. Milestone 10 added a dbt source and staging layer over that synthetic dataset — 31 source tables and 31 typed `stg_airline__*` staging views across reference, operations, bookings, pricing, and billing domains — with no business transformation yet. Milestone 11 added the core airline operations model: four `int_*` intermediate transformations, six conformed core dimensions (including the first genuine `dim_airport` join to AirStats), and two core facts (`fct_flight_schedule`, `fct_flight_operations`) covering routes, airlines, aircraft, and flight schedules/instances. Milestone 12 added the booking and ticketing layer: five booking-lifecycle intermediate models, four core dimensions (`dim_passenger`, `dim_booking_channel`, `dim_fare_class`, `dim_cabin`), and four core facts (`fct_bookings`, `fct_booking_passengers`, `fct_ticket_segments`, `fct_passenger_journeys`), plus a deterministic `passengers_carried`/`load_factor` update to `fct_flight_operations`. Milestone 13 added a deterministic pricing/tariff layer: five pricing intermediate models, six core dimensions (`dim_fare_rule`, `dim_tax`, `dim_currency`, `dim_discount`, `dim_service`, `dim_product`), one core fact (`fct_pricing_events`), and a `convert_currency` macro, covering fares, fare rules, taxes, airport charges, discounts, ancillary pricing, and currency handling. Milestone 14 added a trustworthy invoice layer: four billing intermediate models (`int_invoice_status`, `int_invoice_calculation`, `int_invoice_charge_comparison`, `int_invoice_line_validation`) and two core facts (`fct_invoices`, `fct_invoice_lines`), covering invoice/invoice-line structure, an internal header-vs-lines arithmetic control, and an external pricing-vs-invoice comparison against Milestone 13's `fct_pricing_events` — evidence only, with no billing-exception classification yet. Milestone 15 added a reliable payment layer: five billing intermediate models (`int_payment_attempt_classification`, `int_failed_payment_attempts`, `int_invoice_payment_matching`, `int_payment_allocation`, `int_unallocated_payments`), one core dimension (`dim_payment_method`), and two core facts (`fct_payment_attempts`, `fct_payments`), covering payment-attempt classification, invoice matching/allocation, currency/timing evidence, and a provisional `amount_collected`/`payment_count` extension to `fct_invoices` — again evidence only, with no billing-exception classification. Milestone 16 adds a reliable post-payment financial-adjustment layer: four billing intermediate models (`int_refund_payment_matching`, `int_refund_allocation`, `int_adjustment_allocation`, `int_credit_note_application`) and three core facts (`fct_refunds`, `fct_adjustments`, `fct_credit_notes`), covering refund/payment matching, refund-limit evidence, adjustment sign/type evidence, credit-note handling, and a provisional `refund_count`/`refund_amount`/`adjustment_count`/`net_adjustment_amount` extension to `fct_invoices` — again evidence only, with no billing-exception classification. It does not add voucher application, revenue recognition, a final outstanding-balance model, billing-exception classification, reconciliation, commercial marts, dashboards, or Snowflake deployment — those remain planned for later milestones.

See `reports/airstats_capstone_summary.md` for a concise AirStats capstone summary, `docs/data_models/airstats_capstone_completion_evidence.md` for the full AirStats requirement-to-file mapping, `docs/data_models/airline_synthetic_source_data.md` for the Milestone 9 synthetic-data design, `docs/data_models/airline_staging_layer.md` for the Milestone 10 source/staging design, `docs/data_models/airline_core_operations.md` for the Milestone 11 core operations model design, `docs/data_models/airline_booking_ticketing.md` for the Milestone 12 booking/ticketing design, `docs/data_models/airline_pricing_tariffs.md` for the Milestone 13 pricing/tariffs design, `docs/data_models/airline_invoices.md` for the Milestone 14 invoice design, `docs/data_models/airline_payments.md` for the Milestone 15 payment design, and `docs/data_models/airline_refunds_adjustments.md` for the Milestone 16 refund/adjustment design.

## Core Stack

- Snowflake for the analytical warehouse
- dbt Core with the Snowflake adapter for SQL transformation
- SQLFluff for Snowflake/dbt SQL linting
- Python tooling for local development checks
- GitHub Actions for credential-free CI foundation

## Intended Analytical Flow

AirStats airport/runway reference -> routes and flights -> bookings and tickets -> fares/products/services -> invoices and payments -> refunds and adjustments -> revenue recognition -> balances and billing exceptions -> reconciliation -> commercial reporting.

## Repository Structure

- `models/`: dbt model layers: staging, intermediate, core, and marts (AirStats marts under `models/marts/airport_operations/`; airline staging under `models/staging/airline_{reference,operations,bookings,pricing,billing}/`); reusable `doc()` blocks live in `models/docs/`
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
- Milestone 10 - complete
- Milestone 11 - complete
- Milestone 12 - complete
- Milestone 13 - complete
- Milestone 14 - complete
- Milestone 15 - complete
- Milestone 16 - complete
- Milestone 17 and later milestones - planned

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

Implemented (Milestone 10, airline source and staging layer):

- five Snowflake-oriented dbt sources (`airline_reference`, `airline_operations`, `airline_bookings`, `airline_pricing`, `airline_billing`) covering all 31 Milestone 9 entities, documented but not deployed to any live schema
- 31 typed, normalised `stg_airline__*` staging views under `models/staging/airline_{reference,operations,bookings,pricing,billing}/`, following the AirStats casting/naming conventions with fixed-precision decimal amounts (no floats for money)
- 352 new source/staging dbt tests (keys, relationships, accepted values, ranges), deliberately omitted wherever a generic test would fail against a known Milestone 9 exception
- full preservation of all 14 Milestone 9 controlled exceptions through staging — nothing filtered, corrected, or suppressed
- design documentation (`docs/data_models/airline_staging_layer.md`) mapping RAW airline domains through sources to staging, and documenting (without implementing) the future AirStats airport conformance join

Implemented (Milestone 11, core airline operations model):

- four reusable intermediate transformations under `models/intermediate/airline_operations/`: `int_route_airport_pair` (the first genuine airline-to-AirStats join), `int_scheduled_flight_segments`, `int_operated_flight_segments`, and `int_aircraft_route_compatibility`
- six conformed core dimensions under `models/core/dimensions/`: `dim_airport` (built from the existing AirStats marts, the conformance join Milestone 10 documented but did not implement), `dim_airline`, `dim_aircraft_type`, `dim_aircraft`, `dim_route`, and `dim_flight`, each with a surrogate key generated via `dbt_utils.generate_surrogate_key`
- two core facts under `models/core/facts/`: `fct_flight_schedule` (grain: `schedule_id`) and `fct_flight_operations` (grain: `flight_instance_id`), covering operational schedule/instance measures only — no passenger-booking, revenue, or ticketing facts; `passengers_carried`/`load_factor` are structurally present but always null pending Milestone 12 ticket data
- a deterministic `operational_completion_status` recode and a three-valued `is_assigned_aircraft_type_consistent` signal derived from the source's scheduled-vs-actual aircraft type; no delay measures, since the source has no actual/observed timestamps
- one singular business-rule test (`tests/business_rules/airline_route_origin_destination_distinct.sql`) plus column-level generic tests across the new intermediate/core YAML, including cross-domain `relationships` tests into `stg_airstats__airports` and `dim_airport`
- design documentation (`docs/data_models/airline_core_operations.md`) covering grain/key decisions, the AirStats conformance implementation, and delay/completion/load-factor logic

Implemented (Milestone 12, booking and ticketing):

- five reusable intermediate transformations under `models/intermediate/booking_lifecycle/`: `int_booking_current_state`, `int_booking_passengers`, `int_ticketed_segments`, `int_passenger_journey_completion`, and `int_cancelled_bookings`
- four core dimensions: `dim_passenger`, `dim_booking_channel`, `dim_fare_class`, `dim_cabin` (the last two deliberately excluding fare/pricing monetary columns, reserved for Milestone 13)
- four core facts: `fct_bookings`, `fct_booking_passengers`, `fct_ticket_segments`, `fct_passenger_journeys`, plus a deterministic `passengers_carried`/`load_factor` update to `fct_flight_operations` derived from completed ticket segments
- a deterministic `journey_completion_status` derivation (scheduled/completed/cancelled/not_flown/other) reused by both the passenger-journey fact and the flight-operations passenger count
- one singular business-rule test guarding against double-counting a passenger across a round trip's two flight instances, plus column-level generic tests across the new intermediate/core YAML
- design documentation (`docs/data_models/airline_booking_ticketing.md`) covering grain/key decisions, journey-completion semantics, and the controlled-exception interaction with EXC-006

Implemented (Milestone 13, products, services, prices and tariffs):

- five reusable intermediate transformations under `models/intermediate/pricing/`: `int_fare_component_calculation`, `int_tax_calculation`, `int_airport_charge_calculation`, `int_ancillary_charge_calculation`, and `int_booking_charge_components`, all deterministically grounded in `scripts/airline_synth/build_billing.py`'s own ground-truth arithmetic
- six core dimensions: `dim_fare_rule`, `dim_tax`, `dim_currency`, `dim_discount`, `dim_service`, `dim_product` (reusing the existing `dim_fare_class` from Milestone 12)
- one core fact, `fct_pricing_events`: a unified, sign-conventioned charge-component structure (`base_fare`, `distance_fare`, `tax`, `airport_fee`, `ancillary`, `discount`) ready for Milestone 14 invoice-line generation without recalculating pricing
- a narrow `convert_currency` macro using fixed-point `decimal(18, 2)` arithmetic, no floats
- three singular business-rule tests (fare-formula sanity, fixed-point amount consistency, discount-not-exceeding-subtotal), plus column-level generic tests across the new intermediate/core YAML
- design documentation (`docs/data_models/airline_pricing_tariffs.md`) covering the fare formula, tax/airport-fee/discount/ancillary logic, currency handling, the charge-component grain/sign convention, and controlled `incorrect_fare`-exception preservation for a future Milestone 14 exception-detection model

Implemented (Milestone 14, invoices and invoice lines):

- four reusable intermediate transformations under `models/intermediate/billing/`: `int_invoice_status` (current-state status), `int_invoice_calculation` (internal header-vs-lines arithmetic control), `int_invoice_charge_comparison` (external pricing-vs-invoice comparison against Milestone 13's `fct_pricing_events`), and `int_invoice_line_validation` (structural validation signals only)
- two core facts: `fct_invoices` (grain: `invoice_id`) and `fct_invoice_lines` (grain: `invoice_line_id`), each keeping both `source_*` and `calculated_*`/`expected_*` amounts side by side rather than overwriting either, plus a consistently signed `invoice_total_variance`/`pricing_variance_amount`
- a deterministic `reference_code`-based alignment between `fct_pricing_events` and `stg_airline__invoice_lines` (verified against `scripts/airline_synth/build_billing.py`) that lets the pricing-vs-invoice comparison work without a shared ID between the two independently generated tables
- three singular business-rule tests (invoice-arithmetic sanity, fixed-point amount consistency, and a controlled-anomaly-presence guard covering all four invoice-affecting Milestone 9 exceptions), plus column-level generic tests across the new intermediate/core YAML
- evidence only, no classification: no `is_incorrect_fare`, `billing_exception_type`, or `financial_value_at_risk` field exists anywhere in this milestone -- that belongs to Milestone 18
- design documentation (`docs/data_models/airline_invoices.md`) covering the invoice architecture, the pricing-to-invoice relationship, invoice arithmetic, source-vs-calculated totals, variance semantics, and controlled anomaly preservation

Implemented (Milestone 15, payments and failed payments):

- five reusable intermediate transformations under `models/intermediate/billing/`: `int_payment_attempt_classification` (deterministic successful/failed/other classification, plus a declined/insufficient_funds/other failure-reason bucketing), `int_failed_payment_attempts`, `int_invoice_payment_matching` (preserves unmatched payments rather than dropping them), `int_payment_allocation` (least(payment, invoice total) allocation with fixed-point decimal arithmetic), and `int_unallocated_payments`
- one core dimension, `dim_payment_method`, reused across both new facts
- two core facts: `fct_payment_attempts` (grain: `payment_attempt_id`) and `fct_payments` (grain: `payment_id`), plus a provisional `amount_collected`/`payment_count` extension to `fct_invoices` that is explicitly documented as not a final outstanding-balance measure (refunds/adjustments are not yet modelled)
- currency and timing evidence: `is_currency_match` (no conversion attempted) and `payment_delay_days` (no invented "late" threshold, since the source defines none)
- four singular business-rule tests (payment-allocation arithmetic sanity, fixed-point amount consistency, successful-payment-linked-to-successful-attempt consistency, and a controlled-anomaly-presence guard covering all five payment-affecting Milestone 9 exceptions), plus column-level generic tests across the new intermediate/core YAML
- evidence only, no classification: no `billing_exception_type`, `severity`, `financial_value_at_risk`, or `resolution_status` field exists anywhere in this milestone -- that belongs to Milestone 18
- design documentation (`docs/data_models/airline_payments.md`) covering payment-attempt/successful-payment architecture, invoice matching, allocation semantics, failed-payment classification, currency comparison, late-payment evidence, and controlled anomaly preservation

Implemented (Milestone 16, refunds and adjustments):

- four reusable intermediate transformations under `models/intermediate/billing/`: `int_refund_payment_matching` (preserves unmatched refund evidence rather than dropping it), `int_refund_allocation` (refund-limit evidence: `refund_limit_variance = refund_amount - refundable_amount_reference`, never capped or corrected), `int_adjustment_allocation` (verified sign convention: credit = negative, decreasing amount due), and `int_credit_note_application`
- three core facts: `fct_refunds` (grain: `refund_id`), `fct_adjustments` (grain: `adjustment_id`), and `fct_credit_notes` (grain: `credit_note_id`, implemented as its own standalone fact since a credit note is a distinct document type in the source), plus a provisional `refund_count`/`refund_amount`/`adjustment_count`/`net_adjustment_amount` extension to `fct_invoices` that is explicitly documented as not a final outstanding-balance measure
- two independent, preserved-not-classified controlled-anomaly signals on the deliberately injected `invalid_adjustment` exception (`has_invoice_match = false` and `has_expected_sign_for_type = false` -- a `credit`-type adjustment with a positive amount), plus `refund_limit_variance = 100.00` unmodified on the `refund_greater_than_collected_amount` exception's row
- three singular business-rule tests (refund-allocation arithmetic sanity, fixed-point amount consistency, and a controlled-anomaly-presence guard covering all three preserved signatures), plus column-level generic tests across the new intermediate/core YAML
- evidence only, no classification: no `billing_exception_type`, `severity`, `financial_value_at_risk`, or `resolution_status` field exists anywhere in this milestone -- that belongs to Milestone 18
- design documentation (`docs/data_models/airline_refunds_adjustments.md`) covering refund architecture, payment/refund relationships, refund-limit evidence, adjustment semantics, credit-note handling, sign conventions, currency handling, and the distinction between financial movement and revenue treatment

Planned (Milestone 17 onward):

- voucher application
- revenue recognition
- a final outstanding-balance model netting collected amounts against refunds/adjustments (Milestone 18)
- billing exception classification (Milestone 18)
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
10. Airline Staging Models - complete
11. Core Airline Operations Model - complete
12. Booking and Ticketing - complete
13. Products, Services, Prices and Tariffs - complete
14. Invoices and Invoice Lines - complete
15. Payments and Failed Payments - complete
16. Refunds and Adjustments - complete
17. Revenue Recognition - planned
18. Outstanding Balances and Billing Exceptions - planned
19. Reconciliation Controls - planned
20. Commercial Reporting Marts - planned
21. Production dbt Engineering - planned
22. Final Portfolio Polish - planned
