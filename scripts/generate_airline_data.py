#!/usr/bin/env python3
"""Generate the deterministic synthetic airline source dataset.

Usage:
    python scripts/generate_airline_data.py [--seed N] [--output-dir DIR]
        [--bookings N] [--passengers N]

Writes CSV files under ``data/synthetic/`` (reference, operations, bookings,
pricing, billing) plus ``exception_manifest.csv``. Uses only the Python
standard library. Running this script twice with the same arguments produces
byte-identical output -- see ``docs/data_models/airline_synthetic_source_data.md``
for the full design, and ``scripts/validate_source_data.py`` to check the
result without dbt or Snowflake.

This script does not connect to Snowflake and does not implement any dbt
staging, intermediate, core, or mart modelling. It only produces synthetic
source CSVs for later milestones.
"""

from __future__ import annotations

import argparse
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from airline_synth import build_billing, build_bookings, build_operations, build_pricing, exceptions, reference
from airline_synth.config import AS_OF_DATE, GeneratorConfig
from airline_synth.utils import write_csv

REPO_ROOT = Path(__file__).resolve().parents[1]

FIELDNAMES: dict[str, tuple[str, ...]] = {
    "airports": (
        "ident", "icao_code", "iata_code", "airport_name", "municipality",
        "iso_country", "iso_region", "continent_code", "latitude_deg",
        "longitude_deg", "utc_offset_hours",
    ),
    "currencies": ("currency_code", "currency_name", "minor_unit_digits"),
    "exchange_rates": ("currency_code", "rate_to_usd", "as_of_date"),
    "airlines": ("airline_code", "airline_name", "home_country", "hub_ident"),
    "aircraft_types": (
        "aircraft_type_code", "type_name", "body_type", "typical_seats", "cabins", "cruise_speed_kmh",
    ),
    "aircraft": ("aircraft_registration", "airline_code", "aircraft_type_code", "manufactured_year"),
    "routes": ("route_id", "airline_code", "origin_ident", "destination_ident", "distance_km"),
    "flight_schedules": (
        "schedule_id", "route_id", "airline_code", "flight_number", "origin_ident",
        "destination_ident", "aircraft_type_code", "scheduled_departure_local_time",
        "scheduled_duration_minutes", "operating_days_of_week",
    ),
    "flight_instances": (
        "flight_instance_id", "schedule_id", "flight_number", "flight_date", "origin_ident",
        "destination_ident", "aircraft_registration", "scheduled_departure_utc",
        "scheduled_arrival_utc", "status",
    ),
    "passengers": (
        "passenger_id", "first_name", "last_name", "date_of_birth", "nationality", "email", "loyalty_tier",
    ),
    "bookings": (
        "booking_id", "booking_reference", "airline_code", "route_id", "return_route_id", "trip_type",
        "booking_channel", "booking_date_utc", "point_of_sale_country", "currency", "status",
        "corporate_account_id", "travel_agent_id", "discount_code", "outbound_flight_instance_id",
        "return_flight_instance_id",
    ),
    "booking_passengers": (
        "booking_passenger_id", "booking_id", "passenger_id", "passenger_type", "seq_in_booking",
    ),
    "tickets": (
        "ticket_id", "ticket_number", "booking_id", "passenger_id", "fare_class_code",
        "issue_date_utc", "ticket_status",
    ),
    "ticket_segments": (
        "ticket_segment_id", "ticket_id", "segment_sequence", "flight_instance_id", "cabin",
        "fare_basis_code", "segment_status",
    ),
    "products": ("product_code", "product_name", "fare_class_code", "included_service_codes"),
    "services": ("service_code", "service_name", "category", "base_price_usd"),
    "ancillary_services": (
        "ancillary_service_id", "ticket_id", "service_code", "quantity", "unit_price", "currency",
        "fulfilment_status", "purchase_date_utc",
    ),
    "fare_classes": (
        "fare_class_code", "cabin", "fare_basis_code", "refundable", "change_fee_usd",
        "base_fare_usd", "per_km_usd", "description",
    ),
    "fare_rules": (
        "fare_rule_id", "fare_class_code", "refundable", "change_fee_usd",
        "advance_purchase_days", "min_stay_nights",
    ),
    "airport_fees": ("airport_fee_id", "airport_ident", "fee_code", "fee_name", "currency_code", "amount"),
    "taxes": ("tax_id", "country_code", "tax_code", "tax_name", "percentage_rate", "currency_code"),
    "discounts": ("discount_code", "discount_name", "discount_type", "value", "corporate_account_id"),
    "corporate_accounts": (
        "corporate_account_id", "company_name", "country", "negotiated_discount_pct", "default_currency",
    ),
    "travel_agents": ("travel_agent_id", "agency_name", "iata_number", "country", "commission_pct"),
    "invoices": (
        "invoice_id", "booking_id", "invoice_date_utc", "currency", "bill_to_type", "bill_to_id",
        "subtotal_amount", "tax_amount", "fee_amount", "ancillary_amount", "discount_amount",
        "total_amount", "status",
    ),
    "invoice_lines": (
        "invoice_line_id", "invoice_id", "ticket_id", "line_type", "reference_code",
        "description", "amount", "currency",
    ),
    "payment_attempts": (
        "payment_attempt_id", "invoice_id", "attempt_datetime_utc", "method", "amount",
        "currency", "result", "failure_reason",
    ),
    "payments": (
        "payment_id", "payment_attempt_id", "invoice_id", "payment_datetime_utc", "method",
        "amount", "currency", "allocation_status",
    ),
    "refunds": (
        "refund_id", "invoice_id", "booking_id", "payment_id", "refund_datetime_utc", "reason",
        "amount", "currency", "method", "status",
    ),
    "adjustments": (
        "adjustment_id", "invoice_id", "adjustment_type", "amount", "currency", "reason", "created_at_utc",
    ),
    "credit_notes": (
        "credit_note_id", "invoice_id", "refund_id", "adjustment_id", "amount", "currency",
        "issued_at_utc", "status",
    ),
    "vouchers": (
        "voucher_id", "passenger_id", "issued_from", "amount", "currency", "issued_at_utc",
        "expiry_date", "status", "redeemed_booking_id",
    ),
}

