#!/usr/bin/env python3
"""Validate the generated synthetic airline dataset without dbt or Snowflake.

Usage:
    python scripts/validate_source_data.py [--data-dir data/synthetic]

Checks (see docs/data_models/airline_synthetic_source_data.md for detail):
    - every expected CSV file exists
    - primary keys are unique per entity
    - mandatory key columns are non-null
    - foreign keys resolve, except where the exception manifest says they
      were deliberately broken
    - the exception manifest contains exactly the fourteen documented
      exception types, once each, and each one's structural fingerprint is
      actually present in the data
    - currencies referenced anywhere are present in currencies.csv
    - invoice_line -> invoice / ticket relationships are structurally usable
    - payments/refunds reference the expected source entities
    - repeated generator runs are byte-for-byte deterministic

This script never "fixes" a deliberately injected exception. It reports
"UNEXPECTED" for anything not covered by the manifest and "INTENTIONAL" for
anything the manifest explains, then exits non-zero only when an unexpected
defect is found.
"""

from __future__ import annotations

import argparse
import filecmp
import subprocess
import sys
import tempfile
from collections import defaultdict
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from generate_airline_data import OUTPUT_PATHS
from airline_synth.utils import read_csv

REPO_ROOT = Path(__file__).resolve().parents[1]

PRIMARY_KEYS: dict[str, str] = {
    "airports": "ident",
    "currencies": "currency_code",
    "exchange_rates": "currency_code",
    "airlines": "airline_code",
    "aircraft_types": "aircraft_type_code",
    "aircraft": "aircraft_registration",
    "routes": "route_id",
    "flight_schedules": "schedule_id",
    "flight_instances": "flight_instance_id",
    "passengers": "passenger_id",
    "bookings": "booking_id",
    "booking_passengers": "booking_passenger_id",
    "tickets": "ticket_id",
    "ticket_segments": "ticket_segment_id",
    "products": "product_code",
    "services": "service_code",
    "ancillary_services": "ancillary_service_id",
    "fare_classes": "fare_class_code",
    "fare_rules": "fare_rule_id",
    "airport_fees": "airport_fee_id",
    "taxes": "tax_id",
    "discounts": "discount_code",
    "corporate_accounts": "corporate_account_id",
    "travel_agents": "travel_agent_id",
    "invoices": "invoice_id",
    "invoice_lines": "invoice_line_id",
    "payment_attempts": "payment_attempt_id",
    "payments": "payment_id",
    "refunds": "refund_id",
    "adjustments": "adjustment_id",
    "credit_notes": "credit_note_id",
    "vouchers": "voucher_id",
}

MANDATORY_FIELDS: dict[str, tuple[str, ...]] = {
    "routes": ("airline_code", "origin_ident", "destination_ident"),
    "flight_instances": ("schedule_id", "origin_ident", "destination_ident", "status"),
    "bookings": ("airline_code", "route_id", "outbound_flight_instance_id", "status", "currency"),
    "tickets": ("booking_id", "passenger_id", "fare_class_code"),
    "ticket_segments": ("ticket_id", "flight_instance_id"),
    "invoices": ("booking_id", "currency", "total_amount", "status"),
    "invoice_lines": ("invoice_id", "line_type", "amount", "currency"),
    "payments": ("invoice_id", "amount", "currency"),
    "refunds": ("invoice_id", "booking_id", "amount", "currency"),
}

