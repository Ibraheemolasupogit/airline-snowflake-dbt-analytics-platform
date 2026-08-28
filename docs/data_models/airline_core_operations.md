# Airline Core Operations Model

## Purpose

Milestone 11 adds the first airline intermediate transformations and the first airline core
dimensions and facts, scoped strictly to route/airline/aircraft/airport/flight reference and
flight-schedule/flight-instance operations:

```text
stg_airline__* (Milestone 10) + stg_airstats__airports (AirStats)
  -> models/intermediate/airline_operations/int_*.sql (reusable joins/derivations)
  -> models/core/dimensions/dim_*.sql (governed, tested dimensions)
  -> models/core/facts/fct_*.sql (governed, tested facts)
```

This milestone does **not** implement booking-lifecycle logic, journey completion from
passenger/ticket data, pricing or invoice calculations, payment or refund allocation, revenue
recognition, outstanding-balance or billing-exception detection, reconciliation, or commercial
reporting marts. Those remain planned for Milestone 12 onward, per
`docs/data_models/airline_staging_layer.md` and the README roadmap.

## Intermediate Layer: `models/intermediate/airline_operations/`

Four reusable transformation models, in dependency order:

1. **`int_route_airport_pair`** -- grain: one row per route (`route_id`). Joins
   `stg_airline__routes` to AirStats via `int_airport_geography` (reused, not re-derived) for
   both `origin_ident` and `destination_ident`. This is the first genuine join between the
   airline domain and AirStats; the synthetic `data/synthetic/reference/airports.csv` fixture,
   documented in Milestone 10 as deliberately unused, remains unused here too.
2. **`int_scheduled_flight_segments`** -- grain: one row per flight schedule (`schedule_id`).
   Joins `stg_airline__flight_schedules` to `stg_airline__airlines`, `stg_airline__aircraft_types`,
   and `int_route_airport_pair`. Derives `weekly_operating_day_count` from the pipe-delimited
   `operating_days_of_week` text (`array_size(split(..., '|'))`), the one derived measure the
   source data supports at this grain.
3. **`int_operated_flight_segments`** -- grain: one row per dated flight instance
   (`flight_instance_id`). Joins `stg_airline__flight_instances` to `int_scheduled_flight_segments`
   (scheduled context) and `stg_airline__aircraft` + `stg_airline__aircraft_types` (actual
   operating equipment). Derives `operational_completion_status` (scheduled/completed/cancelled,
   with a defensive `other` fallback) and `is_assigned_aircraft_type_consistent` (a three-valued
   true/false/null comparison of scheduled vs. actual aircraft type).
4. **`int_aircraft_route_compatibility`** -- grain: one row per flight schedule (`schedule_id`).
   Aggregates `is_assigned_aircraft_type_consistent` from `int_operated_flight_segments` up to
   the schedule grain (`operated_instance_count`, `consistent_instance_count`,
   `inconsistent_instance_count`, `consistent_ratio`, `is_fully_consistent`).

### Why not seat-capacity or range compatibility checks

`int_aircraft_route_compatibility` only checks assigned-vs-actual aircraft *type* consistency
because that is the only aircraft/route compatibility signal the Milestone 9 source data
defensibly supports: there is no distinct "scheduled seat capacity" field to compare against
aircraft seat capacity, and no documented aircraft range attribute to compare against route
distance. This does not imply certified runway compatibility, regulatory approval, airport
operating approval, or dispatch suitability -- it is purely a type-assignment consistency signal.

## Core Dimensions: `models/core/dimensions/`

All dimensions are current-state (no history) and use `dbt_utils.generate_surrogate_key` for
surrogate keys over their natural key.

| Model | Grain | Natural key | Surrogate key |
| --- | --- | --- | --- |
| `dim_airport` | current airport identifier | `airport_ident` | `airport_key` |
| `dim_airline` | airline | `airline_code` | `airline_key` |
| `dim_aircraft_type` | aircraft type | `aircraft_type_code` | `aircraft_type_key` |
| `dim_aircraft` | aircraft registration | `aircraft_registration` | `aircraft_key` |
| `dim_route` | airline route | `route_id` | `route_key` |
| `dim_flight` | flight schedule | `schedule_id` | `flight_key` |

### `dim_airport`: the conformed AirStats airport dimension

`dim_airport` is built from the existing AirStats marts (`mart_airport_geographic_coverage`,
`mart_airport_capacity_profile`), not by re-deriving airport logic or by joining the synthetic
`reference/airports.csv` fixture. This is the conformance join that Milestone 10 documented but
deliberately did not implement (see "AirStats Relationship" in `airline_staging_layer.md`).
AirStats' own `snap_airports`/`snap_runways` snapshots remain the place for SCD Type 2 airport
history; `dim_airport` itself carries no history.

