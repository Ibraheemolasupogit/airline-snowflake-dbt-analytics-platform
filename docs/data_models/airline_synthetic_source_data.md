# Airline Synthetic Source Data

## Purpose

Milestone 9 builds a deterministic, relationally coherent synthetic airline
source dataset that later milestones (staging, core dimensions/facts,
booking/pricing/billing transformations, revenue recognition, reconciliation,
and commercial marts) will model. It is source data only: this milestone does
not add dbt staging models, intermediate models, core dimensions/facts,
booking-lifecycle transformations, pricing transformations, billing
calculations, payment allocation, revenue recognition, reconciliation marts,
commercial marts, dashboards, or any live Snowflake loading.

**AirStats remains the conformed airport-reference foundation.** Nothing in
this milestone changes, refactors, or duplicates the AirStats staging,
intermediate, incremental, snapshot, mart, or testing implementation
completed in Milestones 1-8.

## Privacy Statement

Every passenger, booking, ticket, invoice, payment, and refund in this
dataset is synthetic. Passenger names are drawn from a small fixed pool of
common first/last names combined mechanically; email addresses use the
`.invalid` top-level domain reserved by RFC 2606 specifically so it can never
resolve to a real mailbox. No real passenger, airline commercial, or payment
data is used anywhere in this repository.

## Generator Design

`scripts/generate_airline_data.py` orchestrates a small package,
`scripts/airline_synth/`, organised by domain:

- `config.py` -- the fixed seed and the fixed synthetic timeline anchor
- `reference.py` -- static fixture data (airports, airlines, aircraft types, currencies, fare classes, services, corporate accounts, travel agents, name word-lists)
- `utils.py` -- deterministic id formatting, haversine distance, CSV I/O, UTC timestamp helpers
- `build_operations.py`, `build_bookings.py`, `build_pricing.py`, `build_billing.py` -- one row-builder module per domain
- `exceptions.py` -- deterministic controlled-exception injection (see the exception catalogue doc)

Only the Python standard library is used (`csv`, `random`, `math`, `datetime`,
`argparse`, `dataclasses`) -- no pandas, numpy, or Faker dependency was added.

### Determinism

- A single `random.Random(seed)` instance (default seed `20240115`) is
  consumed in a fixed, insertion-ordered sequence of operations. Nothing
  reads from `set()` iteration order or filesystem listing order in a way
  that could vary between runs.
- All dates are computed relative to a fixed anchor, `AS_OF_DATE = 2026-01-15`
  (`airline_synth/config.py`), never from the real wall-clock date. This
  means the generator produces byte-identical output regardless of when it
  is actually executed -- verified by `scripts/validate_source_data.py` and
  by `tests/python/test_synthetic_generator.py`, which run the generator
  twice and diff the output files.
- Row counts are configurable via CLI flags (`--seed`, `--output-dir`,
  `--bookings`, `--passengers`) or by constructing a `GeneratorConfig` with
  different values; the default configuration is deliberately small
  (~150 passengers, 180 bookings) to keep the checked-in dataset lightweight
  (well under 1 MB total).

### Timestamps and currency

All generated timestamps are UTC, rendered as ISO-8601 with a trailing `Z`
(for example `2026-01-05T14:30:00Z`). Every booking is assigned one currency
(derived from a point-of-sale country) that is used consistently across its
invoice, invoice lines, and payment -- except where the `currency_mismatch`
exception deliberately breaks that consistency for one payment. Currency
conversion uses a small fixed `EXCHANGE_RATE_TO_USD` table
(`reference.py`); these are illustrative fixture rates for relational
realism, not live market rates.

## AirStats Airport-Reference Integration

Routes, flight schedules, flight instances, ticket segments, and airport fees
all reference airport identifiers from `AIRPORT_FIXTURE` in
`scripts/airline_synth/reference.py`: 24 real-world airport identifiers
styled the way AirStats/OurAirports represents them (`ident`, `icao_code`,
`iata_code`, `iso_country`, `iso_region`, `continent_code`), spanning North
America, Europe, Asia, Oceania, Africa, and South America.

This fixture is **not** queried from Snowflake or from the AirStats dbt
staging layer -- no live warehouse connection exists for this generator, and
none is claimed. It exists so downstream airline entities are consistent
with the AirStats domain (the same `ident` values a live AirStats source
would contain) instead of referencing arbitrary made-up airport codes. A
copy of the fixture is written to `data/synthetic/reference/airports.csv` for
transparency and reuse.

When a real Snowflake-backed AirStats source exists, a future milestone can
replace this fixture lookup with an actual `airstats.airports` reference
without changing the shape of any downstream entity.

## Entity Inventory, Grain, and Keys

### Reference and operations

| Entity | Grain | Key |
| --- | --- | --- |
| `airlines` | one row per airline | `airline_code` |
| `aircraft_types` | one row per aircraft type | `aircraft_type_code` |
| `aircraft` | one row per aircraft (tail) | `aircraft_registration` |
| `routes` | one row per directional airport pair / airline route | `route_id` |
| `flight_schedules` | one row per scheduled flight service | `schedule_id` |
| `flight_instances` | one row per dated flight occurrence | `flight_instance_id` |

### Passenger and booking

| Entity | Grain | Key |
| --- | --- | --- |
| `passengers` | one row per synthetic passenger | `passenger_id` |
| `bookings` | one row per booking reference | `booking_id` |
| `booking_passengers` | one row per booking-passenger association | `booking_passenger_id` |
| `tickets` | one row per issued passenger ticket | `ticket_id` |
| `ticket_segments` | one row per ticketed passenger flight segment | `ticket_segment_id` |

### Products and pricing