# (child_table, child_field, parent_table, parent_field) -- checked only when
# the child field is non-empty, since some FKs are intentionally optional.
FOREIGN_KEYS: list[tuple[str, str, str, str]] = [
    ("routes", "airline_code", "airlines", "airline_code"),
    ("routes", "origin_ident", "airports", "ident"),
    ("routes", "destination_ident", "airports", "ident"),
    ("aircraft", "airline_code", "airlines", "airline_code"),
    ("aircraft", "aircraft_type_code", "aircraft_types", "aircraft_type_code"),
    ("flight_schedules", "route_id", "routes", "route_id"),
    ("flight_schedules", "airline_code", "airlines", "airline_code"),
    ("flight_schedules", "aircraft_type_code", "aircraft_types", "aircraft_type_code"),
    ("flight_instances", "schedule_id", "flight_schedules", "schedule_id"),
    ("flight_instances", "aircraft_registration", "aircraft", "aircraft_registration"),
    ("bookings", "airline_code", "airlines", "airline_code"),
    ("bookings", "route_id", "routes", "route_id"),
    ("bookings", "return_route_id", "routes", "route_id"),
    ("bookings", "corporate_account_id", "corporate_accounts", "corporate_account_id"),
    ("bookings", "travel_agent_id", "travel_agents", "travel_agent_id"),
    ("bookings", "discount_code", "discounts", "discount_code"),
    ("bookings", "outbound_flight_instance_id", "flight_instances", "flight_instance_id"),
    ("bookings", "return_flight_instance_id", "flight_instances", "flight_instance_id"),
    ("booking_passengers", "booking_id", "bookings", "booking_id"),
    ("booking_passengers", "passenger_id", "passengers", "passenger_id"),
    ("tickets", "booking_id", "bookings", "booking_id"),
    ("tickets", "passenger_id", "passengers", "passenger_id"),
    ("tickets", "fare_class_code", "fare_classes", "fare_class_code"),
    ("ticket_segments", "ticket_id", "tickets", "ticket_id"),
    ("ticket_segments", "flight_instance_id", "flight_instances", "flight_instance_id"),
    ("ancillary_services", "ticket_id", "tickets", "ticket_id"),
    ("ancillary_services", "service_code", "services", "service_code"),
    ("airport_fees", "airport_ident", "airports", "ident"),
    ("discounts", "corporate_account_id", "corporate_accounts", "corporate_account_id"),
    ("invoice_lines", "invoice_id", "invoices", "invoice_id"),
    ("invoice_lines", "ticket_id", "tickets", "ticket_id"),
    ("payment_attempts", "invoice_id", "invoices", "invoice_id"),
    ("payments", "payment_attempt_id", "payment_attempts", "payment_attempt_id"),
    ("payments", "invoice_id", "invoices", "invoice_id"),
    ("refunds", "invoice_id", "invoices", "invoice_id"),
    ("refunds", "booking_id", "bookings", "booking_id"),
    ("refunds", "payment_id", "payments", "payment_id"),
    ("adjustments", "invoice_id", "invoices", "invoice_id"),
    ("credit_notes", "invoice_id", "invoices", "invoice_id"),
    ("credit_notes", "refund_id", "refunds", "refund_id"),
    ("vouchers", "passenger_id", "passengers", "passenger_id"),
]

# exception_type -> (table whose PK is the affected_record_key, FK field it deliberately breaks)
REFERENTIAL_EXCEPTION_TYPES: dict[str, tuple[str, str]] = {
    "payment_without_invoice": ("payments", "invoice_id"),
    "invalid_adjustment": ("adjustments", "invoice_id"),
}

EXPECTED_EXCEPTION_TYPES = {
    "duplicate_invoice",
    "failed_payment",
    "unallocated_payment",
    "incorrect_fare",
    "refund_greater_than_collected_amount",
    "cancelled_flight_without_refund",
    "late_arriving_payment",
    "missing_invoice_line",
    "completed_segment_without_recognised_revenue_precursor",
    "payment_without_invoice",
    "ancillary_sold_but_not_fulfilled",
    "ancillary_fulfilled_but_not_billed",
    "currency_mismatch",
    "invalid_adjustment",
}


class Report:
    def __init__(self) -> None:
        self.unexpected: list[str] = []
        self.intentional: list[str] = []
        self.passed: list[str] = []

    def ok(self, message: str) -> None:
        self.passed.append(message)

    def defect(self, message: str) -> None:
        self.unexpected.append(message)

    def expected(self, message: str) -> None:
        self.intentional.append(message)

    def is_clean(self) -> bool:
        return not self.unexpected


