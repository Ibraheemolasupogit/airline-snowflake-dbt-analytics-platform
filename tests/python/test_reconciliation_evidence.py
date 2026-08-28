"""Tests for scripts/generate_reconciliation_evidence.py.

These exercise the pure control-computation functions directly against the real, already-generated
data/synthetic/ fixtures (read-only) and only write to tmp_path for the seed/fixture-writing
functions, so running these tests never overwrites the repo's own seeds/outputs/ files.
"""

from __future__ import annotations

import csv
import json
from pathlib import Path

import pytest

import generate_reconciliation_evidence as reconciliation_evidence

REPO_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = REPO_ROOT / "data" / "synthetic"
CONTROL_TOTALS_PATH = DATA_DIR / "control_totals.json"


@pytest.fixture(scope="module")
def control_totals() -> dict:
    with CONTROL_TOTALS_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _rows_by_control_id(rows: list[dict]) -> dict[str, dict]:
    return {row["control_id"]: row for row in rows}


def test_generate_seed_round_trips_control_totals(control_totals, tmp_path):
    seed_path = tmp_path / "seed_synthetic_control_totals.csv"
    row_count = reconciliation_evidence.generate_seed(control_totals, seed_path)

    assert row_count == len(control_totals["control_totals"])

    with seed_path.open("r", newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    seeded = {row["metric_name"]: row["metric_value"] for row in rows}
    for metric_name, expected_value in control_totals["control_totals"].items():
        assert seeded[metric_name] == str(expected_value)
        assert rows[0]["as_of_date"] == control_totals["as_of_date"]


def test_booking_control_totals_all_pass(control_totals):
    rows = reconciliation_evidence.generate_booking_control_totals(control_totals, DATA_DIR)
    by_id = _rows_by_control_id(rows)

    for control_id in (
        "booking.booking_count",
        "booking.booking_confirmed_count",
        "booking.booking_cancelled_count",
        "ticket.ticket_count",
        "flight_operations.flight_instance_count",
        "flight_operations.flight_instance_completed_count",
        "flight_operations.flight_instance_cancelled_count",
        "flight_operations.flight_instance_scheduled_count",
    ):
        assert by_id[control_id]["control_status"] == "pass", control_id
        assert by_id[control_id]["variance_count"] == 0, control_id


def test_invoice_control_totals_pass_with_known_informational_warning(control_totals):
    rows = reconciliation_evidence.generate_invoice_control_totals(control_totals, DATA_DIR)
    by_id = _rows_by_control_id(rows)

    assert by_id["invoice.invoice_count"]["control_status"] == "pass"
    assert by_id["invoice.invoice_total_value"]["control_status"] == "pass"

    # Informational-only: known controlled exceptions (missing_invoice_line, incorrect_fare,
    # completed_segment_without_recognised_revenue_precursor) make this genuinely nonzero -- it
    # must never be reported as a hard reconciliation failure.
    consistency = by_id["invoice.invoice_line_arithmetic_consistency"]
    assert consistency["control_status"] in {"pass", "warning"}


def test_payment_control_totals_pass_and_failed_attempts_are_supplementary(control_totals):
    rows = reconciliation_evidence.generate_payment_control_totals(control_totals, DATA_DIR)
    by_id = _rows_by_control_id(rows)

    assert by_id["payment.successful_payment_count"]["control_status"] == "pass"
    assert by_id["payment.successful_payment_total_value"]["control_status"] == "pass"
    assert by_id["payment.failed_attempt_count"]["control_status"] == "not_applicable"
    assert by_id["payment.failed_attempt_count"]["source_measure"] == ""


def test_refund_control_totals_reconcile_despite_the_controlled_anomaly(control_totals):
    rows = reconciliation_evidence.generate_refund_control_totals(control_totals, DATA_DIR)
    by_id = _rows_by_control_id(rows)

    # This is the core Milestone 19 assertion: the refund_greater_than_collected_amount
    # controlled exception's inflated amount is preserved unmodified in refunds.csv, and
    # source-to-warehouse reconciliation still shows an exact match -- a business anomaly is not
    # the same thing as a reconciliation failure.
    assert by_id["refund.refund_count"]["control_status"] == "pass"
    assert by_id["refund.refund_total_value"]["control_status"] == "pass"
    assert by_id["refund.refund_total_value"]["variance_amount"] == 0.0


def test_schema_only_fixtures_contain_no_fabricated_data_rows(tmp_path):
    reconciliation_evidence.generate_schema_only_fixtures(tmp_path)

    for filename in ("revenue_reconciliation.csv", "billing_exceptions.csv"):
        lines = (tmp_path / filename).read_text(encoding="utf-8").splitlines()
        assert lines[0].startswith("#"), "first line must document this is a schema-only fixture"
        assert len(lines) == 2, "must contain only a comment line and a header row, no data"
