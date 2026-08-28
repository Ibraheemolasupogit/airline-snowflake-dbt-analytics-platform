# Airline Source and Staging Layer

## Purpose

Milestone 10 adds a production-style dbt source and staging layer over the Milestone 9
deterministic synthetic airline dataset. It mirrors the disciplined AirStats pattern:

```text
data/synthetic/*.csv (Milestone 9 generator output)
  -> Snowflake-oriented raw source definitions (source())
  -> typed/normalised staging views (stg_airline__*)
```

No business transformation happens at this layer: no booking-lifecycle logic, journey
completion, pricing calculation, invoice arithmetic, payment allocation, refund allocation,
revenue recognition, exception detection, or reconciliation. Staging only casts types, trims
text, normalises blank strings to null, and normalises simple booleans. Business logic begins in
Milestone 11 onward.

## Source Architecture

Five per-domain Snowflake-oriented sources, one per Milestone 9 CSV folder:

```text
RAW_AIRLINE_REFERENCE   <- source('airline_reference', ...)  <- data/synthetic/reference/
RAW_AIRLINE_OPERATIONS  <- source('airline_operations', ...) <- data/synthetic/operations/
RAW_AIRLINE_BOOKINGS    <- source('airline_bookings', ...)   <- data/synthetic/bookings/
RAW_AIRLINE_PRICING     <- source('airline_pricing', ...)    <- data/synthetic/pricing/
RAW_AIRLINE_BILLING     <- source('airline_billing', ...)    <- data/synthetic/billing/
```

These schemas are **not deployed to any live Snowflake account**. This milestone documents and
parses the source configuration only; no warehouse-backed `dbt run`/`dbt test` has occurred.

### Categorisation note: corporate_accounts and travel_agents

The Milestone 9 generator physically writes `corporate_accounts.csv` and `travel_agents.csv`
into `data/synthetic/billing/`, alongside invoices and payments, because they are billing
counterparties in this dataset. This milestone follows that actual file location and models
both entities under `source('airline_billing', ...)` / `models/staging/airline_billing/`, rather
than under the reference domain, per the instruction to use the actual Milestone 9 entity
inventory as authority where the categorisation differs slightly from a purely conceptual
grouping.

### Airport reference: deliberately not duplicated

`data/synthetic/reference/airports.csv` is a static copy of the AirStats-style airport fixture
used by the Milestone 9 generator for internal consistency (see
`docs/data_models/airline_synthetic_source_data.md`). It is **not** modelled as an airline
source or staging view here. AirStats (`source('airstats', 'airports')`,
`stg_airstats__airports`) remains the sole authoritative airport-reference implementation. See
"AirStats Relationship" below.

## Entity Map

### Reference (`airline_reference`, `RAW_AIRLINE_REFERENCE`)

| Entity | Staging model |
| --- | --- |
| airlines | `stg_airline__airlines` |
| aircraft_types | `stg_airline__aircraft_types` |
| currencies | `stg_airline__currencies` |
| exchange_rates | `stg_airline__exchange_rates` |

### Operations (`airline_operations`, `RAW_AIRLINE_OPERATIONS`)

| Entity | Staging model |
| --- | --- |
| aircraft | `stg_airline__aircraft` |
| routes | `stg_airline__routes` |
| flight_schedules | `stg_airline__flight_schedules` |
| flight_instances | `stg_airline__flight_instances` |

### Bookings and ticketing (`airline_bookings`, `RAW_AIRLINE_BOOKINGS`)

| Entity | Staging model |
| --- | --- |
| passengers | `stg_airline__passengers` |
| bookings | `stg_airline__bookings` |
| booking_passengers | `stg_airline__booking_passengers` |
| tickets | `stg_airline__tickets` |
| ticket_segments | `stg_airline__ticket_segments` |

### Pricing/products (`airline_pricing`, `RAW_AIRLINE_PRICING`)

| Entity | Staging model |
| --- | --- |
| products | `stg_airline__products` |
| services | `stg_airline__services` |
| ancillary_services | `stg_airline__ancillary_services` |
| fare_classes | `stg_airline__fare_classes` |
| fare_rules | `stg_airline__fare_rules` |
| airport_fees | `stg_airline__airport_fees` |
| taxes | `stg_airline__taxes` |
| discounts | `stg_airline__discounts` |