def load_all(data_dir: Path) -> dict[str, list[dict]]:
    tables = {name: read_csv(data_dir / path) for name, path in OUTPUT_PATHS.items()}
    tables["exception_manifest"] = read_csv(data_dir / "exception_manifest.csv")
    return tables


def check_files_exist(data_dir: Path, report: Report) -> None:
    for name, path in OUTPUT_PATHS.items():
        full = data_dir / path
        if full.exists():
            report.ok(f"file exists: {path}")
        else:
            report.defect(f"missing required file: {path}")
    manifest_path = data_dir / "exception_manifest.csv"
    if manifest_path.exists():
        report.ok("file exists: exception_manifest.csv")
    else:
        report.defect("missing required file: exception_manifest.csv")


def check_primary_keys(tables: dict[str, list[dict]], report: Report) -> None:
    for table, pk in PRIMARY_KEYS.items():
        seen: dict[str, int] = defaultdict(int)
        missing = 0
        for row in tables[table]:
            value = row.get(pk, "")
            if not value:
                missing += 1
            seen[value] += 1
        duplicates = [k for k, count in seen.items() if count > 1]
        if missing:
            report.defect(f"{table}.{pk} has {missing} null/blank primary key value(s)")
        else:
            report.ok(f"{table}.{pk} has no null primary key values")
        if duplicates:
            report.defect(f"{table}.{pk} has duplicate primary key value(s): {duplicates[:5]}")
        else:
            report.ok(f"{table}.{pk} is unique ({len(tables[table])} rows)")


def check_mandatory_fields(tables: dict[str, list[dict]], report: Report) -> None:
    for table, fields in MANDATORY_FIELDS.items():
        for field in fields:
            missing = sum(1 for row in tables[table] if not row.get(field, ""))
            if missing:
                report.defect(f"{table}.{field} has {missing} null/blank value(s)")
            else:
                report.ok(f"{table}.{field} has no null values")


def check_foreign_keys(tables: dict[str, list[dict]], manifest: list[dict], report: Report) -> None:
    exempt: dict[tuple[str, str], set[str]] = defaultdict(set)
    for row in manifest:
        mapping = REFERENTIAL_EXCEPTION_TYPES.get(row["exception_type"])
        if mapping:
            exempt[mapping].add(row["affected_record_key"])

    for child_table, child_field, parent_table, parent_field in FOREIGN_KEYS:
        parent_pk = PRIMARY_KEYS[parent_table]
        parent_keys = {row[parent_pk] for row in tables[parent_table]}
        child_pk = PRIMARY_KEYS[child_table]
        exempt_keys = exempt.get((child_table, child_field), set())

        broken: list[str] = []
        for row in tables[child_table]:
            value = row.get(child_field, "")
            if not value:
                continue
            if value not in parent_keys:
                own_key = row.get(child_pk, "")
                if own_key in exempt_keys:
                    report.expected(
                        f"{child_table}.{child_field} intentionally broken for "
                        f"{child_table}.{child_pk}={own_key} (value={value})"
                    )
                else:
                    broken.append(own_key or value)

        if broken:
            report.defect(
                f"{child_table}.{child_field} -> {parent_table}.{parent_field} has "
                f"{len(broken)} unexpected unresolved value(s): {broken[:5]}"
            )
        else:
            report.ok(f"{child_table}.{child_field} -> {parent_table}.{parent_field} resolves")


def check_currencies(tables: dict[str, list[dict]], report: Report) -> None:
    supported = {row["currency_code"] for row in tables["currencies"]}
    currency_fields = [
        ("bookings", "currency"),
        ("invoices", "currency"),
        ("invoice_lines", "currency"),
        ("payments", "currency"),
        ("payment_attempts", "currency"),
        ("refunds", "currency"),
        ("adjustments", "currency"),
        ("credit_notes", "currency"),
        ("vouchers", "currency"),
        ("ancillary_services", "currency"),
        ("airport_fees", "currency_code"),
        ("taxes", "currency_code"),
        ("exchange_rates", "currency_code"),
    ]
    unsupported: list[str] = []
    for table, field in currency_fields:
        for row in tables[table]:
            value = row.get(field, "")
            if value and value not in supported:
                unsupported.append(f"{table}.{field}={value}")
    if unsupported:
        report.defect(f"unsupported currency codes found: {unsupported[:10]}")
    else:
        report.ok("all referenced currency codes are present in currencies.csv")


