# Payment Assurance Report

**As of:** 2026-01-15 (the dataset's fixed synthetic as-of date)
**Scope:** Payment source-to-warehouse controls (Milestone 19).

## Implemented models

- `models/intermediate/reconciliation/int_payment_reconciliation.sql`
- `models/core/facts/fct_reconciliation_controls.sql`

## Results (offline evidence: `outputs/daily_payment_control_totals.csv`)

| Control | Source | Warehouse (expected) | Status |
| --- | --- | --- | --- |
| `payment.successful_payment_count` | 171 | 171 | pass |
| `payment.successful_payment_total_value` | 7,986,366.42 | 7,986,366.42 | pass |
| `payment.failed_attempt_count` (supplementary) | n/a | 25 | not_applicable |

`successful_payment_total_value` compares `sum(fct_payments.payment_amount)` -- the raw,
**uncapped** amount actually collected -- against `control_totals.json`'s own definition (every row
in `payments.csv` summed with no capping). It deliberately does **not** use `allocated_amount`
(Milestone 15's invoice-capped figure), which answers a different question ("how much was applied
toward its invoice") than this control ("how much cash was actually collected").

`failed_attempt_count` (25 failed attempts, from `fct_payment_attempts`) is supplementary evidence
only: `control_totals.json` has no failed-attempt total to compare against, so this row is reported
as `not_applicable`, never as a pass/fail judgement.

## Offline validation performed

- `scripts/generate_reconciliation_evidence.py` executed against the checked-in synthetic dataset.
- `tests/python/test_reconciliation_evidence.py::test_payment_control_totals_pass_and_failed_attempts_are_supplementary`
  asserts both controls pass and the failed-attempt row is correctly marked supplementary.
- dbt `parse`/`ls`/SQLFluff/pre-commit static validation (see the Milestone 19 completion report).

## Warehouse-backed execution

**Not performed.** No Snowflake connection was used. The "Warehouse (expected)" figures are a
deterministic offline recomputation from `payments.csv`/`payment_attempts.csv`, mirroring
`fct_payments`/`fct_payment_attempts`'s own unmodified passthrough columns exactly -- not an
executed `dbt run` result.
