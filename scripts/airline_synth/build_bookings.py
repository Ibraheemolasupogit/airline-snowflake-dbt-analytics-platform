"""Passenger and booking domain, plus ancillary-service sales.

Grain:
    passengers: one row per synthetic passenger.
    bookings: one row per booking reference.
    booking_passengers: one row per booking-passenger association.
    tickets: one row per issued passenger ticket.
    ticket_segments: one row per ticketed passenger flight segment.
    ancillary_services: one row per ancillary service sold against a ticket.
"""

from __future__ import annotations

import random
from datetime import date, datetime, timedelta

from . import reference
from .config import GeneratorConfig
from .utils import date_to_iso, sequential_id, to_utc_iso

BOOKING_REF_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def _booking_reference(booking_seq: int) -> str:
    value = booking_seq * 2654435761 % (32**6)
    chars = []
    for _ in range(6):
        value, remainder = divmod(value, 32)
        chars.append(BOOKING_REF_ALPHABET[remainder])
    return "".join(reversed(chars))


def build_passengers(config: GeneratorConfig, rng: random.Random, as_of_date: date) -> list[dict]:
    rows = []
    for i in range(1, config.num_passengers + 1):
        first = reference.FIRST_NAMES[rng.randrange(len(reference.FIRST_NAMES))]
        last = reference.LAST_NAMES[rng.randrange(len(reference.LAST_NAMES))]
        age_years = rng.randint(18, 75)
        dob = as_of_date - timedelta(days=age_years * 365 + rng.randint(0, 364))
        nationality = reference.NATIONALITIES[rng.randrange(len(reference.NATIONALITIES))]
        loyalty_roll = rng.random()
        if loyalty_roll < 0.55:
            loyalty_tier = "none"
        elif loyalty_roll < 0.80:
            loyalty_tier = "silver"
        elif loyalty_roll < 0.95:
            loyalty_tier = "gold"
        else:
            loyalty_tier = "platinum"

        rows.append(
            {
                "passenger_id": sequential_id("PSG", i),
                "first_name": first,
                "last_name": last,
                "date_of_birth": date_to_iso(dob),
                "nationality": nationality,
                "email": f"{first.lower()}.{last.lower()}.{i:04d}@example-airline-test.invalid",
                "loyalty_tier": loyalty_tier,
            }
        )
    return rows


def _index_flight_instances_by_route(
    routes: list[dict], schedules: list[dict], flight_instances: list[dict]
) -> dict[str, list[dict]]:
    schedule_to_route = {s["schedule_id"]: s["route_id"] for s in schedules}
    by_route: dict[str, list[dict]] = {r["route_id"]: [] for r in routes}
    for instance in flight_instances:
        route_id = schedule_to_route.get(instance["schedule_id"])
        if route_id in by_route:
            by_route[route_id].append(instance)
    return by_route


