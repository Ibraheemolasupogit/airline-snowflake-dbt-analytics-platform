"""Deterministic controlled-exception injection.

This module mutates an already-generated, otherwise-clean in-memory dataset
to plant a fixed, documented catalogue of data-quality and financial-control
exceptions. Every exception is chosen by deterministic index/lookup (never by
fresh randomness), so the same seed always plants the same exceptions on the
same records. Each injected exception produces one manifest row describing
what was done, why, and which later dbt rule is expected to catch it.

Nothing here "fixes" anything -- these functions exist purely to create
controlled defects for Milestone 10+ assurance models to detect. The
validator (``scripts/validate_source_data.py``) reads the manifest so it can
tell an intentional exception apart from an unexpected integrity defect.
"""

from __future__ import annotations

from datetime import datetime, timedelta

from .utils import sequential_id, to_utc_iso

MANIFEST_FIELDS = (
    "exception_id",
    "exception_type",
    "affected_entity",
    "affected_record_key",
    "expected_detection_rule",
    "rationale",
)


def _manifest_row(seq: int, exception_type: str, entity: str, key: str, rule: str, rationale: str) -> dict:
    return {
        "exception_id": sequential_id("EXC", seq, width=3),
        "exception_type": exception_type,
        "affected_entity": entity,
        "affected_record_key": key,
        "expected_detection_rule": rule,
        "rationale": rationale,
    }