OUTPUT_PATHS: dict[str, str] = {
    "airports": "reference/airports.csv",
    "currencies": "reference/currencies.csv",
    "exchange_rates": "reference/exchange_rates.csv",
    "airlines": "reference/airlines.csv",
    "aircraft_types": "reference/aircraft_types.csv",
    "aircraft": "operations/aircraft.csv",
    "routes": "operations/routes.csv",
    "flight_schedules": "operations/flight_schedules.csv",
    "flight_instances": "operations/flight_instances.csv",
    "passengers": "bookings/passengers.csv",
    "bookings": "bookings/bookings.csv",
    "booking_passengers": "bookings/booking_passengers.csv",
    "tickets": "bookings/tickets.csv",
    "ticket_segments": "bookings/ticket_segments.csv",
    "products": "pricing/products.csv",
    "services": "pricing/services.csv",
    "ancillary_services": "pricing/ancillary_services.csv",
    "fare_classes": "pricing/fare_classes.csv",
    "fare_rules": "pricing/fare_rules.csv",
    "airport_fees": "pricing/airport_fees.csv",
    "taxes": "pricing/taxes.csv",
    "discounts": "pricing/discounts.csv",
    "corporate_accounts": "billing/corporate_accounts.csv",
    "travel_agents": "billing/travel_agents.csv",
    "invoices": "billing/invoices.csv",
    "invoice_lines": "billing/invoice_lines.csv",
    "payment_attempts": "billing/payment_attempts.csv",
    "payments": "billing/payments.csv",
    "refunds": "billing/refunds.csv",
    "adjustments": "billing/adjustments.csv",
    "credit_notes": "billing/credit_notes.csv",
    "vouchers": "billing/vouchers.csv",
}


def build_airports_rows() -> list[dict]:
    return [dict(zip(FIELDNAMES["airports"], row)) for row in reference.AIRPORT_FIXTURE]