def build_bookings(
    config: GeneratorConfig,
    rng: random.Random,
    routes: list[dict],
    schedules: list[dict],
    flight_instances: list[dict],
    passengers: list[dict],
    fare_classes: list[dict],
    corporate_accounts: list[dict],
    travel_agents: list[dict],
    discounts: list[dict],
) -> tuple[list[dict], list[dict], list[dict], list[dict]]:
    """Returns (bookings, booking_passengers, tickets, ticket_segments)."""

    instances_by_route = _index_flight_instances_by_route(routes, schedules, flight_instances)
    reverse_route: dict[str, str] = {}
    route_key_to_id = {
        (r["airline_code"], r["origin_ident"], r["destination_ident"]): r["route_id"] for r in routes
    }
    for r in routes:
        key = (r["airline_code"], r["destination_ident"], r["origin_ident"])
        reverse_route[r["route_id"]] = route_key_to_id.get(key, "")

    instances_by_id = {i["flight_instance_id"]: i for i in flight_instances}
    generic_discount_codes = [d["discount_code"] for d in discounts if not d["corporate_account_id"]]
    corporate_discount_by_account = {
        d["corporate_account_id"]: d["discount_code"] for d in discounts if d["corporate_account_id"]
    }

    routable_route_ids = [r["route_id"] for r in routes if instances_by_route.get(r["route_id"])]

    bookings: list[dict] = []
    booking_passengers: list[dict] = []
    tickets: list[dict] = []
    ticket_segments: list[dict] = []

    passenger_type_weights = [0.9, 0.08, 0.02]
    party_size_weights = [0.55, 0.3, 0.15]

    ticket_seq = 1
    segment_seq = 1
    bp_seq = 1

    for booking_seq in range(1, config.num_bookings + 1):
        route_id = routable_route_ids[rng.randrange(len(routable_route_ids))]
        route = next(r for r in routes if r["route_id"] == route_id)
        airline_code = route["airline_code"]
        candidate_instances = instances_by_route[route_id]
        outbound = candidate_instances[rng.randrange(len(candidate_instances))]
        outbound_date = date.fromisoformat(outbound["flight_date"])

        is_round_trip = rng.random() < config.round_trip_rate
        return_instance = None
        return_route_id = reverse_route.get(route_id, "")
        if is_round_trip and return_route_id and instances_by_route.get(return_route_id):
            later_candidates = [
                inst
                for inst in instances_by_route[return_route_id]
                if date.fromisoformat(inst["flight_date"]) > outbound_date
            ]
            if later_candidates:
                return_instance = later_candidates[rng.randrange(len(later_candidates))]
        trip_type = "round_trip" if return_instance else "one_way"

        lead_days = rng.randint(1, 60)
        booking_date = outbound_date - timedelta(days=lead_days)
        booking_datetime_utc = to_utc_iso(
            datetime(booking_date.year, booking_date.month, booking_date.day, 9, 0, 0)
        )

        channel = reference.BOOKING_CHANNELS[rng.randrange(len(reference.BOOKING_CHANNELS))]
        pos_country = reference.NATIONALITIES[rng.randrange(len(reference.NATIONALITIES))]
        currency = reference.COUNTRY_CURRENCY[pos_country]

        corporate_account_id = ""
        travel_agent_id = ""
        discount_code = ""
        if channel == "corporate_portal" or rng.random() < config.corporate_booking_rate:
            account = corporate_accounts[rng.randrange(len(corporate_accounts))]
            corporate_account_id = account["corporate_account_id"]
            discount_code = corporate_discount_by_account.get(corporate_account_id, "")
        elif channel == "travel_agent" or rng.random() < config.travel_agent_booking_rate:
            agent = travel_agents[rng.randrange(len(travel_agents))]
            travel_agent_id = agent["travel_agent_id"]
        elif rng.random() < config.discount_usage_rate and generic_discount_codes:
            discount_code = generic_discount_codes[rng.randrange(len(generic_discount_codes))]

        status = "confirmed"
        if outbound["status"] == "completed" and rng.random() < 0.08:
            status = "cancelled"

        fare_class = fare_classes[rng.randrange(len(fare_classes))]

        booking_id = sequential_id("BKG", booking_seq)
        bookings.append(
            {
                "booking_id": booking_id,
                "booking_reference": _booking_reference(booking_seq),
                "airline_code": airline_code,
                "route_id": route_id,
                "return_route_id": return_route_id if return_instance else "",
                "trip_type": trip_type,
                "booking_channel": channel,
                "booking_date_utc": booking_datetime_utc,
                "point_of_sale_country": pos_country,
                "currency": currency,
                "status": status,
                "corporate_account_id": corporate_account_id,
                "travel_agent_id": travel_agent_id,
                "discount_code": discount_code,
                "outbound_flight_instance_id": outbound["flight_instance_id"],
                "return_flight_instance_id": return_instance["flight_instance_id"] if return_instance else "",
            }
        )

        party_size = rng.choices([1, 2, 3], weights=party_size_weights, k=1)[0]
        chosen_passengers = rng.sample(passengers, k=min(party_size, len(passengers)))

        for order, passenger in enumerate(chosen_passengers, start=1):
            passenger_type = rng.choices(["adult", "child", "infant"], weights=passenger_type_weights, k=1)[0]
            booking_passengers.append(
                {
                    "booking_passenger_id": sequential_id("BKP", bp_seq),
                    "booking_id": booking_id,
                    "passenger_id": passenger["passenger_id"],
                    "passenger_type": passenger_type,
                    "seq_in_booking": order,
                }
            )
            bp_seq += 1

            ticket_id = sequential_id("TKT", ticket_seq)
            ticket_status = "cancelled" if status == "cancelled" else "issued"
            tickets.append(
                {
                    "ticket_id": ticket_id,
                    "ticket_number": f"{700_000_000_000 + ticket_seq:013d}",
                    "booking_id": booking_id,
                    "passenger_id": passenger["passenger_id"],
                    "fare_class_code": fare_class["fare_class_code"],
                    "issue_date_utc": booking_datetime_utc,
                    "ticket_status": ticket_status,
                }
            )
            ticket_seq += 1

            for leg_seq, instance in enumerate(
                [outbound] + ([return_instance] if return_instance else []), start=1
            ):
                flight_status = instances_by_id[instance["flight_instance_id"]]["status"]
                if status == "cancelled":
                    segment_status = "cancelled"
                elif flight_status == "completed":
                    segment_status = "flown"
                elif flight_status == "cancelled":
                    segment_status = "cancelled"
                else:
                    segment_status = "confirmed"

                ticket_segments.append(
                    {
                        "ticket_segment_id": sequential_id("SEG", segment_seq),
                        "ticket_id": ticket_id,
                        "segment_sequence": leg_seq,
                        "flight_instance_id": instance["flight_instance_id"],
                        "cabin": fare_class["cabin"],
                        "fare_basis_code": fare_class["fare_basis_code"],
                        "segment_status": segment_status,
                    }
                )
                segment_seq += 1

    return bookings, booking_passengers, tickets, ticket_segments


