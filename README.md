# Airline Operations & Commercial Analytics Engineering Platform

A Snowflake + dbt + SQL analytics engineering platform modelling airline operations, bookings,
pricing, billing, fulfilment-driven revenue recognition, financial reconciliation, and commercial
reporting -- built production-style, end to end, on deterministic synthetic data.

## Overview

This is a specialist analytics-engineering portfolio project, not a generic data platform. It
covers one coherent business domain -- an airline's operational and commercial data -- from
conformed airport reference data through to executive-facing commercial marts, with the financial
rigour (reconciliation, exception detection, revenue-recognition semantics) a real airline finance
or commercial-analytics team would expect.

## Business Problem

An airline (and the finance/commercial teams around it) needs to answer questions that span
several distinct systems: which flights actually operated, which bookings turned into tickets,
what was priced versus what was invoiced, what cash was actually collected, which invoices remain
outstanding, which billing events look wrong, and how much revenue was genuinely *earned* -- not
just billed. This platform builds the layered dbt project that answers those questions
end to end, with every monetary figure traceable back to a specific, governed source.

## What the Platform Demonstrates

- Dimensional modelling with explicit grain, surrogate keys, and conformed dimensions across two
  independent source systems (AirStats airport reference + a synthetic airline operational/
  commercial dataset).
- A financial-assurance layer that distinguishes booked value, invoiced value, cash collected,
  refunds/adjustments, recognised revenue, outstanding balance, and financial value at risk --
  never blurring these into one generic "revenue" number.
- Deterministic synthetic data with 14 deliberately injected, catalogued business anomalies, and
  rule-based detection that finds all of them without a single hardcoded record ID.
- Source-to-warehouse reconciliation that explicitly separates a genuine ETL defect from a
  business anomaly that reconciles correctly.
- Production-style dbt engineering -- enforced model contracts, incremental models, SCD Type 2
  snapshots, exposures, governed metric definitions, and a two-lane CI pipeline -- applied
  selectively and justified in writing, not applied everywhere by default.

## Architecture

```mermaid
flowchart LR
    SRC[Sources -- AirStats and Synthetic Airline Data] --> STG[Staging]
    STG --> INT[Intermediate]
    INT --> CORE[Core Dimensions and Facts]
    CORE --> ASSURE[Assurance and Reconciliation]
    CORE --> MARTS[Commercial Marts]
    ASSURE --> MARTS
    MARTS --> BI[Intended BI Consumption]
```

Five layers: `staging` (typed, source-aligned), `intermediate` (reusable business logic),
`core` (governed dimensions/facts, nine under an enforced dbt contract), `marts` (37
consumption-ready reporting models across six domains), and a set of exposures documenting
intended (not yet deployed) BI consumption surfaces. See
[`docs/architecture/overview.md`](docs/architecture/overview.md) for the full layer breakdown and
[`docs/data_models/`](docs/data_models/) for per-domain lineage detail.

## Core Data Flow

```text
AirStats / OurAirports reference
  -> routes
  -> scheduled flights
  -> operated flight instances
  -> bookings
  -> passengers
  -> tickets and flight segments
  -> pricing / fares / taxes / fees / ancillaries
  -> invoices
  -> payments
  -> refunds / adjustments
  -> service fulfilment
  -> recognised revenue
  -> outstanding balances
  -> billing exceptions
  -> reconciliation
  -> commercial reporting
```

Every arrow above is a real `ref()`/`source()` dependency in the dbt DAG, not an aspirational
diagram -- see [`docs/data_models/`](docs/data_models/) for the model-by-model lineage behind each
step.

## AirStats: the Conformed Airport Reference Foundation

AirStats is this project's own conformed layer over real, open OurAirports-style airport and
runway reference data -- staged, tested, snapshotted (SCD Type 2), and exposed as consumption-ready
marts under `models/marts/airport_operations/`. It is the **sole authoritative source** for
airport identity in this platform: `dim_airport` is built directly from the AirStats marts, and
every airline route, hub, and operational airport identifier is conformed to it. The synthetic
airline dataset carries airport identifiers styled the way AirStats/OurAirports represents them,
but that synthetic fixture is never treated as an authoritative reference -- only AirStats is.

## Key Capabilities

- **Layered dbt architecture** with explicit grain and surrogate keys generated once per entity
  and reused everywhere via `ref()` -- never re-derived.
- **Nine enforced dbt model contracts** on the platform's most-consumed governed dimensions/facts
  (`dim_airport`, `dim_route`, `fct_flight_operations`, `fct_bookings`, `fct_invoice_lines`,
  `fct_payments`, `fct_revenue`, `fct_billing_exceptions`, `fct_outstanding_balances`), applied
  selectively -- not to every model.