def check_invoice_line_usability(tables: dict[str, list[dict]], report: Report) -> None:
    invoice_ids = {row["invoice_id"] for row in tables["invoices"]}
    ticket_ids = {row["ticket_id"] for row in tables["tickets"]}
    bad = 0
    for line in tables["invoice_lines"]:
        if line["invoice_id"] not in invoice_ids:
            bad += 1
            continue
        if line["ticket_id"] and line["ticket_id"] not in ticket_ids:
            bad += 1
    if bad:
        report.defect(f"invoice_lines has {bad} structurally unusable row(s)")
    else:
        report.ok("invoice_lines relationships to invoices/tickets are structurally usable")


def _payment_by_id(tables: dict[str, list[dict]]) -> dict[str, dict]:
    return {p["payment_id"]: p for p in tables["payments"]}


def _invoice_by_id(tables: dict[str, list[dict]]) -> dict[str, dict]:
    return {i["invoice_id"]: i for i in tables["invoices"]}


def verify_exception_fingerprints(tables: dict[str, list[dict]], manifest: list[dict], report: Report) -> None:
    manifest_types = [row["exception_type"] for row in manifest]
    if len(manifest) != 14:
        report.defect(f"expected exactly 14 manifest rows, found {len(manifest)}")
    missing_types = EXPECTED_EXCEPTION_TYPES - set(manifest_types)
    extra_types = set(manifest_types) - EXPECTED_EXCEPTION_TYPES
    duplicate_types = [t for t in set(manifest_types) if manifest_types.count(t) > 1]
    if missing_types:
        report.defect(f"manifest is missing exception type(s): {sorted(missing_types)}")
    if extra_types:
        report.defect(f"manifest has unrecognised exception type(s): {sorted(extra_types)}")
    if duplicate_types:
        report.defect(f"manifest has repeated exception type(s): {sorted(duplicate_types)}")
    if not (missing_types or extra_types or duplicate_types):
        report.ok("manifest contains exactly the 14 expected exception types, once each")

    invoices_by_id = _invoice_by_id(tables)
    payments_by_id = _payment_by_id(tables)
    lines_by_invoice: dict[str, list[dict]] = defaultdict(list)
    for line in tables["invoice_lines"]:
        lines_by_invoice[line["invoice_id"]].append(line)
    refunds_by_booking: dict[str, list[dict]] = defaultdict(list)
    for r in tables["refunds"]:
        refunds_by_booking[r["booking_id"]].append(r)

    by_type = {row["exception_type"]: row for row in manifest}

    def fingerprint_duplicate_invoice() -> bool:
        row = by_type["duplicate_invoice"]
        original, duplicate = row["affected_record_key"].split("|")
        return (
            original in invoices_by_id
            and duplicate in invoices_by_id
            and invoices_by_id[original]["booking_id"] == invoices_by_id[duplicate]["booking_id"]
        )

    def fingerprint_failed_payment() -> bool:
        invoice_id = by_type["failed_payment"]["affected_record_key"]
        return invoice_id in invoices_by_id and not any(
            p["invoice_id"] == invoice_id for p in tables["payments"]
        )

    def fingerprint_unallocated_payment() -> bool:
        payment_id = by_type["unallocated_payment"]["affected_record_key"]
        payment = payments_by_id.get(payment_id)
        if not payment:
            return False
        invoice = invoices_by_id.get(payment["invoice_id"])
        return bool(invoice) and float(payment["amount"]) > float(invoice["total_amount"])

    def fingerprint_incorrect_fare() -> bool:
        line_id = by_type["incorrect_fare"]["affected_record_key"]
        line = next((line for line in tables["invoice_lines"] if line["invoice_line_id"] == line_id), None)
        return line is not None

    def fingerprint_refund_greater() -> bool:
        refund_id = by_type["refund_greater_than_collected_amount"]["affected_record_key"]
        refund = next((r for r in tables["refunds"] if r["refund_id"] == refund_id), None)
        if not refund:
            return False
        payment = payments_by_id.get(refund["payment_id"])
        if not payment:
            return True
        return float(refund["amount"]) > float(payment["amount"])

    def fingerprint_cancelled_flight() -> bool:
        flight_instance_id = by_type["cancelled_flight_without_refund"]["affected_record_key"]
        flight = next((f for f in tables["flight_instances"] if f["flight_instance_id"] == flight_instance_id), None)
        return bool(flight) and flight["status"] == "cancelled"

    def fingerprint_late_payment() -> bool:
        payment_id = by_type["late_arriving_payment"]["affected_record_key"]
        payment = payments_by_id.get(payment_id)
        if not payment:
            return False
        invoice = invoices_by_id.get(payment["invoice_id"])
        if not invoice:
            return False
        invoice_dt = datetime.fromisoformat(invoice["invoice_date_utc"].replace("Z", ""))
        payment_dt = datetime.fromisoformat(payment["payment_datetime_utc"].replace("Z", ""))
        return (payment_dt - invoice_dt).days >= 30

    def fingerprint_missing_line() -> bool:
        invoice_id = by_type["missing_invoice_line"]["affected_record_key"]
        invoice = invoices_by_id.get(invoice_id)
        if not invoice:
            return False
        line_sum = round(sum(float(line["amount"]) for line in lines_by_invoice.get(invoice_id, [])), 2)
        return abs(line_sum - float(invoice["total_amount"])) > 0.01

    def fingerprint_completed_no_revenue() -> bool:
        segment_id = by_type["completed_segment_without_recognised_revenue_precursor"]["affected_record_key"]
        segment = next((s for s in tables["ticket_segments"] if s["ticket_segment_id"] == segment_id), None)
        if not segment:
            return False
        ticket_id = segment["ticket_id"]
        has_base_fare = any(
            line["ticket_id"] == ticket_id and line["line_type"] == "base_fare" for line in tables["invoice_lines"]
        )
        return segment["segment_status"] == "flown" and not has_base_fare

    def fingerprint_payment_without_invoice() -> bool:
        payment_id = by_type["payment_without_invoice"]["affected_record_key"]
        payment = payments_by_id.get(payment_id)
        return bool(payment) and payment["invoice_id"] not in invoices_by_id

    def fingerprint_ancillary_not_fulfilled() -> bool:
        ancillary_id = by_type["ancillary_sold_but_not_fulfilled"]["affected_record_key"]
        ancillary = next(
            (a for a in tables["ancillary_services"] if a["ancillary_service_id"] == ancillary_id), None
        )
        return bool(ancillary) and ancillary["fulfilment_status"] == "not_fulfilled"

    def fingerprint_ancillary_unbilled() -> bool:
        ancillary_id = by_type["ancillary_fulfilled_but_not_billed"]["affected_record_key"]
        ancillary = next(
            (a for a in tables["ancillary_services"] if a["ancillary_service_id"] == ancillary_id), None
        )
        if not ancillary or ancillary["fulfilment_status"] != "fulfilled":
            return False
        has_line = any(
            line["ticket_id"] == ancillary["ticket_id"]
            and line["line_type"] == "ancillary"
            and line["reference_code"] == ancillary["service_code"]
            for line in tables["invoice_lines"]
        )
        return not has_line

    def fingerprint_currency_mismatch() -> bool:
        payment_id = by_type["currency_mismatch"]["affected_record_key"]
        payment = payments_by_id.get(payment_id)
        if not payment:
            return False
        invoice = invoices_by_id.get(payment["invoice_id"])
        return bool(invoice) and invoice["currency"] != payment["currency"]

    def fingerprint_invalid_adjustment() -> bool:
        adjustment_id = by_type["invalid_adjustment"]["affected_record_key"]
        adjustment = next((a for a in tables["adjustments"] if a["adjustment_id"] == adjustment_id), None)
        return bool(adjustment) and adjustment["invoice_id"] not in invoices_by_id

    fingerprints = {
        "duplicate_invoice": fingerprint_duplicate_invoice,
        "failed_payment": fingerprint_failed_payment,
        "unallocated_payment": fingerprint_unallocated_payment,
        "incorrect_fare": fingerprint_incorrect_fare,
        "refund_greater_than_collected_amount": fingerprint_refund_greater,
        "cancelled_flight_without_refund": fingerprint_cancelled_flight,
        "late_arriving_payment": fingerprint_late_payment,
        "missing_invoice_line": fingerprint_missing_line,
        "completed_segment_without_recognised_revenue_precursor": fingerprint_completed_no_revenue,
        "payment_without_invoice": fingerprint_payment_without_invoice,
        "ancillary_sold_but_not_fulfilled": fingerprint_ancillary_not_fulfilled,
        "ancillary_fulfilled_but_not_billed": fingerprint_ancillary_unbilled,
        "currency_mismatch": fingerprint_currency_mismatch,
        "invalid_adjustment": fingerprint_invalid_adjustment,
    }

    for exception_type, check in fingerprints.items():
        if exception_type not in by_type:
            continue
        try:
            ok = check()
        except Exception as exc:  # defensive: a broken fingerprint check is itself a defect to report
            report.defect(f"fingerprint check for '{exception_type}' raised {exc!r}")
            continue
        if ok:
            report.expected(f"exception fingerprint confirmed: {exception_type}")
        else:
            report.defect(f"exception fingerprint NOT found in data for manifest entry: {exception_type}")