def build_ancillary_services(
    config: GeneratorConfig,
    rng: random.Random,
    tickets: list[dict],
    ticket_segments: list[dict],
    bookings_by_id: dict[str, dict],
) -> list[dict]:
    rows = []
    seq = 1
    segments_by_ticket: dict[str, list[dict]] = {}
    for seg in ticket_segments:
        segments_by_ticket.setdefault(seg["ticket_id"], []).append(seg)

    for ticket in tickets:
        if ticket["ticket_status"] != "issued":
            continue
        if rng.random() >= config.ancillary_purchase_rate:
            continue

        booking = bookings_by_id[ticket["booking_id"]]
        currency = booking["currency"]
        rate = reference.EXCHANGE_RATE_TO_USD[currency]
        num_services = 1 if rng.random() < 0.7 else 2
        service_picks = rng.sample(reference.SERVICES, k=min(num_services, len(reference.SERVICES)))

        segments = segments_by_ticket.get(ticket["ticket_id"], [])
        any_flown = any(s["segment_status"] == "flown" for s in segments)
        any_future = any(s["segment_status"] == "confirmed" for s in segments)

        for service_code, _name, _category, base_price_usd in service_picks:
            if any_flown and not any_future:
                fulfilment_status = "fulfilled"
            elif any_future:
                fulfilment_status = "pending"
            else:
                fulfilment_status = "not_fulfilled"

            rows.append(
                {
                    "ancillary_service_id": sequential_id("ANC", seq),
                    "ticket_id": ticket["ticket_id"],
                    "service_code": service_code,
                    "quantity": 1,
                    "unit_price": round(base_price_usd / rate, 2),
                    "currency": currency,
                    "fulfilment_status": fulfilment_status,
                    "purchase_date_utc": ticket["issue_date_utc"],
                }
            )
            seq += 1
    return rows
