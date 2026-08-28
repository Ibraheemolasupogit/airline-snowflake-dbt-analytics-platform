#!/usr/bin/env python3
"""Compute deterministic source-level control totals for the synthetic dataset.

Usage:
    python scripts/generate_control_totals.py [--data-dir data/synthetic]
        [--output data/synthetic/control_totals.json]

Reads the CSV files already written by ``generate_airline_data.py`` and
aggregates simple counts/values useful for later reconciliation milestones:
booking count/value, invoice count/value, successful payment count/value,
refund count/value, flight-instance count, and ticket count.

These are SYNTHETIC SOURCE control totals only. They describe the generated
CSVs as they stand; they are not warehouse-computed reconciliation results,
and this script never connects to Snowflake. Figures are computed exactly as
generated, including deliberately injected exceptions (for example the
duplicate invoice), so a later reconciliation model that recomputes these
totals from dbt models has something meaningful to compare against.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from airline_synth.config import AS_OF_DATE
from airline_synth.utils import date_to_iso, read_csv

REPO_ROOT = Path(__file__).resolve().parents[1]


def _sum_amount(rows: list[dict], field: str = "total_amount") -> float:
    return round(sum(float(row[field]) for row in rows), 2)


def compute_control_totals(data_dir: Path) -> dict:
    bookings = read_csv(data_dir / "bookings" / "bookings.csv")
    invoices = read_csv(data_dir / "billing" / "invoices.csv")
    payments = read_csv(data_dir / "billing" / "payments.csv")
    refunds = read_csv(data_dir / "billing" / "refunds.csv")
    flight_instances = read_csv(data_dir / "operations" / "flight_instances.csv")
    tickets = read_csv(data_dir / "bookings" / "tickets.csv")

    successful_payments = [p for p in payments]  # every row in payments.csv is a successful transaction

    return {
        "as_of_date": date_to_iso(AS_OF_DATE),
        "control_totals": {
            "booking_count": len(bookings),
            "booking_confirmed_count": sum(1 for b in bookings if b["status"] != "cancelled"),
            "booking_cancelled_count": sum(1 for b in bookings if b["status"] == "cancelled"),
            "invoice_count": len(invoices),
            "invoice_total_value": _sum_amount(invoices, "total_amount"),
            "successful_payment_count": len(successful_payments),
            "successful_payment_total_value": _sum_amount(successful_payments, "amount"),
            "refund_count": len(refunds),
            "refund_total_value": _sum_amount(refunds, "amount"),
            "flight_instance_count": len(flight_instances),
            "flight_instance_completed_count": sum(1 for f in flight_instances if f["status"] == "completed"),
            "flight_instance_cancelled_count": sum(1 for f in flight_instances if f["status"] == "cancelled"),
            "flight_instance_scheduled_count": sum(1 for f in flight_instances if f["status"] == "scheduled"),
            "ticket_count": len(tickets),
        },
        "notes": (
            "Values are computed as-generated, including deliberately injected exceptions "
            "(for example the duplicate invoice in exception_manifest.csv). Amounts are summed "
            "in each row's native currency without cross-currency conversion, so 'total_value' "
            "figures are illustrative multi-currency sums, not a single reporting currency total."
        ),
    }


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=str, default="data/synthetic")
    parser.add_argument("--output", type=str, default="data/synthetic/control_totals.json")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    data_dir = Path(args.data_dir)
    if not data_dir.is_absolute():
        data_dir = REPO_ROOT / data_dir
    output_path = Path(args.output)
    if not output_path.is_absolute():
        output_path = REPO_ROOT / output_path

    totals = compute_control_totals(data_dir)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as handle:
        json.dump(totals, handle, indent=2, sort_keys=True)
        handle.write("\n")

    print(f"Wrote control totals to {output_path}")
    for key, value in sorted(totals["control_totals"].items()):
        print(f"  {key}: {value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