def check_determinism(config_args: list[str], report: Report) -> None:
    with tempfile.TemporaryDirectory() as tmp_a, tempfile.TemporaryDirectory() as tmp_b:
        for tmp_dir in (tmp_a, tmp_b):
            result = subprocess.run(
                [sys.executable, str(REPO_ROOT / "scripts" / "generate_airline_data.py"),
                 "--output-dir", tmp_dir, *config_args],
                cwd=REPO_ROOT,
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                report.defect(f"generator run failed during determinism check: {result.stderr[-500:]}")
                return

        mismatches = []
        for name, path in OUTPUT_PATHS.items():
            file_a = Path(tmp_a) / path
            file_b = Path(tmp_b) / path
            if not filecmp.cmp(file_a, file_b, shallow=False):
                mismatches.append(name)
        manifest_a = Path(tmp_a) / "exception_manifest.csv"
        manifest_b = Path(tmp_b) / "exception_manifest.csv"
        if not filecmp.cmp(manifest_a, manifest_b, shallow=False):
            mismatches.append("exception_manifest")

        if mismatches:
            report.defect(f"generator output is NOT deterministic across repeated runs: {mismatches}")
        else:
            report.ok("generator output is byte-for-byte identical across two independent runs")


def print_report(report: Report) -> None:
    print(f"PASSED checks: {len(report.passed)}")
    print(f"INTENTIONAL (documented exceptions): {len(report.intentional)}")
    for line in report.intentional:
        print(f"  [INTENTIONAL] {line}")
    print(f"UNEXPECTED defects: {len(report.unexpected)}")
    for line in report.unexpected:
        print(f"  [UNEXPECTED]  {line}")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=str, default="data/synthetic")
    parser.add_argument("--skip-determinism-check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    data_dir = Path(args.data_dir)
    if not data_dir.is_absolute():
        data_dir = REPO_ROOT / data_dir

    report = Report()
    check_files_exist(data_dir, report)
    if not report.is_clean():
        print_report(report)
        return 1

    tables = load_all(data_dir)
    manifest = tables["exception_manifest"]

    check_primary_keys(tables, report)
    check_mandatory_fields(tables, report)
    check_foreign_keys(tables, manifest, report)
    check_currencies(tables, report)
    check_invoice_line_usability(tables, report)
    verify_exception_fingerprints(tables, manifest, report)

    if not args.skip_determinism_check:
        check_determinism([], report)

    print_report(report)
    return 0 if report.is_clean() else 1


if __name__ == "__main__":
    raise SystemExit(main())