| Entity | Grain | Key |
| --- | --- | --- |
| `products` | one row per sellable fare bundle | `product_code` |
| `services` | one row per sellable ancillary/service catalog entry | `service_code` |
| `ancillary_services` | one row per ancillary service sold against a ticket | `ancillary_service_id` |
| `fare_classes` | one row per sellable fare class | `fare_class_code` |
| `fare_rules` | one row per fare-class rule set | `fare_rule_id` |
| `airport_fees` | one row per (airport, fee type) | `airport_fee_id` |
| `taxes` | one row per (country, tax type) | `tax_id` |
| `discounts` | one row per discount code | `discount_code` |
| `currencies` | one row per currency code | `currency_code` |
| `exchange_rates` | one row per currency, rate to USD as of `AS_OF_DATE` | `currency_code` |

### Billing and payments

| Entity | Grain | Key |
| --- | --- | --- |
| `corporate_accounts` | one row per corporate account | `corporate_account_id` |
| `travel_agents` | one row per travel agent | `travel_agent_id` |
| `invoices` | one row per invoice | `invoice_id` |
| `invoice_lines` | one row per invoice charge component | `invoice_line_id` |
| `payment_attempts` | one row per payment attempt | `payment_attempt_id` |
| `payments` | one row per successful payment transaction | `payment_id` |
| `refunds` | one row per refund transaction | `refund_id` |
| `adjustments` | one row per manual invoice adjustment | `adjustment_id` |
| `credit_notes` | one row per credit note | `credit_note_id` |
| `vouchers` | one row per issued travel voucher | `voucher_id` |

All 31 entities named in the Milestone 9 scope are implemented; none were
deferred.

## Relational Flow

```text
airport (fixture)
  -> route (directional, per airline)
    -> flight_schedule (template: flight number, days of week, local time)
      -> flight_instance (dated occurrence; status: scheduled | completed | cancelled)
        -> ticket_segment (links a ticket to one flight_instance; status derived from
           the flight_instance's status and the booking's status)
booking (one route, one or two flight_instances if round trip)
  -> booking_passenger (links passengers to the booking)
  -> ticket (one per booking passenger)
    -> ticket_segment (one or two, per trip_type)
    -> ancillary_service (0-2 sold per issued ticket)
  -> invoice (one per booking)
    -> invoice_line (base_fare, tax, airport_fee, ancillary, discount)
    -> payment_attempt (one or more)
      -> payment (successful attempts only)
        -> refund (for cancelled bookings that had already paid)
          -> credit_note
    -> adjustment (occasional manual correction)
  -> voucher (occasional goodwill issuance)
```

### Determining fulfilment for later revenue recognition

`flight_instances.status` and `ticket_segments.segment_status` together let a
later revenue-recognition model decide whether a flight or ancillary service
was actually fulfilled:

- `flight_instances.status = 'completed'` and `ticket_segments.segment_status
  = 'flown'` together mean the segment was actually flown.
- `segment_status = 'cancelled'` means the segment will never be flown
  (either the booking was cancelled, or the flight itself was cancelled).
- `segment_status = 'confirmed'` means the segment is still in the future.
- `ancillary_services.fulfilment_status` (`fulfilled` / `not_fulfilled` /
  `pending`) gives the equivalent signal for ancillary services.

## Known Simplifications

- The dataset's "today" is a fixed anchor date (`2026-01-15`), not the real
  current date. This keeps the generator deterministic forever, at the cost
  of the dataset visibly aging relative to the real world over time.
- One invoice is generated per booking (no split-billing between a
  corporate sponsor and a traveller on the same booking).
- Taxes are modelled as a single flat government passenger tax percentage
  per country rather than a full jurisdictional tax/fee rulebook.
- Invoice currency conversion is centralised (computed directly from a USD
  baseline at generation time) rather than modelled as a multi-hop
  currency remittance chain through the standalone `airport_fees`/`taxes`
  reference amounts.
- Every ticket in a booking shares the same fare class; airlines do not mix
  cabins within one booking in this generator.
- Codeshares, interline itineraries, and more than two flight segments per
  ticket are out of scope.
- Aircraft rotation is a simple round-robin by aircraft type within an
  airline's fleet, not a real crew/maintenance-aware scheduling model.

## Control Totals

`scripts/generate_control_totals.py` reads the generated CSVs and writes
`data/synthetic/control_totals.json`: booking count/value, invoice
count/value, successful payment count/value, refund count/value,
flight-instance count (split by status), and ticket count. These are
**synthetic source-level control totals only** -- they describe the
generated CSVs exactly as written, including the effect of deliberately
injected exceptions (for example, the duplicate invoice is counted twice).
They are not a warehouse-computed reconciliation result, and no Snowflake
connection is used to produce them. A later reconciliation milestone can
recompute the same totals from dbt models and compare against this file.

## Controlled Exceptions

See `docs/data_models/airline_synthetic_exception_catalogue.md` for the full
catalogue. In summary: `scripts/airline_synth/exceptions.py` deterministically
plants 14 documented data-quality/financial-control exceptions into the
otherwise-clean generated dataset, and records each one as a row in
`data/synthetic/exception_manifest.csv` (exception id, type, affected entity,
affected record key, expected later detection rule, rationale).
`scripts/validate_source_data.py` uses that manifest to tell an intentional
exception apart from an unexpected integrity defect, and never "fixes" a
planted exception.

## Validation

`scripts/validate_source_data.py` checks (without dbt or Snowflake): all
expected files exist; every primary key is unique and non-null; foreign keys
resolve except where the manifest says they are deliberately broken; the
manifest contains exactly the 14 expected exception types, each with its
structural fingerprint actually present in the data; every referenced
currency is supported; invoice-line relationships are structurally usable;
and repeated generator runs are byte-for-byte deterministic.
`tests/python/test_synthetic_generator.py` exercises the same properties as
pytest tests.