### `dim_airline`, `dim_route`: concrete AirStats integration evidence

`dim_airline.hub_airport_key` and `dim_route.origin_airport_key` /
`dim_route.destination_airport_key` are foreign keys into `dim_airport`, each backed by a
`relationships` test. This is concrete evidence -- not just documentation -- that AirStats
airport identifiers are genuinely integrated into the airline domain.

### `dim_flight`: grain choice

`dim_flight` is graded at `schedule_id`, not `flight_number`. In the Milestone 9 dataset the two
are in 1:1 correspondence (one schedule per route with a unique flight number), but `schedule_id`
is the durable source-system primary key, so it is the grain key; `flight_number` is retained as
a descriptive attribute. Do not confuse this scheduled-flight identity with a dated flight
instance, which is `fct_flight_operations`' grain.

## Core Facts: `models/core/facts/`

| Model | Grain | Natural key |
| --- | --- | --- |
| `fct_flight_schedule` | scheduled flight service | `schedule_id` |
| `fct_flight_operations` | dated flight instance | `flight_instance_id` |

Both facts carry only operational schedule/instance measures and foreign keys to the core
dimensions above -- no passenger-booking, revenue, or ticketing facts.

### Delay, completion, and load-factor logic

- **Delay measures**: not computed. The Milestone 9 source provides only *scheduled* departure
  and arrival timestamps (`scheduled_departure_utc`, `scheduled_arrival_utc`) -- there are no
  actual/observed departure or arrival timestamps anywhere in the dataset. A delay measure would
  require comparing scheduled against actual times, which cannot be done honestly with this
  source. `fct_flight_operations` only asserts `scheduled_arrival_utc >= scheduled_departure_utc`
  where both are known.
- **Completion status**: `operational_completion_status`, carried through from
  `int_operated_flight_segments`, is a deterministic recode of the source `status` column
  (`scheduled` / `completed` / `cancelled`, with an `other` fallback). It is explicitly documented
  as a source-observed operational signal only -- it does not infer service fulfilment, revenue
  recognition, or on-time performance.
- **Load factor**: `fct_flight_operations.seats_available` is real, taken from the actual
  operating aircraft's type typical-seat capacity. `passengers_carried` is always `null` in this
  milestone because populating it requires ticket-level passenger counts, which are explicitly
  out of scope until Milestone 12 (Booking and Ticketing); the column exists now as a stable,
  documented placeholder so later milestones populate it rather than adding it as a schema
  change. `load_factor` (`passengers_carried / seats_available`, guarded to compute only when
  `seats_available > 0`) is consequently always `null` too, for the same reason. Both columns are
  tested with `dbt_expectations.expect_column_values_to_be_between` guarded by
  `row_condition: ... is not null`, so the tests are inert now and become live the moment a later
  milestone populates real values.

## AirStats Conformance Implementation

Milestone 10 documented the future join (see "AirStats Relationship" in
`airline_staging_layer.md`) without implementing it. Milestone 11 implements it concretely:

- `int_route_airport_pair` joins `stg_airline__routes.origin_ident` /
  `destination_ident` to `int_airport_geography.ident` (AirStats' own intermediate layer, reused
  rather than re-derived).
- `dim_airport` is built from AirStats' own consumption-ready marts
  (`mart_airport_geographic_coverage`, `mart_airport_capacity_profile`).
- `dim_airline.hub_airport_key`, `dim_route.origin_airport_key`, and
  `dim_route.destination_airport_key` are foreign keys into `dim_airport`, each with a
  `relationships` test -- concrete evidence of integration, not just documentation.
- The synthetic `data/synthetic/reference/airports.csv` fixture is never joined anywhere in this
  milestone; AirStats remains the sole authoritative airport-reference source, as Milestone 10
  established.

## Tests Added

- Column-level generic tests in `models/intermediate/airline_operations/_airline_operations_intermediate.yml`,
  `models/core/dimensions/_core_dimensions.yml`, and `models/core/facts/_core_facts.yml`: `not_null`,
  `unique`, `relationships` (including cross-domain relationships into `stg_airstats__airports`
  and `dim_airport`), `accepted_values`, `dbt_expectations.expect_column_values_to_be_between`,
  and `dbt_utils.expression_is_true` (`scheduled_arrival_utc >= scheduled_departure_utc`).
- One singular business-rule test,
  `tests/business_rules/airline_route_origin_destination_distinct.sql`, asserting no airline
  route has an identical origin and destination airport identifier.

## Scope Boundary

This document covers route, schedule, flight-operation, aircraft, and AirStats conformance models.
Booking, ticketing, pricing, invoicing, payment, refund, revenue-recognition, reconciliation, and
commercial-reporting logic are documented in their own domain files under `docs/data_models/`.
