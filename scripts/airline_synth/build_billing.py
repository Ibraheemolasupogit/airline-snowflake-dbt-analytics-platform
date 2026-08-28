"""Billing and payments domain.

Grain:
    corporate_accounts: one row per corporate account.
    travel_agents: one row per travel agent.
    invoices: one row per invoice.
    invoice_lines: one row per invoice charge component.
    payment_attempts: one row per payment attempt.
    payments: one row per successful payment transaction.
    refunds: one row per refund transaction.
    adjustments: one row per manual invoice adjustment.
    credit_notes: one row per credit note.
    vouchers: one row per issued travel voucher.
"""

from __future__ import annotations

import random
from datetime import datetime, timedelta

from . import reference
from .utils import convert_usd, date_to_iso, sequential_id, to_utc_iso

FAILURE_REASONS = ("card_declined", "insufficient_funds", "bank_rejected")


def build_corporate_accounts() -> list[dict]:
    return [
        {
            "corporate_account_id": sequential_id("CORP", i, width=3),
            "company_name": name,
            "country": country,
            "negotiated_discount_pct": pct,
            "default_currency": reference.COUNTRY_CURRENCY[country],
        }
        for i, (name, country, pct) in enumerate(reference.CORPORATE_ACCOUNTS, start=1)
    ]


def build_travel_agents() -> list[dict]:
    return [
        {
            "travel_agent_id": sequential_id("TA", i, width=3),
            "agency_name": name,
            "iata_number": f"90-{100000 + i * 137}",
            "country": country,
            "commission_pct": pct,
        }
        for i, (name, country, pct) in enumerate(reference.TRAVEL_AGENTS, start=1)
    ]


def _fare_amount_usd(fare_class: dict, distance_km: float) -> float:
    return fare_class["base_fare_usd"] + fare_class["per_km_usd"] * distance_km


