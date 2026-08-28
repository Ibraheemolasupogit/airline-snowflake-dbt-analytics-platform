# Revenue Recognition Bridge Report

**As of:** 2026-01-15 (the dataset's fixed synthetic as-of date)
**Scope:** The financial bridge across invoiced value, collected cash, refunds, adjustments,
recognised revenue, and outstanding balance (Milestone 19). This is not a source-to-warehouse
reconciliation -- see below.

## Implemented model

- `models/intermediate/reconciliation/int_revenue_reconciliation.sql` (feeds
  `int_financial_control_summary` / `fct_reconciliation_controls`)

## Why this is a bridge, not a control

`data/synthetic/control_totals.json` contains no recognised-revenue total. More fundamentally,
invoice total, cash collected, and net recognised revenue describe genuinely different
business/accounting states, by design (Milestone 17):

- **Invoice total** (`fct_invoices.source_invoice_total`) -- what was billed, regardless of whether
  it was ever paid or the underlying service ever flew.
- **Cash collected** (`fct_invoices.amount_collected`) -- money actually applied toward invoices
  (Milestone 15), independent of whether the ticket has flown.
- **Net recognised revenue** (`fct_revenue.net_recognised_amount`) -- earned revenue, recognised
  only once a service is actually fulfilled (Milestone 17), independent of billing or payment
  timing.

`int_revenue_reconciliation` reports every row with `control_status = 'not_applicable'` for exactly
this reason: forcing these three measures to equal one another would be a false assertion this
milestone's own scope explicitly forbids.

## Bridge measures produced (schema, not fabricated figures)

```text
invoiced_value              sum(fct_invoices.source_invoice_total)
collected_cash               sum(fct_invoices.amount_collected)
refund_total                  sum(fct_refunds.refund_amount)
net_adjustment_total         sum(fct_invoices.net_adjustment_amount)
net_recognised_revenue       sum(fct_revenue.net_recognised_amount)
outstanding_balance_total    sum(fct_outstanding_balances.outstanding_balance)
```

## Warehouse-backed execution

**Not performed, and actual figures are not reported here.** `collected_cash` depends on
Milestone 15's payment-allocation capping logic and `net_recognised_revenue` depends on Milestone
17's fulfilment-eligibility logic -- both are business logic already implemented in dbt that this
milestone deliberately does not reimplement in Python (doing so would risk producing numbers that
silently diverge from what dbt actually computes). `outputs/revenue_reconciliation.csv` is
correspondingly a **schema-only fixture** (column headers only, explicitly labelled, zero data
rows) -- it will be populated only once `dbt run` executes against a live Snowflake warehouse. This
report documents the bridge's structure and intent, not its executed values.