- **Incremental materialisation** (`merge` strategy, configurable late-arrival lookback window)
  for four transaction-event facts, with a written rationale for the facts deliberately left
  full-refresh.
- **SCD Type 2 snapshots** for both AirStats reference data and airline reference entities
  (fare rules, airport fees, taxes, corporate accounts), using `check` strategy throughout because
  no source in this project has a genuine `updated_at` field -- documented, never fabricated.
- **Deterministic synthetic data**, standard-library Python only, fixed seed, with a documented
  catalogue of 14 controlled business anomalies and a machine-readable exception manifest.
- **1,700+ dbt tests** -- generic, singular business-rule, source-quality, referential-integrity,
  incremental-integrity, and snapshot-integrity -- organised by folder, with stored failures
  configured per test category.
- **Offline-safe CI** (SQLFluff, `pre-commit`, `dbt parse`/`ls`, the full Python regression suite)
  that runs green with zero Snowflake credentials, plus a second, credentials-gated lane for real
  warehouse execution that is skipped, never failed, when secrets are absent.
- **Six dbt exposures** and a **governed metric-definition convention** in place of a semantic
  layer the project's own pinned dependencies don't support.
- **State/defer and dbt-artifact-handling readiness**, documented and infrastructure-prepared,
  without claiming a capability that has never actually run.

## Commercial & Financial Analytics

This platform treats these as **distinct, separately governed measures** -- never collapsed into
one generic "revenue" figure:

| Measure | What it actually means |
| --- | --- |
| Booked value | What a booking's tickets/ancillaries were priced at (`fct_pricing_events`). |
| Invoiced value | What was actually billed (`fct_invoices.source_invoice_total`). |
| Amount collected | Cash actually received against an invoice (`fct_invoices.amount_collected`). |
| Refunds / adjustments | Money returned or corrected after the fact, each with its own sign convention. |
| Recognised revenue | Revenue earned once the underlying service was *fulfilled* -- independent of billing or cash timing (`fct_revenue`). |
| Outstanding balance | `invoiced - collected + refunds + adjustments`, never clamped to zero. |
| Financial value at risk | The monetary exposure carried by a detected billing exception -- not a balance, not revenue. |

Currency safety is enforced throughout: no model ever sums raw amounts across different
currencies. See [`docs/business_glossary/metric_definitions.md`](docs/business_glossary/metric_definitions.md)
for the full governed metric list.

## Data Quality / Assurance

- **Deterministic synthetic control totals** (`scripts/generate_control_totals.py`) generated
  directly from the same source-of-truth data the warehouse layer models -- never hand-typed.
- **Source-to-warehouse reconciliation** across booking, invoice, payment, and refund domains,
  plus a revenue/cash bridge that deliberately does *not* force false equality between invoiced
  value, collected cash, and recognised revenue -- they are genuinely different things.
- **14 controlled business anomalies** (a duplicate invoice, an overpaid/unallocated payment, a
  refund exceeding its collected payment, a currency mismatch, an invalid adjustment, and more),
  each with rule-based -- never hardcoded-ID -- detection.
- **The central assurance distinction**: a business anomaly (the data itself is unusual, but
  faithfully carried through) is not the same thing as a reconciliation failure (the warehouse
  computed something differently from the source). Both are demonstrated, and tested, as
  independently true where applicable -- see
  [`docs/data_models/airline_reconciliation_controls.md`](docs/data_models/airline_reconciliation_controls.md).
- No live-warehouse reconciliation has been run; every reconciliation figure in this repository's
  evidence is either a dbt test definition or an offline Python recomputation explicitly labelled
  as such.

## Commercial Marts

Six mart domains, 37 consumption-ready models total: `airport_operations` (AirStats capacity/
runway/status reporting), `airline_operations` (flight/route/airport activity), `passenger_commercial`
(bookings, journeys, channels, fare classes, cabins, corporate accounts), `billing_assurance`
(invoices, payments, refunds, outstanding balances, billing exceptions, reconciliation),
`revenue` (recognised revenue by route/airport/fare-class/cabin/channel/corporate-account, plus
route commercial performance), and `executive` (four narrow cross-domain summaries).

