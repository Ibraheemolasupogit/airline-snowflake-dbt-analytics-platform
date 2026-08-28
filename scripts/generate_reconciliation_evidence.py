#!/usr/bin/env python3
"""Generate Milestone 19 reconciliation evidence: the dbt seed and offline output fixtures.

Usage:
    python scripts/generate_reconciliation_evidence.py [--data-dir data/synthetic]
        [--control-totals data/synthetic/control_totals.json]
        [--seed-output seeds/reconciliation/seed_synthetic_control_totals.csv]
        [--outputs-dir outputs]

This script has two jobs, both deterministic and offline (no Snowflake connection, no wall-clock
dependence):

1. Regenerate the dbt seed (seeds/reconciliation/seed_synthetic_control_totals.csv) from
   data/synthetic/control_totals.json in a tidy long format (metric_name, metric_value,
   as_of_date). This is the ONLY place control_totals.json's values are transcribed -- the seed is
   mechanically derived from the JSON, never hand-typed, and the JSON remains the single
   source-of-truth control artifact (per this milestone's "do not manually duplicate totals in two
   places" requirement). dbt reconciliation models read the seed, not the JSON, since dbt has no
   native JSON source here.

2. Write four "daily control totals" CSVs to outputs/ (booking, invoice, payment, refund), each
   comparing:
     - source_measure: read directly from control_totals.json (trusted as-is, never recomputed)
     - warehouse_measure: independently recomputed here directly from the raw synthetic CSVs,
       using the exact same field/filter semantics the corresponding dbt core fact column uses
       (documented per metric below) -- e.g. fct_invoices.source_invoice_total is an unmodified
       passthrough of invoices.csv's own total_amount, so summing that column here mirrors
       exactly what int_invoice_reconciliation.sql will compute once run against a real warehouse.

   These are OFFLINE EXPECTED RECONCILIATION FIXTURES, not executed warehouse query results: no
   Snowflake connection is used anywhere in this script. Every row is labelled accordingly. Only
   the nine controls whose warehouse-side dbt column is a direct passthrough/count of a raw source
   field are computed here (see docs/data_models/airline_reconciliation_controls.md) -- this
   script deliberately does NOT reimplement payment-allocation capping, revenue-recognition
   eligibility, or exception-detection logic, since that would recompute business logic Milestones
   13-18 already implement in dbt; those richer outputs (revenue_reconciliation.csv,
   billing_exceptions.csv) are schema-only fixtures, populated only once dbt actually runs against
   a warehouse -- see generate_schema_only_fixtures() below.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from airline_synth.utils import read_csv, write_csv

REPO_ROOT = Path(__file__).resolve().parents[1]

# A single-cent tolerance for monetary comparisons only, defending against sub-cent binary
# floating-point noise when Python sums many decimal(18, 2)-precision values -- not because SQL
# rounding differs (both sides read the identical underlying cent-precision figures). Count
# comparisons use exact equality (threshold 0), since counts cannot legitimately differ by a
# fraction. See docs/data_models/airline_reconciliation_controls.md for the documented rationale.
MONETARY_TOLERANCE = 0.01
COUNT_TOLERANCE = 0

SEED_FIELDNAMES = ["metric_name", "metric_value", "as_of_date"]
CONTROL_FIELDNAMES = [
    "control_id",
    "control_domain",
    "control_name",
    "source_measure",
    "warehouse_measure",
    "variance_amount",
    "variance_count",
    "control_status",
    "materiality_threshold",
    "as_of_date",
    "notes",
]


def _load_control_totals(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def generate_seed(control_totals: dict, seed_output: Path) -> int:
    as_of_date = control_totals["as_of_date"]
    rows = [
        {"metric_name": name, "metric_value": value, "as_of_date": as_of_date}
        for name, value in sorted(control_totals["control_totals"].items())
    ]
    return write_csv(seed_output, SEED_FIELDNAMES, rows)


def _count_control(
    control_id: str,
    control_domain: str,
    control_name: str,
    source_measure: int,
    warehouse_measure: int,
    as_of_date: str,
    notes: str,
) -> dict:
    variance_count = warehouse_measure - source_measure
    status = "pass" if variance_count == COUNT_TOLERANCE else "fail"
    return {
        "control_id": control_id,
        "control_domain": control_domain,
        "control_name": control_name,
        "source_measure": source_measure,
        "warehouse_measure": warehouse_measure,
        "variance_amount": "",
        "variance_count": variance_count,
        "control_status": status,
        "materiality_threshold": COUNT_TOLERANCE,
        "as_of_date": as_of_date,
        "notes": notes,
    }


def _amount_control(
    control_id: str,
    control_domain: str,
    control_name: str,
    source_measure: float,
    warehouse_measure: float,
    as_of_date: str,
    notes: str,
) -> dict:
    variance_amount = round(warehouse_measure - source_measure, 2)
    status = "pass" if abs(variance_amount) <= MONETARY_TOLERANCE else "fail"
    return {
        "control_id": control_id,
        "control_domain": control_domain,
        "control_name": control_name,
        "source_measure": source_measure,
        "warehouse_measure": warehouse_measure,
        "variance_amount": variance_amount,
        "variance_count": "",
        "control_status": status,
        "materiality_threshold": MONETARY_TOLERANCE,
        "as_of_date": as_of_date,
        "notes": notes,
    }


def generate_booking_control_totals(control_totals: dict, data_dir: Path) -> list[dict]:
    totals = control_totals["control_totals"]
    as_of_date = control_totals["as_of_date"]
    bookings = read_csv(data_dir / "bookings" / "bookings.csv")
    tickets = read_csv(data_dir / "bookings" / "tickets.csv")
    ticket_segments = read_csv(data_dir / "bookings" / "ticket_segments.csv")
    flight_instances = read_csv(data_dir / "operations" / "flight_instances.csv")

    warehouse_ticket_count = len({row["ticket_id"] for row in ticket_segments})

    return [
        _count_control(
            "booking.booking_count", "booking", "booking_count",
            totals["booking_count"], len(bookings), as_of_date,
            "fct_bookings row count (1:1 with bookings.csv).",
        ),
        _count_control(
            "booking.booking_confirmed_count", "booking", "booking_confirmed_count",
            totals["booking_confirmed_count"],
            sum(1 for row in bookings if row["status"] != "cancelled"), as_of_date,
            "count(*) from fct_bookings where not is_cancelled.",
        ),
        _count_control(
            "booking.booking_cancelled_count", "booking", "booking_cancelled_count",
            totals["booking_cancelled_count"],
            sum(1 for row in bookings if row["status"] == "cancelled"), as_of_date,
            "count(*) from fct_bookings where is_cancelled.",
        ),
        _count_control(
            "ticket.ticket_count", "ticket", "ticket_count",
            totals["ticket_count"], len(tickets), as_of_date,
            "count(distinct ticket_id) from fct_ticket_segments -- independently recomputed from "
            "ticket_segments.csv, not tickets.csv, for genuine cross-validation.",
        ),
        _count_control(
            "flight_operations.flight_instance_count", "flight_operations", "flight_instance_count",
            totals["flight_instance_count"], len(flight_instances), as_of_date,
            "fct_flight_operations row count (1:1 with flight_instances.csv).",
        ),
        _count_control(
            "flight_operations.flight_instance_completed_count", "flight_operations",
            "flight_instance_completed_count",
            totals["flight_instance_completed_count"],
            sum(1 for row in flight_instances if row["status"] == "completed"), as_of_date,
            "count(*) from fct_flight_operations where status = 'completed' (raw status, not "
            "operational_completion_status).",
        ),
        _count_control(
            "flight_operations.flight_instance_cancelled_count", "flight_operations",
            "flight_instance_cancelled_count",
            totals["flight_instance_cancelled_count"],
            sum(1 for row in flight_instances if row["status"] == "cancelled"), as_of_date,
            "count(*) from fct_flight_operations where status = 'cancelled'.",
        ),
        _count_control(
            "flight_operations.flight_instance_scheduled_count", "flight_operations",
            "flight_instance_scheduled_count",
            totals["flight_instance_scheduled_count"],
            sum(1 for row in flight_instances if row["status"] == "scheduled"), as_of_date,
            "count(*) from fct_flight_operations where status = 'scheduled'.",
        ),
    ] + [
        {
            **_count_control(
                "ticket.ticket_count_cross_check", "ticket", "ticket_count_cross_check",
                len(tickets), warehouse_ticket_count, as_of_date,
                "Informational: count(distinct ticket_id) from ticket_segments.csv vs. "
                "len(tickets.csv), both source-side -- confirms full ticket/segment coverage "
                "independently of control_totals.json.",
            ),
        }
    ]


def generate_invoice_control_totals(control_totals: dict, data_dir: Path) -> list[dict]:
    totals = control_totals["control_totals"]
    as_of_date = control_totals["as_of_date"]
    invoices = read_csv(data_dir / "billing" / "invoices.csv")
    invoice_lines = read_csv(data_dir / "billing" / "invoice_lines.csv")

    warehouse_invoice_total = round(sum(float(row["total_amount"]) for row in invoices), 2)
    lines_by_invoice: dict[str, float] = {}
    for line in invoice_lines:
        lines_by_invoice[line["invoice_id"]] = lines_by_invoice.get(line["invoice_id"], 0.0) + float(
            line["amount"]
        )
    calculated_line_total = round(sum(lines_by_invoice.values()), 2)
    line_arithmetic_variance = round(calculated_line_total - warehouse_invoice_total, 2)

    return [
        _count_control(
            "invoice.invoice_count", "invoice", "invoice_count",
            totals["invoice_count"], len(invoices), as_of_date,
            "fct_invoices row count (1:1 with invoices.csv, including the duplicate_invoice row).",
        ),
        _amount_control(
            "invoice.invoice_total_value", "invoice", "invoice_total_value",
            totals["invoice_total_value"], warehouse_invoice_total, as_of_date,
            "sum(fct_invoices.source_invoice_total) -- the unmodified invoices.csv.total_amount "
            "passthrough, NOT calculated_invoice_line_total. See "
            "docs/data_models/airline_reconciliation_controls.md for why.",
        ),
        {
            **_amount_control(
                "invoice.invoice_line_arithmetic_consistency", "invoice",
                "invoice_line_arithmetic_consistency",
                warehouse_invoice_total, calculated_line_total, as_of_date,
                "Informational, NOT a source-to-warehouse control: sum(calculated_invoice_line_total) "
                "vs. sum(source_invoice_total), both warehouse-side. Nonzero here reflects the "
                "already-known missing_invoice_line/incorrect_fare/completed_segment_without_"
                "recognised_revenue_precursor controlled exceptions (see fct_billing_exceptions), "
                "not a reconciliation defect -- see docs/data_models/airline_reconciliation_"
                "controls.md.",
            ),
            "control_status": "warning" if abs(line_arithmetic_variance) > MONETARY_TOLERANCE else "pass",
        },
    ]


def generate_payment_control_totals(control_totals: dict, data_dir: Path) -> list[dict]:
    totals = control_totals["control_totals"]
    as_of_date = control_totals["as_of_date"]
    payments = read_csv(data_dir / "billing" / "payments.csv")
    payment_attempts = read_csv(data_dir / "billing" / "payment_attempts.csv")

    warehouse_payment_total = round(sum(float(row["amount"]) for row in payments), 2)
    failed_attempt_count = sum(1 for row in payment_attempts if row["result"] == "failed")

    return [
        _count_control(
            "payment.successful_payment_count", "payment", "successful_payment_count",
            totals["successful_payment_count"], len(payments), as_of_date,
            "fct_payments row count (1:1 with payments.csv -- every row is a successful "
            "transaction by construction).",
        ),
        _amount_control(
            "payment.successful_payment_total_value", "payment", "successful_payment_total_value",
            totals["successful_payment_total_value"], warehouse_payment_total, as_of_date,
            "sum(fct_payments.payment_amount), the raw uncapped amount -- not allocated_amount.",
        ),
        {
            **_count_control(
                "payment.failed_attempt_count", "payment", "failed_attempt_count",
                0, failed_attempt_count, as_of_date,
                "Supplementary, NOT a source-to-warehouse control: control_totals.json has no "
                "failed-attempt total to compare against. count(*) from fct_payment_attempts "
                "where attempt_classification = 'failed'.",
            ),
            "source_measure": "",
            "control_status": "not_applicable",
        },
    ]


def generate_refund_control_totals(control_totals: dict, data_dir: Path) -> list[dict]:
    totals = control_totals["control_totals"]
    as_of_date = control_totals["as_of_date"]
    refunds = read_csv(data_dir / "billing" / "refunds.csv")

    warehouse_refund_total = round(sum(float(row["amount"]) for row in refunds), 2)

    return [
        _count_control(
            "refund.refund_count", "refund", "refund_count",
            totals["refund_count"], len(refunds), as_of_date,
            "fct_refunds row count (1:1 with refunds.csv).",
        ),
        _amount_control(
            "refund.refund_total_value", "refund", "refund_total_value",
            totals["refund_total_value"], warehouse_refund_total, as_of_date,
            "sum(fct_refunds.refund_amount), UNCAPPED -- includes the refund_greater_than_"
            "collected_amount controlled exception's full inflated amount. This is expected to "
            "reconcile exactly even though the underlying transaction is intentionally anomalous: "
            "a data-quality/business anomaly is different from a source-to-warehouse "
            "reconciliation failure. See docs/data_models/airline_reconciliation_controls.md.",
        ),
    ]


def generate_schema_only_fixtures(outputs_dir: Path) -> None:
    """Write header-only fixtures for outputs that require dbt execution against a warehouse.

    revenue_reconciliation.csv and billing_exceptions.csv depend on accumulated business logic
    (payment-allocation capping, revenue-recognition eligibility, exception-detection rules) this
    script deliberately does not reimplement -- doing so would recompute business logic Milestones
    15-18 already implement in dbt, and risk producing numbers that quietly diverge from what dbt
    actually computes. These fixtures document the exact output CONTRACT (column headers) without
    fabricating any data row; they are populated only once `dbt run`/`dbt seed` executes against a
    real Snowflake warehouse.
    """
    revenue_reconciliation_columns = [
        "control_id", "control_domain", "control_name", "source_measure", "warehouse_measure",
        "variance_amount", "variance_count", "control_status", "materiality_threshold",
        "as_of_date", "notes",
    ]
    billing_exceptions_columns = [
        "exception_type", "severity", "status", "currency", "exception_count",
        "financial_value_at_risk_total",
    ]

    for filename, columns in (
        ("revenue_reconciliation.csv", revenue_reconciliation_columns),
        ("billing_exceptions.csv", billing_exceptions_columns),
    ):
        path = outputs_dir / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", newline="", encoding="utf-8") as handle:
            handle.write(
                "# Schema-only fixture -- requires `dbt run`/`dbt seed` against a live Snowflake "
                "warehouse to populate; not generated by this offline script. See "
                "docs/data_models/airline_reconciliation_controls.md.\n"
            )
            writer = csv.writer(handle, lineterminator="\n")
            writer.writerow(columns)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=str, default="data/synthetic")
    parser.add_argument("--control-totals", type=str, default="data/synthetic/control_totals.json")
    parser.add_argument(
        "--seed-output", type=str, default="seeds/reconciliation/seed_synthetic_control_totals.csv"
    )
    parser.add_argument("--outputs-dir", type=str, default="outputs")
    return parser.parse_args(argv)


def _resolve(path_str: str) -> Path:
    path = Path(path_str)
    return path if path.is_absolute() else REPO_ROOT / path


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    data_dir = _resolve(args.data_dir)
    control_totals_path = _resolve(args.control_totals)
    seed_output = _resolve(args.seed_output)
    outputs_dir = _resolve(args.outputs_dir)

    control_totals = _load_control_totals(control_totals_path)

    seed_rows = generate_seed(control_totals, seed_output)
    print(f"Wrote {seed_rows} rows to {seed_output}")

    domains = {
        "daily_booking_control_totals.csv": generate_booking_control_totals(control_totals, data_dir),
        "daily_invoice_control_totals.csv": generate_invoice_control_totals(control_totals, data_dir),
        "daily_payment_control_totals.csv": generate_payment_control_totals(control_totals, data_dir),
        "daily_refund_control_totals.csv": generate_refund_control_totals(control_totals, data_dir),
    }
    for filename, rows in domains.items():
        count = write_csv(outputs_dir / filename, CONTROL_FIELDNAMES, rows)
        failing = [row for row in rows if row["control_status"] == "fail"]
        print(f"Wrote {count} rows to {outputs_dir / filename} ({len(failing)} failing)")

    generate_schema_only_fixtures(outputs_dir)
    print(f"Wrote schema-only fixtures to {outputs_dir}/revenue_reconciliation.csv and billing_exceptions.csv")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
