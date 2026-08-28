# Billing Reconciliation Report

**As of:** 2026-01-15 (the dataset's fixed synthetic as-of date)
**Scope:** Booking and invoice source-to-warehouse controls (Milestone 19).

## Implemented models

- `models/intermediate/reconciliation/int_booking_reconciliation.sql`
- `models/intermediate/reconciliation/int_invoice_reconciliation.sql`
- `models/intermediate/reconciliation/int_financial_control_summary.sql`
- `models/core/facts/fct_reconciliation_controls.sql`

## Deterministic source controls

Source: `data/synthetic/control_totals.json`, re-expressed as
`seeds/reconciliation/seed_synthetic_control_totals.csv` by `scripts/generate_reconciliation_evidence.py`
(never hand-typed). See `docs/data_models/airline_reconciliation_controls.md` for the full
provenance and formula documentation.

## Results (offline evidence: `outputs/daily_booking_control_totals.csv`, `outputs/daily_invoice_control_totals.csv`)

| Control | Source | Warehouse (expected) | Status |
| --- | --- | --- | --- |
| `booking.booking_count` | 180 | 180 | pass |
| `booking.booking_confirmed_count` | 173 | 173 | pass |
| `booking.booking_cancelled_count` | 7 | 7 | pass |
| `ticket.ticket_count` | 290 | 290 | pass |
| `flight_operations.flight_instance_count` | 864 | 864 | pass |
| `flight_operations.flight_instance_completed_count` | 623 | 623 | pass |
| `flight_operations.flight_instance_cancelled_count` | 1 | 1 | pass |
| `flight_operations.flight_instance_scheduled_count` | 240 | 240 | pass |
| `invoice.invoice_count` | 181 | 181 | pass |
| `invoice.invoice_total_value` | 8,117,998.23 | 8,117,998.23 | pass |
| `invoice.invoice_line_arithmetic_consistency` (informational) | 8,117,998.23 | 8,254,743.17 | **warning** |

All twelve direct source-to-warehouse controls pass exactly. The one `warning` is expected and
documented: it reflects three already-known Milestone 9 controlled exceptions
(`missing_invoice_line`, `incorrect_fare`, `completed_segment_without_recognised_revenue_precursor`),
each already correctly classified by `fct_billing_exceptions` (Milestone 18) -- it is not a
reconciliation failure.

## Offline validation performed

- `scripts/generate_reconciliation_evidence.py` executed against the checked-in synthetic dataset
  (see `tests/python/test_reconciliation_evidence.py` for automated assertions on these figures).
- dbt `parse`/`ls`/SQLFluff/pre-commit static validation (see the Milestone 19 completion report).

## Warehouse-backed execution

**Not performed.** No Snowflake connection was used to produce any figure in this report or in
`outputs/`. The "Warehouse (expected)" column above is a deterministic offline recomputation from
the same raw synthetic CSVs the dbt models read, using identical field/filter semantics -- not an
executed `dbt run` result.