def generate(config: GeneratorConfig) -> dict[str, list[dict]]:
    rng = random.Random(config.seed)

    airlines = build_operations.build_airlines()
    aircraft_types = build_operations.build_aircraft_types()
    aircraft = build_operations.build_aircraft(config)
    routes = build_operations.build_routes(config, rng)
    flight_schedules = build_operations.build_flight_schedules(routes)
    flight_instances = build_operations.build_flight_instances(config, flight_schedules, aircraft, AS_OF_DATE)

    currencies = build_pricing.build_currencies()
    exchange_rates = build_pricing.build_exchange_rates()
    fare_classes = build_pricing.build_fare_classes()
    fare_rules = build_pricing.build_fare_rules()
    products = build_pricing.build_products()
    services = build_pricing.build_services()
    airport_fees = build_pricing.build_airport_fees()
    taxes = build_pricing.build_taxes()

    corporate_accounts = build_billing.build_corporate_accounts()
    travel_agents = build_billing.build_travel_agents()
    discounts = build_pricing.build_discounts(corporate_accounts)

    passengers = build_bookings.build_passengers(config, rng, AS_OF_DATE)
    bookings, booking_passengers, tickets, ticket_segments = build_bookings.build_bookings(
        config, rng, routes, flight_schedules, flight_instances, passengers,
        fare_classes, corporate_accounts, travel_agents, discounts,
    )

    bookings_by_id = {b["booking_id"]: b for b in bookings}
    ancillary_services = build_bookings.build_ancillary_services(
        config, rng, tickets, ticket_segments, bookings_by_id
    )

    routes_by_id = {r["route_id"]: r for r in routes}
    discounts_by_code = {d["discount_code"]: d for d in discounts}
    billing_docs = build_billing.build_billing_documents(
        rng, bookings, tickets, ticket_segments, ancillary_services, fare_classes,
        routes_by_id, discounts_by_code,
    )

    tables: dict[str, list[dict]] = {
        "airports": build_airports_rows(),
        "currencies": currencies,
        "exchange_rates": exchange_rates,
        "airlines": airlines,
        "aircraft_types": aircraft_types,
        "aircraft": aircraft,
        "routes": routes,
        "flight_schedules": flight_schedules,
        "flight_instances": flight_instances,
        "passengers": passengers,
        "bookings": bookings,
        "booking_passengers": booking_passengers,
        "tickets": tickets,
        "ticket_segments": ticket_segments,
        "products": products,
        "services": services,
        "ancillary_services": ancillary_services,
        "fare_classes": fare_classes,
        "fare_rules": fare_rules,
        "airport_fees": airport_fees,
        "taxes": taxes,
        "discounts": discounts,
        "corporate_accounts": corporate_accounts,
        "travel_agents": travel_agents,
        **billing_docs,
    }

    manifest = exceptions.inject_exceptions(tables)
    tables["exception_manifest"] = manifest
    return tables


def write_tables(tables: dict[str, list[dict]], output_dir: Path) -> dict[str, int]:
    counts: dict[str, int] = {}
    for name, path_suffix in OUTPUT_PATHS.items():
        counts[name] = write_csv(output_dir / path_suffix, FIELDNAMES[name], tables[name])
    counts["exception_manifest"] = write_csv(
        output_dir / "exception_manifest.csv", exceptions.MANIFEST_FIELDS, tables["exception_manifest"]
    )
    return counts


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=GeneratorConfig().seed)
    parser.add_argument("--output-dir", type=str, default=GeneratorConfig().output_dir)
    parser.add_argument("--bookings", type=int, default=GeneratorConfig().num_bookings)
    parser.add_argument("--passengers", type=int, default=GeneratorConfig().num_passengers)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    config = GeneratorConfig(
        seed=args.seed,
        output_dir=args.output_dir,
        num_bookings=args.bookings,
        num_passengers=args.passengers,
    )
    output_dir = Path(config.output_dir)
    if not output_dir.is_absolute():
        output_dir = REPO_ROOT / output_dir

    tables = generate(config)
    counts = write_tables(tables, output_dir)

    print(f"Generated synthetic airline data under {output_dir} (seed={config.seed})")
    for name in sorted(counts):
        print(f"  {name}: {counts[name]} rows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