**Route profitability is intentionally excluded.** No route or flight cost dataset exists anywhere
in this project's source data (no fuel, crew, maintenance, or airport-charge cost basis) -- this
was assessed deliberately, not overlooked. `mart_route_commercial_performance` is the documented
substitute: revenue-per-unit commercial metrics only (revenue per passenger, revenue per flight),
never RASK, CASK, margin, or a fabricated cost figure. See
[`docs/data_models/airline_commercial_marts.md`](docs/data_models/airline_commercial_marts.md).

## Production dbt Engineering

- **9 contracted models** with every column's data type verified against actual SQL output.
- **4 incremental facts** (`fct_payment_attempts`, `fct_payments`, `fct_refunds`, `fct_revenue`),
  `merge` strategy, with a documented rationale for the facts deliberately left full-refresh.
- **6 SCD Type 2 snapshots** total (2 AirStats, 4 airline), `check` strategy throughout.
- **Source freshness**: deliberately unconfigured everywhere -- no source in this project has a
  genuine ingestion timestamp, and this was verified against the actual generator code rather than
  assumed.
- **6 exposures** documenting intended BI consumption surfaces, explicitly labelled as not yet
  deployed.
- **A governed metric-definition convention** in place of a dbt Semantic Layer, since the
  required `dbt-metricflow` package isn't part of this project's pinned dependencies.
- **Two-lane CI**: an always-green offline-assurance lane (YAML/SQL validation, `dbt parse`/`ls`,
  SQLFluff, `pre-commit`, the full Python regression suite, a secret scan) and a
  credentials-gated warehouse-assurance lane that is skipped -- never failed -- without Snowflake
  secrets configured.
- **State/defer and dbt-artifact-handling readiness**, documented and prepared, not claimed as
  executed.

See [`docs/engineering/dbt_production_engineering.md`](docs/engineering/dbt_production_engineering.md)
for the full policy behind every decision above, and
[`docs/runbooks/dbt_production_runbook.md`](docs/runbooks/dbt_production_runbook.md) for the
operational runbook.

## Repository Structure

```text
models/
  staging/       typed, source-aligned models (36)
  intermediate/  reusable business transformations (51)
  core/          governed dimensions and facts (35; 9 under an enforced contract)
  marts/         consumption-ready reporting models (37, across 6 domains)
  exposures/     intended BI consumption surfaces (6)
snapshots/       SCD Type 2 history (6: 2 AirStats, 4 airline)
seeds/           small, version-controlled reference fixtures (reconciliation control totals)
tests/           generic + singular dbt tests, organised by category (1,700+), plus Python tests
macros/          reusable dbt macros (currency conversion)
scripts/         standard-library Python: synthetic-data generation, validation, reconciliation evidence
docs/            architecture, data models, engineering, business glossary, runbooks, decisions
reports/         portfolio-facing summary reports (reconciliation, assurance, revenue recognition)
outputs/         offline reconciliation-evidence CSV fixtures
```

Full documentation index: [`docs/README.md`](docs/README.md).

## Technology Stack

Snowflake (target warehouse) - dbt Core 1.9 with the Snowflake adapter - SQL - Python
(standard library only for data generation/validation) - SQLFluff - `pre-commit` - GitHub Actions -
`dbt_utils` / `dbt_expectations` / `dbt_date` packages.

## Example Analytical Outputs

