# Airline Synthetic Exception Catalogue

## Purpose

`scripts/airline_synth/exceptions.py` deterministically plants 14 documented
exceptions into the otherwise-clean Milestone 9 synthetic dataset, so that
Milestone 10+ dbt assurance and reconciliation models have carefully
controlled, known defects to detect. Every exception is chosen by
deterministic index/lookup against the already-generated dataset -- never by
fresh randomness -- so the same seed always plants the same exceptions on the
same records. This milestone does **not** build the dbt detection models
themselves; it only plants the source-data conditions they will need to
catch.

The machine-readable record is `data/synthetic/exception_manifest.csv`, with
one row per exception: `exception_id`, `exception_type`, `affected_entity`,
`affected_record_key`, `expected_detection_rule`, `rationale`.
`scripts/validate_source_data.py` reads this manifest so it can tell an
intentional exception apart from an unexpected integrity defect, and never
"fixes" a planted exception.

## Catalogue

| # | `exception_type` | Affected entity | What was done |
| - | --- | --- | --- |
| 1 | `duplicate_invoice` | `invoices` | Cloned an existing invoice and its lines under a new `invoice_id` (suffix `-DUP`) for the same `booking_id`, simulating an accidental double-bill. |
| 2 | `failed_payment` | `invoices` | Selected an invoice whose every payment attempt failed, so no row exists for it in `payments.csv`. |
| 3 | `unallocated_payment` | `payments` | Raised a successful payment's `amount` above its invoice's `total_amount` and set `allocation_status = 'overpaid_unallocated'`. |
| 4 | `incorrect_fare` | `invoice_lines` | Overwrote a `base_fare` line's `amount` to a value inconsistent with `fare_classes.base_fare_usd + per_km_usd * route distance`. |
| 5 | `refund_greater_than_collected_amount` | `refunds` | Raised a refund's `amount` above the `amount` actually collected on its linked `payments` row. |
| 6 | `cancelled_flight_without_refund` | `flight_instances` | Flipped an already-`completed` flight instance to `status = 'cancelled'` post-hoc and cancelled its `ticket_segments`, while deliberately leaving the associated booking/invoice/payment untouched -- so no refund exists for the affected passengers. |
| 7 | `late_arriving_payment` | `payments` | Shifted a successful payment's `payment_datetime_utc` to 75 days after its invoice date (normal turnaround is hours). |
| 8 | `missing_invoice_line` | `invoices` | Removed an invoice's `tax` line without adjusting the invoice header, so `sum(invoice_lines.amount)` no longer reconciles to `invoices.total_amount`. |
| 9 | `completed_segment_without_recognised_revenue_precursor` | `ticket_segments` | Removed the `base_fare` invoice line for a ticket whose segment is `segment_status = 'flown'`, so a fulfilled service has no billed revenue precursor. |
| 10 | `payment_without_invoice` | `payments` | Appended a payment referencing `invoice_id = 'INV-99999'`, which does not exist in `invoices.csv`. |
| 11 | `ancillary_sold_but_not_fulfilled` | `ancillary_services` | Forced `fulfilment_status = 'not_fulfilled'` on an ancillary sold against an otherwise-flown ticket. |
| 12 | `ancillary_fulfilled_but_not_billed` | `ancillary_services` | Removed the `invoice_line` for an ancillary service already marked `fulfilment_status = 'fulfilled'`. |
| 13 | `currency_mismatch` | `payments` | Set a payment's `currency` to a different code than its invoice's `currency`, with no recorded conversion. |
| 14 | `invalid_adjustment` | `adjustments` | Appended an adjustment referencing `invoice_id = 'INV-99998'` (non-existent) with an implausibly large amount (999,999). |

## How to Read the Manifest

Each row's `expected_detection_rule` states, in plain language, the rule a
later dbt test or reconciliation model should apply. For example, exception 8
(`missing_invoice_line`) documents: *"sum(invoice_lines.amount) for an
invoice should reconcile to invoice.total_amount."* A Milestone 10+ model
that implements that rule should flag exactly the `invoice_id` named in that
row's `affected_record_key` -- and, in a well-behaved dataset, nothing else.

`affected_record_key` is usually a single natural key (e.g. a `payment_id`),
but for exceptions that involve two related records (`duplicate_invoice`) it
is a `|`-separated pair naming both.

## Verifying the Catalogue

`scripts/validate_source_data.py::verify_exception_fingerprints` re-derives
each exception's structural signature directly from the generated CSVs (for
example, for `unallocated_payment` it checks that the named payment's amount
actually exceeds its invoice's total) and confirms the manifest contains
exactly these 14 types, once each -- no more, no fewer. The same checks are
exercised as pytest tests in `tests/python/test_synthetic_generator.py`.

## Scope Boundary

This milestone deliberately does **not** implement the dbt-side detection
logic (billing exception models, reconciliation marts, etc.) -- that begins
in Milestone 18 (Outstanding Balances and Billing Exceptions) and Milestone
19 (Reconciliation Controls). This catalogue exists so those later
milestones have a known-correct answer key to build and test against.
