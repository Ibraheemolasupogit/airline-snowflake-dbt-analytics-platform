# Refund Assurance Report

**As of:** 2026-01-15 (the dataset's fixed synthetic as-of date)
**Scope:** Refund source-to-warehouse controls (Milestone 19), and this milestone's central
business-anomaly-vs-reconciliation-failure distinction.

## Implemented models

- `models/intermediate/reconciliation/int_refund_reconciliation.sql`
- `models/core/facts/fct_reconciliation_controls.sql`

## Results (offline evidence: `outputs/daily_refund_control_totals.csv`)

| Control | Source | Warehouse (expected) | Status |
| --- | --- | --- | --- |
| `refund.refund_count` | 7 | 7 | pass |
| `refund.refund_total_value` | 67,888.54 | 67,888.54 | pass |

## The controlled anomaly, and why it still reconciles

`refunds.csv` contains one deliberately injected `refund_greater_than_collected_amount` controlled
exception: a refund's `amount` was raised by exactly `100.0` above the amount actually collected on
its linked payment (`scripts/airline_synth/exceptions.py`). `refund.refund_total_value` sums
`fct_refunds.refund_amount` **uncapped** -- Milestone 16 never corrects or caps a refund's own
stored amount -- so this inflated figure is summed into both the source total (67,888.54) and the
warehouse total (67,888.54) identically. The control reports `pass` correctly: the ETL faithfully
reproduced the source, anomalous value included.

That same record is **separately and correctly** flagged as a `refund_greater_than_collected_amount`
billing exception by `fct_billing_exceptions` (Milestone 18). Both facts are true simultaneously --
`tests/business_rules/airline_reconciliation_anomaly_reconciles_despite_exception.sql` asserts this
exact dual expectation in dbt, and
`tests/python/test_reconciliation_evidence.py::test_refund_control_totals_reconcile_despite_the_controlled_anomaly`
asserts the reconciliation half offline. A data-quality/business anomaly is not the same thing as a
source-to-warehouse reconciliation failure, and this milestone deliberately does not conflate them.

## Offline validation performed

- `scripts/generate_reconciliation_evidence.py` executed against the checked-in synthetic dataset.
- The two tests named above, both passing.
- dbt `parse`/`ls`/SQLFluff/pre-commit static validation (see the Milestone 19 completion report).

## Warehouse-backed execution

**Not performed.** No Snowflake connection was used. The "Warehouse (expected)" figures are a
deterministic offline recomputation from `refunds.csv`, mirroring `fct_refunds.refund_amount`'s own
unmodified passthrough exactly -- not an executed `dbt run` result.