Offline evidence, generated by `scripts/generate_reconciliation_evidence.py` directly from the
checked-in synthetic dataset -- explicitly *not* an executed `dbt run`/`dbt build` result (see each
file's own header for that distinction):

- `outputs/`: [`daily_booking_control_totals.csv`](outputs/daily_booking_control_totals.csv), [`daily_invoice_control_totals.csv`](outputs/daily_invoice_control_totals.csv), [`daily_payment_control_totals.csv`](outputs/daily_payment_control_totals.csv), [`daily_refund_control_totals.csv`](outputs/daily_refund_control_totals.csv) -- fully-populated offline reconciliation fixtures.
- `outputs/`: [`revenue_reconciliation.csv`](outputs/revenue_reconciliation.csv), [`billing_exceptions.csv`](outputs/billing_exceptions.csv) -- schema-only fixtures for outputs that require live warehouse business-logic execution, labelled as such rather than fabricated.
- `reports/`: [`billing_reconciliation_report.md`](reports/billing_reconciliation_report.md), [`payment_assurance_report.md`](reports/payment_assurance_report.md), [`refund_assurance_report.md`](reports/refund_assurance_report.md), [`revenue_recognition_report.md`](reports/revenue_recognition_report.md), [`month_end_revenue_reconciliation.md`](reports/month_end_revenue_reconciliation.md) -- narrative reports over the same offline evidence.
- `reports/`: [`airstats_capstone_summary.md`](reports/airstats_capstone_summary.md) -- the AirStats foundation's own capstone summary.

## Local Validation / Getting Started

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

To regenerate the synthetic airline dataset and validate it offline:

```bash
python scripts/generate_airline_data.py
python scripts/generate_control_totals.py
python scripts/generate_reconciliation_evidence.py
python scripts/validate_source_data.py
python -m pytest tests/python
```

For local dbt connectivity against a real Snowflake account (not required for any check above):

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

Real credentials, private keys, local profiles, and environment files must never be committed --
`profiles.yml` is gitignored; only `profiles.example.yml` (environment-variable-based) is tracked.

## Known Limitations

- All airline transactional data is **deterministic synthetic data**, standard-library Python,
  fixed seed -- never real passenger, airline, or commercial data.
- **No live Snowflake warehouse execution** is included in this repository's evidence. Every
  contract, incremental model, snapshot, and reconciliation figure has been designed and
  offline-validated (parse, `dbt ls`, SQLFluff, type cross-checks) but never executed against a
  real warehouse.
- **No BI dashboard is deployed.** The six dbt exposures document intended consumption surfaces,
  not built ones.
- **No route profitability metric exists**, because no route/flight cost dataset exists anywhere
  in this project's source data -- a deliberate exclusion, not an oversight.
- **No dbt source freshness is configured**, because no source in this project has a genuine
  ingestion timestamp -- confirmed against the actual generator code, not assumed.
- **Every SCD Type 2 snapshot uses the `check` strategy**, because no source entity has a
  trustworthy `updated_at`/equivalent field -- none was fabricated to demonstrate `timestamp`
  strategy instead.
- The AirStats reference layer is a fixed local extract, not a live-refreshed feed -- its own
  known limitations are documented in `docs/data_models/airstats_sources.md`.
- **Fare/revenue recognition is computed at ticket grain**, matching the pricing grain the
  synthetic source actually generates -- there is no per-segment fare apportionment rule to
  recognise revenue at a finer grain than that.
- This repository makes no production, customer-delivery, or regulatory-suitability claims of any
  kind.

## What This Supports In An Interview

Engineering decisions in this repository that are documented well enough to discuss in depth:

- Dimensional modelling and grain design -- why each core fact's grain was chosen, and where a
  mart deliberately mixes grains and where it deliberately does not.
- Conforming a second source system (the synthetic airline dataset) to an existing, independently
  built reference layer (AirStats) rather than duplicating airport-reference logic.
- dbt project architecture -- the staging/intermediate/core/marts layering, the
  single-generation-point convention for surrogate keys, and when to promote an intermediate model
  to a governed core fact versus keep it internal.
- Incremental-loading design -- choosing `merge` with a late-arrival lookback window for four
  specific facts, and the written reasoning for why two adjacent, similar-looking facts were
  deliberately left full-refresh instead.
- SCD Type 2 design -- `check` versus `timestamp` strategy, and why fabricating an `updated_at`
  field to demonstrate the latter would have been dishonest.
- Financial reconciliation -- source-to-warehouse control design, tolerance conventions, and the
  business-anomaly-vs-ETL-failure distinction.
- Revenue-recognition semantics -- why recognised revenue, invoiced value, and cash collected are
  three different numbers, and how each is kept separately queryable.
- Rule-based exception detection at scale (14 types) without ever matching on a hardcoded record
  ID.
- Production CI design for a project with no live credentials -- an always-green offline lane
  versus a credentials-gated warehouse lane, and why public CI must never require secrets to pass.
- Business-metric governance -- a written metric-definition convention chosen deliberately over a
  semantic-layer implementation the project's own dependencies didn't support.
- Avoiding fabricated precision -- explicitly declining to compute route profitability, RASK/CASK,
  or cross-currency aggregates where the underlying data cannot honestly support them.

## Potential Future Extensions

Optional, deliberately out of scope for this portfolio's completed roadmap:

- Voucher application logic (the synthetic source generates voucher data; applying it against
  bookings/invoices was never brought into the financial model).
- A real Snowflake account and a first `dbt build`/`dbt docs generate`/`dbt source freshness`
  execution, exercising the warehouse-assurance CI lane this project already has in place.
- A real BI tool connected to one or more of the six documented exposures.

---

Full documentation index: [`docs/README.md`](docs/README.md). Detailed per-domain data model
docs: [`docs/data_models/`](docs/data_models/). Production-engineering design:
[`docs/engineering/dbt_production_engineering.md`](docs/engineering/dbt_production_engineering.md).