### Billing (`airline_billing`, `RAW_AIRLINE_BILLING`)

| Entity | Staging model |
| --- | --- |
| corporate_accounts | `stg_airline__corporate_accounts` |
| travel_agents | `stg_airline__travel_agents` |
| invoices | `stg_airline__invoices` |
| invoice_lines | `stg_airline__invoice_lines` |
| payment_attempts | `stg_airline__payment_attempts` |
| payments | `stg_airline__payments` |
| refunds | `stg_airline__refunds` |
| adjustments | `stg_airline__adjustments` |
| credit_notes | `stg_airline__credit_notes` |
| vouchers | `stg_airline__vouchers` |

31 source tables and 31 staging models in total, covering every Milestone 9 entity.

## Typing Conventions

Following the AirStats staging pattern (`with source as (select * from {{ source(...) }}),
renamed as (<casts>) select <columns> from renamed`):

- Text: `nullif(trim(cast(<col> as varchar)), '')`
- Integer counts: `try_to_number(nullif(trim(cast(<col> as varchar)), ''), 38, 0)`
- Monetary amounts: `try_to_decimal(..., 18, 2)` -- fixed-point decimal, never floating point,
  suitable for later financial controls.
- Rates/percentages/ratios (exchange rates, tax percentage_rate, fare per_km_usd, corporate
  discount/commission percentages, discount `value`): `try_to_decimal(..., 18, 6)` for finer
  precision.
- Pure calendar dates (`date_of_birth`, `flight_date`, `as_of_date`, `expiry_date`):
  `try_to_date(...)`.
- UTC timestamps (every `_utc`-suffixed column): `try_to_timestamp_ntz(...)`.
- Booleans (`refundable`, generated as Python `True`/`False` text): a `case` expression matching
  `lower(...) = 'true'` / `'false'`, mirroring the AirStats yes/no pattern.
- Pipe-delimited list-like text (`cabins`, `included_service_codes`, `operating_days_of_week`):
  preserved as trimmed text, not parsed into an array. Parsing is deferred to a later milestone
  if it is ever needed.

Currency codes and monetary amounts are always kept in separate columns; no currency conversion
or arithmetic happens in staging.

## Controlled Exception Preservation

The Milestone 9 dataset deliberately contains 14 documented exceptions (see
`docs/data_models/airline_synthetic_exception_catalogue.md` and
`data/synthetic/exception_manifest.csv`). The staging layer preserves every one of them exactly:

- No staging model filters, corrects, or suppresses an exception row.
- Every affected column is cast the same way regardless of whether the specific row is one of
  the 14 planted exceptions.
- Generic tests are deliberately **not** added where they would fail by design against a known
  exception (for example, no `unique` test on `stg_airline__invoices.booking_id`, since the
  duplicate-invoice exception intentionally produces two invoices for one booking; no
  `relationships` test on `stg_airline__payments.invoice_id` or
  `stg_airline__adjustments.invoice_id`, since one row in each deliberately references a
  non-existent invoice). Each such omission is called out in the relevant column's YAML
  description.
- Exception-*detection* logic (flagging duplicates, validating refund limits, checking invoice
  reconciliation, etc.) is handled in downstream billing-assurance models, not in staging.

## AirStats Relationship

Several airline entities carry airport identifiers styled exactly like AirStats/OurAirports
idents, preserved unchanged through staging so downstream models can conform them:

```text
stg_airline__routes.origin_ident / destination_ident
stg_airline__flight_schedules.origin_ident / destination_ident
stg_airline__flight_instances.origin_ident / destination_ident
stg_airline__ticket_segments (via its flight_instance)
stg_airline__airport_fees.airport_ident
stg_airline__airlines.hub_ident
  -> source('airstats', 'airports').ident / ref('stg_airstats__airports').ident
```

The staging layer does **not** add a `relationships` test against AirStats for these columns and
does **not** create `dim_airport` or any other conformance model. That join belongs in the core
model where the conformed airport dimension is built.

## Scope Boundary

This document covers the source and staging layer: typing, naming, source-quality tests, and
preservation of source records exactly as generated. Intermediate transformations, conformed core
dimensions/facts, pricing, invoicing, payment allocation, revenue recognition, billing exceptions,
reconciliation, and commercial marts are documented in their own downstream domain files.
