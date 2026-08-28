# Month-End Financial Assurance Report

**As of:** 2026-01-15 (the dataset's own fixed synthetic as-of date -- never wall-clock-dependent)
**Scope:** A single month-end-style snapshot across bookings, invoices, payments, refunds,
adjustments, recognised revenue, outstanding balances, and billing exceptions (Milestone 19).

## Implemented model

- `models/intermediate/reconciliation/int_month_end_financial_assurance.sql` -- grain: one row,
  reusing every measure from an existing fact unchanged; no new calculation.

## Measures available offline (from `scripts/generate_reconciliation_evidence.py`)

| Measure | Value |
| --- | --- |
| `booking_count` | 180 |
| `invoice_count` | 181 |
| `invoice_total_value` | 8,117,998.23 |
| `payment_count` | 171 |
| `payment_total_value` | 7,986,366.42 |
| `refund_count` | 7 |
| `refund_total_value` | 67,888.54 |

These are the same direct source-to-warehouse controls documented in `billing_reconciliation_report.md`,
`payment_assurance_report.md`, and `refund_assurance_report.md` -- all deterministically
recomputed offline from the raw synthetic CSVs, not warehouse-executed.

## Measures requiring warehouse execution (not reported here)

`amount_collected_total`, `net_adjustment_total`, `adjustment_count`,
`net_recognised_revenue_total`, `outstanding_balance_total`, `billing_exception_count`, and
`billing_exception_financial_value_at_risk_total` all depend on business logic already implemented
in dbt (payment-allocation capping, revenue-recognition eligibility, exception-detection rules)
that this milestone deliberately does not reimplement in Python. `int_month_end_financial_assurance.sql`
computes all of them by reusing the relevant existing fact column directly; this report does not
fabricate their values in the absence of an executed `dbt run`.

## Offline validation performed

- dbt `parse`/`ls` confirm `int_month_end_financial_assurance` resolves and reuses only existing
  facts.
- SQLFluff/pre-commit static validation (see the Milestone 19 completion report).

## Warehouse-backed execution

**Not performed.** No Snowflake connection was used anywhere in this milestone. This report
distinguishes exactly which figures are genuine deterministic offline evidence (above) from which
require a real warehouse run to populate.