def build_billing_documents(
    rng: random.Random,
    bookings: list[dict],
    tickets: list[dict],
    ticket_segments: list[dict],
    ancillary_services: list[dict],
    fare_classes: list[dict],
    routes_by_id: dict[str, dict],
    discounts_by_code: dict[str, dict],
) -> dict[str, list[dict]]:
    fare_by_code = {f["fare_class_code"]: f for f in fare_classes}
    tickets_by_booking: dict[str, list[dict]] = {}
    for t in tickets:
        tickets_by_booking.setdefault(t["booking_id"], []).append(t)

    ancillary_by_ticket: dict[str, list[dict]] = {}
    for a in ancillary_services:
        ancillary_by_ticket.setdefault(a["ticket_id"], []).append(a)

    invoices: list[dict] = []
    invoice_lines: list[dict] = []
    payment_attempts: list[dict] = []
    payments: list[dict] = []
    refunds: list[dict] = []
    adjustments: list[dict] = []
    credit_notes: list[dict] = []
    vouchers: list[dict] = []

    invoice_seq = 1
    line_seq = 1
    attempt_seq = 1
    payment_seq = 1
    refund_seq = 1
    adjustment_seq = 1
    credit_note_seq = 1
    voucher_seq = 1

    for booking in bookings:
        booking_tickets = tickets_by_booking.get(booking["booking_id"], [])
        if not booking_tickets:
            continue
        currency = booking["currency"]
        route = routes_by_id[booking["route_id"]]

        invoice_id = sequential_id("INV", invoice_seq)
        invoice_seq += 1
        invoice_date_utc = booking["booking_date_utc"]

        bill_to_type = "passenger"
        bill_to_id = booking_tickets[0]["passenger_id"]
        if booking["corporate_account_id"]:
            bill_to_type = "corporate"
            bill_to_id = booking["corporate_account_id"]
        elif booking["travel_agent_id"]:
            bill_to_type = "travel_agent"
            bill_to_id = booking["travel_agent_id"]

        subtotal = 0.0
        tax_total = 0.0
        fee_total = 0.0
        ancillary_total = 0.0

        for ticket in booking_tickets:
            fare_class = fare_by_code[ticket["fare_class_code"]]
            fare_usd = _fare_amount_usd(fare_class, route["distance_km"])
            fare_local = convert_usd(fare_usd, currency, reference.EXCHANGE_RATE_TO_USD)
            invoice_lines.append(
                {
                    "invoice_line_id": sequential_id("INL", line_seq),
                    "invoice_id": invoice_id,
                    "ticket_id": ticket["ticket_id"],
                    "line_type": "base_fare",
                    "reference_code": fare_class["fare_class_code"],
                    "description": f"Base fare: {fare_class['description']}",
                    "amount": fare_local,
                    "currency": currency,
                }
            )
            line_seq += 1
            subtotal += fare_local

            tax_usd = fare_usd * reference.COUNTRY_TAX_TYPES[0][2]
            tax_local = convert_usd(tax_usd, currency, reference.EXCHANGE_RATE_TO_USD)
            invoice_lines.append(
                {
                    "invoice_line_id": sequential_id("INL", line_seq),
                    "invoice_id": invoice_id,
                    "ticket_id": ticket["ticket_id"],
                    "line_type": "tax",
                    "reference_code": reference.COUNTRY_TAX_TYPES[0][0],
                    "description": reference.COUNTRY_TAX_TYPES[0][1],
                    "amount": tax_local,
                    "currency": currency,
                }
            )
            line_seq += 1
            tax_total += tax_local

            for fee_code, fee_name, fee_usd in reference.AIRPORT_FEE_TYPES:
                fee_local = convert_usd(fee_usd, currency, reference.EXCHANGE_RATE_TO_USD)
                invoice_lines.append(
                    {
                        "invoice_line_id": sequential_id("INL", line_seq),
                        "invoice_id": invoice_id,
                        "ticket_id": ticket["ticket_id"],
                        "line_type": "airport_fee",
                        "reference_code": fee_code,
                        "description": fee_name,
                        "amount": fee_local,
                        "currency": currency,
                    }
                )
                line_seq += 1
                fee_total += fee_local

            for ancillary in ancillary_by_ticket.get(ticket["ticket_id"], []):
                amount = ancillary["unit_price"] * ancillary["quantity"]
                invoice_lines.append(
                    {
                        "invoice_line_id": sequential_id("INL", line_seq),
                        "invoice_id": invoice_id,
                        "ticket_id": ticket["ticket_id"],
                        "line_type": "ancillary",
                        "reference_code": ancillary["service_code"],
                        "description": f"Ancillary service: {ancillary['service_code']}",
                        "amount": amount,
                        "currency": currency,
                    }
                )
                line_seq += 1
                ancillary_total += amount

        discount_amount = 0.0
        if booking["discount_code"]:
            discount = discounts_by_code[booking["discount_code"]]
            if discount["discount_type"] == "percentage":
                discount_amount = round(subtotal * float(discount["value"]), 2)
            else:
                discount_amount = convert_usd(float(discount["value"]), currency, reference.EXCHANGE_RATE_TO_USD)
            discount_amount = min(discount_amount, subtotal)
            invoice_lines.append(
                {
                    "invoice_line_id": sequential_id("INL", line_seq),
                    "invoice_id": invoice_id,
                    "ticket_id": "",
                    "line_type": "discount",
                    "reference_code": booking["discount_code"],
                    "description": f"Discount: {discount['discount_name']}",
                    "amount": -discount_amount,
                    "currency": currency,
                }
            )
            line_seq += 1

        total_amount = round(subtotal + tax_total + fee_total + ancillary_total - discount_amount, 2)

        invoice_row = {
            "invoice_id": invoice_id,
            "booking_id": booking["booking_id"],
            "invoice_date_utc": invoice_date_utc,
            "currency": currency,
            "bill_to_type": bill_to_type,
            "bill_to_id": bill_to_id,
            "subtotal_amount": round(subtotal, 2),
            "tax_amount": round(tax_total, 2),
            "fee_amount": round(fee_total, 2),
            "ancillary_amount": round(ancillary_total, 2),
            "discount_amount": round(discount_amount, 2),
            "total_amount": total_amount,
            "status": "issued",
        }
        invoices.append(invoice_row)

        if total_amount <= 0:
            invoice_row["status"] = "paid"
            continue

        # A booking that is later cancelled may already have been paid for --
        # cancellation is a passenger-lifecycle event independent of whether
        # the payment attempt itself succeeds, so payment generation runs the
        # same way regardless of booking status.
        outcome_roll = rng.random()
        attempt_dt = datetime.fromisoformat(invoice_date_utc.replace("Z", "")) + timedelta(hours=2)

        successful_payment_amount = None
        if outcome_roll < 0.82:
            payment_attempts.append(
                {
                    "payment_attempt_id": sequential_id("PAT", attempt_seq),
                    "invoice_id": invoice_id,
                    "attempt_datetime_utc": to_utc_iso(attempt_dt),
                    "method": reference.PAYMENT_METHODS[0],
                    "amount": total_amount,
                    "currency": currency,
                    "result": "success",
                    "failure_reason": "",
                }
            )
            attempt_id = sequential_id("PAT", attempt_seq)
            attempt_seq += 1
            payments.append(
                {
                    "payment_id": sequential_id("PMT", payment_seq),
                    "payment_attempt_id": attempt_id,
                    "invoice_id": invoice_id,
                    "payment_datetime_utc": to_utc_iso(attempt_dt),
                    "method": reference.PAYMENT_METHODS[0],
                    "amount": total_amount,
                    "currency": currency,
                    "allocation_status": "fully_allocated",
                }
            )
            successful_payment_amount = total_amount
            payment_seq += 1
        elif outcome_roll < 0.94:
            failure_reason = FAILURE_REASONS[rng.randrange(len(FAILURE_REASONS))]
            payment_attempts.append(
                {
                    "payment_attempt_id": sequential_id("PAT", attempt_seq),
                    "invoice_id": invoice_id,
                    "attempt_datetime_utc": to_utc_iso(attempt_dt),
                    "method": reference.PAYMENT_METHODS[0],
                    "amount": total_amount,
                    "currency": currency,
                    "result": "failed",
                    "failure_reason": failure_reason,
                }
            )
            attempt_seq += 1
            retry_dt = attempt_dt + timedelta(hours=6)
            payment_attempts.append(
                {
                    "payment_attempt_id": sequential_id("PAT", attempt_seq),
                    "invoice_id": invoice_id,
                    "attempt_datetime_utc": to_utc_iso(retry_dt),
                    "method": reference.PAYMENT_METHODS[1],
                    "amount": total_amount,
                    "currency": currency,
                    "result": "success",
                    "failure_reason": "",
                }
            )
            attempt_id = sequential_id("PAT", attempt_seq)
            attempt_seq += 1
            payments.append(
                {
                    "payment_id": sequential_id("PMT", payment_seq),
                    "payment_attempt_id": attempt_id,
                    "invoice_id": invoice_id,
                    "payment_datetime_utc": to_utc_iso(retry_dt),
                    "method": reference.PAYMENT_METHODS[1],
                    "amount": total_amount,
                    "currency": currency,
                    "allocation_status": "fully_allocated",
                }
            )
            successful_payment_amount = total_amount
            payment_seq += 1
        else:
            failure_reason = FAILURE_REASONS[rng.randrange(len(FAILURE_REASONS))]
            payment_attempts.append(
                {
                    "payment_attempt_id": sequential_id("PAT", attempt_seq),
                    "invoice_id": invoice_id,
                    "attempt_datetime_utc": to_utc_iso(attempt_dt),
                    "method": reference.PAYMENT_METHODS[0],
                    "amount": total_amount,
                    "currency": currency,
                    "result": "failed",
                    "failure_reason": failure_reason,
                }
            )
            attempt_seq += 1

        if booking["status"] == "cancelled" and successful_payment_amount is not None:
            refund_id = sequential_id("REF", refund_seq)
            refund_seq += 1
            refund_dt = attempt_dt + timedelta(days=2)
            refunds.append(
                {
                    "refund_id": refund_id,
                    "invoice_id": invoice_id,
                    "booking_id": booking["booking_id"],
                    "payment_id": sequential_id("PMT", payment_seq - 1),
                    "refund_datetime_utc": to_utc_iso(refund_dt),
                    "reason": "cancellation",
                    "amount": successful_payment_amount,
                    "currency": currency,
                    "method": "original_payment",
                    "status": "issued",
                }
            )
            credit_notes.append(
                {
                    "credit_note_id": sequential_id("CRN", credit_note_seq),
                    "invoice_id": invoice_id,
                    "refund_id": refund_id,
                    "adjustment_id": "",
                    "amount": successful_payment_amount,
                    "currency": currency,
                    "issued_at_utc": to_utc_iso(refund_dt),
                    "status": "issued",
                }
            )
            credit_note_seq += 1
            invoice_row["status"] = "refunded"
        elif booking["status"] == "cancelled":
            invoice_row["status"] = "cancelled"
        elif successful_payment_amount is not None:
            invoice_row["status"] = "paid"
        else:
            invoice_row["status"] = "issued"

        if invoice_seq % 23 == 0:
            adjustment_amount = round(total_amount * 0.03, 2)
            adjustments.append(
                {
                    "adjustment_id": sequential_id("ADJ", adjustment_seq),
                    "invoice_id": invoice_id,
                    "adjustment_type": "credit",
                    "amount": -adjustment_amount,
                    "currency": currency,
                    "reason": "goodwill_rate_correction",
                    "created_at_utc": to_utc_iso(attempt_dt + timedelta(days=1)),
                }
            )
            adjustment_seq += 1

        if invoice_seq % 31 == 0:
            voucher_amount = round(total_amount * 0.1, 2)
            vouchers.append(
                {
                    "voucher_id": sequential_id("VCH", voucher_seq),
                    "passenger_id": bill_to_id if bill_to_type == "passenger" else booking_tickets[0]["passenger_id"],
                    "issued_from": "goodwill",
                    "amount": voucher_amount,
                    "currency": currency,
                    "issued_at_utc": to_utc_iso(attempt_dt + timedelta(days=1)),
                    "expiry_date": date_to_iso((attempt_dt + timedelta(days=365)).date()),
                    "status": "active",
                    "redeemed_booking_id": "",
                }
            )
            voucher_seq += 1

    return {
        "invoices": invoices,
        "invoice_lines": invoice_lines,
        "payment_attempts": payment_attempts,
        "payments": payments,
        "refunds": refunds,
        "adjustments": adjustments,
        "credit_notes": credit_notes,
        "vouchers": vouchers,
    }