def inject_exceptions(tables: dict[str, list[dict]]) -> list[dict]:
    manifest: list[dict] = []
    seq = 1

    invoices = tables["invoices"]
    invoice_lines = tables["invoice_lines"]
    payments = tables["payments"]
    payment_attempts = tables["payment_attempts"]
    refunds = tables["refunds"]
    adjustments = tables["adjustments"]
    ancillary_services = tables["ancillary_services"]
    flight_instances = tables["flight_instances"]
    ticket_segments = tables["ticket_segments"]

    invoices_by_id = {inv["invoice_id"]: inv for inv in invoices}
    lines_by_invoice: dict[str, list[dict]] = {}
    for line in invoice_lines:
        lines_by_invoice.setdefault(line["invoice_id"], []).append(line)

    used_invoice_ids: set[str] = set()
    used_line_ids: set[str] = set()
    used_ancillary_ids: set[str] = set()
    used_payment_ids: set[str] = set()

    # 1. duplicate invoice: clone an existing invoice + its lines under a new id.
    source_invoice = invoices[4]
    duplicate_id = f"{source_invoice['invoice_id']}-DUP"
    duplicate_invoice = dict(source_invoice)
    duplicate_invoice["invoice_id"] = duplicate_id
    invoices.append(duplicate_invoice)
    for line in lines_by_invoice.get(source_invoice["invoice_id"], []):
        new_line = dict(line)
        new_line["invoice_line_id"] = f"{line['invoice_line_id']}-DUP"
        new_line["invoice_id"] = duplicate_id
        invoice_lines.append(new_line)
    used_invoice_ids.add(source_invoice["invoice_id"])
    manifest.append(
        _manifest_row(
            seq,
            "duplicate_invoice",
            "invoices",
            f"{source_invoice['invoice_id']}|{duplicate_id}",
            "invoice count per booking_id should be exactly one",
            "Cloned an existing invoice and its lines under a new invoice_id for the same booking "
            "to simulate an accidental double-bill.",
        )
    )
    seq += 1

    # 2. failed payment: an invoice whose only payment attempt(s) all failed.
    paid_invoice_ids = {p["invoice_id"] for p in payments}
    failed_only_invoice = next(
        inv
        for inv in invoices
        if inv["invoice_id"] not in paid_invoice_ids
        and inv["invoice_id"] not in used_invoice_ids
        and inv["status"] == "issued"
        and inv["total_amount"] > 0
    )
    used_invoice_ids.add(failed_only_invoice["invoice_id"])
    manifest.append(
        _manifest_row(
            seq,
            "failed_payment",
            "invoices",
            failed_only_invoice["invoice_id"],
            "issued invoice with total_amount > 0 and no successful payment should surface as outstanding",
            "Every payment attempt against this invoice failed; no successful payment exists.",
        )
    )
    seq += 1

    # 3. unallocated payment: a successful payment that overpays its invoice.
    overpay_payment = next(p for p in payments if p["invoice_id"] not in used_invoice_ids)
    overpay_payment["amount"] = round(overpay_payment["amount"] + 50.0, 2)
    overpay_payment["allocation_status"] = "overpaid_unallocated"
    used_invoice_ids.add(overpay_payment["invoice_id"])
    used_payment_ids.add(overpay_payment["payment_id"])
    manifest.append(
        _manifest_row(
            seq,
            "unallocated_payment",
            "payments",
            overpay_payment["payment_id"],
            "payment.amount should not exceed its invoice.total_amount",
            "Payment amount was increased above the invoice total, leaving an unallocated excess.",
        )
    )
    seq += 1

    # 4. incorrect fare: a base_fare line set to a value inconsistent with its fare class.
    incorrect_fare_line = next(
        line
        for line in invoice_lines
        if line["line_type"] == "base_fare" and line["invoice_id"] not in used_invoice_ids
    )
    original_amount = incorrect_fare_line["amount"]
    incorrect_fare_line["amount"] = round(original_amount * 3.0 + 17.0, 2)
    used_invoice_ids.add(incorrect_fare_line["invoice_id"])
    used_line_ids.add(incorrect_fare_line["invoice_line_id"])
    manifest.append(
        _manifest_row(
            seq,
            "incorrect_fare",
            "invoice_lines",
            incorrect_fare_line["invoice_line_id"],
            "base_fare line amount should equal fare_class base_fare_usd + per_km_usd * route distance",
            f"Base fare amount overwritten to {incorrect_fare_line['amount']} instead of the "
            f"fare-class-derived {original_amount}.",
        )
    )
    seq += 1

    # 5. refund greater than collected amount.
    refund_candidates = [r for r in refunds if r["invoice_id"] not in used_invoice_ids]
    if refund_candidates:
        target_refund = refund_candidates[0]
    else:
        fallback_payment = next(p for p in payments if p["invoice_id"] not in used_invoice_ids)
        target_refund = {
            "refund_id": sequential_id("REF", 900),
            "invoice_id": fallback_payment["invoice_id"],
            "booking_id": invoices_by_id[fallback_payment["invoice_id"]]["booking_id"],
            "payment_id": fallback_payment["payment_id"],
            "refund_datetime_utc": fallback_payment["payment_datetime_utc"],
            "reason": "goodwill",
            "amount": fallback_payment["amount"],
            "currency": fallback_payment["currency"],
            "method": "original_payment",
            "status": "issued",
        }
        refunds.append(target_refund)
    linked_payment = next((p for p in payments if p["payment_id"] == target_refund["payment_id"]), None)
    collected_amount = linked_payment["amount"] if linked_payment else target_refund["amount"]
    target_refund["amount"] = round(collected_amount + 100.0, 2)
    used_invoice_ids.add(target_refund["invoice_id"])
    manifest.append(
        _manifest_row(
            seq,
            "refund_greater_than_collected_amount",
            "refunds",
            target_refund["refund_id"],
            "refund.amount should not exceed the amount collected on the linked payment",
            "Refund amount was raised above the amount actually collected on the linked payment.",
        )
    )
    seq += 1

    # 6. cancelled flight without refund: flip a completed flight to cancelled post-hoc.
    cancel_target = next(f for f in flight_instances if f["status"] == "completed")
    cancel_target["status"] = "cancelled"
    affected_segments = [s for s in ticket_segments if s["flight_instance_id"] == cancel_target["flight_instance_id"]]
    for segment in affected_segments:
        segment["segment_status"] = "cancelled"
    manifest.append(
        _manifest_row(
            seq,
            "cancelled_flight_without_refund",
            "flight_instances",
            cancel_target["flight_instance_id"],
            "tickets on a cancelled flight_instance should have an associated refund or voucher",
            "Flight instance marked cancelled after ticketing; the associated booking/invoice/payment "
            "were deliberately left untouched, so no refund exists for the affected passengers.",
        )
    )
    seq += 1

    # 7. late-arriving payment: shift a successful payment far after its invoice date.
    late_payment = next(
        p
        for p in payments
        if p["payment_id"] not in used_payment_ids and p["invoice_id"] not in used_invoice_ids
    )
    invoice_date = datetime.fromisoformat(invoices_by_id[late_payment["invoice_id"]]["invoice_date_utc"].replace("Z", ""))
    late_payment["payment_datetime_utc"] = to_utc_iso(invoice_date + timedelta(days=75))
    used_invoice_ids.add(late_payment["invoice_id"])
    used_payment_ids.add(late_payment["payment_id"])
    manifest.append(
        _manifest_row(
            seq,
            "late_arriving_payment",
            "payments",
            late_payment["payment_id"],
            "payment_datetime_utc should normally fall within a few days of invoice_date_utc",
            "Payment timestamp shifted to 75 days after the invoice date to simulate a late-arriving payment.",
        )
    )
    seq += 1

    # 8. missing invoice line: remove an invoice's tax line without adjusting the header.
    missing_line_invoice = next(
        inv
        for inv in invoices
        if inv["invoice_id"] not in used_invoice_ids
        and any(line["line_type"] == "tax" for line in lines_by_invoice.get(inv["invoice_id"], []))
    )
    tax_line = next(
        line for line in lines_by_invoice[missing_line_invoice["invoice_id"]] if line["line_type"] == "tax"
    )
    invoice_lines.remove(tax_line)
    used_invoice_ids.add(missing_line_invoice["invoice_id"])
    used_line_ids.add(tax_line["invoice_line_id"])
    manifest.append(
        _manifest_row(
            seq,
            "missing_invoice_line",
            "invoices",
            missing_line_invoice["invoice_id"],
            "sum(invoice_lines.amount) for an invoice should reconcile to invoice.total_amount",
            f"Removed tax line {tax_line['invoice_line_id']} without adjusting the invoice header, "
            "so the header no longer reconciles to its lines.",
        )
    )
    seq += 1

    # 9. completed segment without a recognised-revenue precursor: remove a flown ticket's base fare line.
    flown_segment = next(
        s
        for s in ticket_segments
        if s["segment_status"] == "flown"
        and not any(
            line["ticket_id"] == s["ticket_id"] and line["invoice_line_id"] in used_line_ids
            for line in invoice_lines
        )
    )
    base_fare_line = next(
        line
        for line in invoice_lines
        if line["ticket_id"] == flown_segment["ticket_id"] and line["line_type"] == "base_fare"
    )
    invoice_lines.remove(base_fare_line)
    used_line_ids.add(base_fare_line["invoice_line_id"])
    manifest.append(
        _manifest_row(
            seq,
            "completed_segment_without_recognised_revenue_precursor",
            "ticket_segments",
            flown_segment["ticket_segment_id"],
            "a flown ticket_segment's ticket should have a base_fare invoice_line to recognise as revenue",
            f"Removed base_fare line {base_fare_line['invoice_line_id']} for a ticket with a flown segment.",
        )
    )
    seq += 1

    # 10. payment without invoice: an orphaned payment referencing a non-existent invoice.
    orphan_payment_id = sequential_id("PMT", 9001)
    payments.append(
        {
            "payment_id": orphan_payment_id,
            "payment_attempt_id": "",
            "invoice_id": "INV-99999",
            "payment_datetime_utc": to_utc_iso(datetime(2026, 1, 2, 10, 0, 0)),
            "method": "bank_transfer",
            "amount": 320.0,
            "currency": "USD",
            "allocation_status": "unallocated",
        }
    )
    manifest.append(
        _manifest_row(
            seq,
            "payment_without_invoice",
            "payments",
            orphan_payment_id,
            "payments.invoice_id should resolve to an existing invoices.invoice_id",
            "Appended a payment referencing invoice_id 'INV-99999', which does not exist in invoices.csv.",
        )
    )
    seq += 1

    # 11. ancillary sold but not fulfilled: force a flown ticket's ancillary to not_fulfilled.
    ancillary_not_fulfilled = next(
        a for a in ancillary_services if a["ancillary_service_id"] not in used_ancillary_ids
    )
    ancillary_not_fulfilled["fulfilment_status"] = "not_fulfilled"
    used_ancillary_ids.add(ancillary_not_fulfilled["ancillary_service_id"])
    manifest.append(
        _manifest_row(
            seq,
            "ancillary_sold_but_not_fulfilled",
            "ancillary_services",
            ancillary_not_fulfilled["ancillary_service_id"],
            "an ancillary sold against a flown ticket should ordinarily be fulfilled",
            "Forced fulfilment_status to 'not_fulfilled' for an ancillary sold on an otherwise-flown ticket.",
        )
    )
    seq += 1

    # 12. ancillary fulfilled but not billed: fulfilled ancillary with its invoice line removed.
    ancillary_fulfilled = next(
        a
        for a in ancillary_services
        if a["ancillary_service_id"] not in used_ancillary_ids and a["fulfilment_status"] == "fulfilled"
    )
    ancillary_line = next(
        (
            line
            for line in invoice_lines
            if line["ticket_id"] == ancillary_fulfilled["ticket_id"]
            and line["line_type"] == "ancillary"
            and line["reference_code"] == ancillary_fulfilled["service_code"]
        ),
        None,
    )
    if ancillary_line is not None:
        invoice_lines.remove(ancillary_line)
    used_ancillary_ids.add(ancillary_fulfilled["ancillary_service_id"])
    manifest.append(
        _manifest_row(
            seq,
            "ancillary_fulfilled_but_not_billed",
            "ancillary_services",
            ancillary_fulfilled["ancillary_service_id"],
            "a fulfilled ancillary_service should have a matching invoice_line of line_type='ancillary'",
            "Removed the invoice_line for an ancillary_service already marked fulfilled.",
        )
    )
    seq += 1

    # 13. currency mismatch: payment currency differs from its invoice currency.
    mismatch_payment = next(
        p
        for p in payments
        if p["payment_id"] not in used_payment_ids
        and p["invoice_id"] in invoices_by_id
        and p["invoice_id"] not in used_invoice_ids
    )
    invoice_currency = invoices_by_id[mismatch_payment["invoice_id"]]["currency"]
    mismatch_payment["currency"] = "USD" if invoice_currency != "USD" else "GBP"
    used_invoice_ids.add(mismatch_payment["invoice_id"])
    used_payment_ids.add(mismatch_payment["payment_id"])
    manifest.append(
        _manifest_row(
            seq,
            "currency_mismatch",
            "payments",
            mismatch_payment["payment_id"],
            "payment.currency should equal the currency of its invoice",
            f"Payment currency set to {mismatch_payment['currency']} while its invoice remains "
            f"{invoice_currency}, with no recorded conversion.",
        )
    )
    seq += 1

    # 14. invalid adjustment: adjustment referencing a non-existent invoice with an implausible amount.
    invalid_adjustment_id = sequential_id("ADJ", 9001)
    adjustments.append(
        {
            "adjustment_id": invalid_adjustment_id,
            "invoice_id": "INV-99998",
            "adjustment_type": "credit",
            "amount": 999999.0,
            "currency": "USD",
            "reason": "data_entry_error",
            "created_at_utc": to_utc_iso(datetime(2026, 1, 3, 8, 0, 0)),
        }
    )
    manifest.append(
        _manifest_row(
            seq,
            "invalid_adjustment",
            "adjustments",
            invalid_adjustment_id,
            "adjustments.invoice_id should resolve to an existing invoice and amount should be plausible",
            "Appended an adjustment referencing a non-existent invoice_id with an implausibly large amount.",
        )
    )
    seq += 1

    return manifest
