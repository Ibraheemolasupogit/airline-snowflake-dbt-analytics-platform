"""Reference and operations domain: airlines, aircraft, routes, flights.

Grain:
    airlines: one row per airline.
    aircraft_types: one row per aircraft type.
    aircraft: one row per aircraft (tail).
    routes: one row per directional airport pair / airline route.
    flight_schedules: one row per scheduled flight service.
    flight_instances: one row per dated flight occurrence.
"""

from __future__ import annotations

import random
from datetime import timedelta

from . import reference
from .config import GeneratorConfig
from .utils import haversine_km, local_time_to_utc, sequential_id, to_utc_iso

WEEKDAY_CODES = ("MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN")

AIRPORT_BY_IDENT = {row[0]: row for row in reference.AIRPORT_FIXTURE}


def build_airlines() -> list[dict]:
    return [
        {
            "airline_code": code,
            "airline_name": name,
            "home_country": country,
            "hub_ident": hub,
        }
        for code, name, country, hub in reference.AIRLINES
    ]


def build_aircraft_types() -> list[dict]:
    return [
        {
            "aircraft_type_code": code,
            "type_name": name,
            "body_type": body,
            "typical_seats": seats,
            "cabins": "|".join(cabins),
            "cruise_speed_kmh": speed,
        }
        for code, name, body, seats, cabins, speed in reference.AIRCRAFT_TYPES
    ]


def _pick_aircraft_type_code(distance_km: float, airline_index: int) -> str:
    if distance_km > 6000:
        return "B77W" if airline_index % 2 == 0 else "A359"
    if distance_km > 3000:
        return "A321" if airline_index % 2 == 0 else "B738"
    return "A320" if airline_index % 2 == 0 else "E190"


def build_aircraft(config: GeneratorConfig) -> list[dict]:
    rows: list[dict] = []
    seq = 1
    for airline_code, _name, home_country, _hub in reference.AIRLINES:
        for i in range(config.aircraft_per_airline):
            type_code = reference.AIRCRAFT_TYPES[(seq + i) % len(reference.AIRCRAFT_TYPES)][0]
            rows.append(
                {
                    "aircraft_registration": f"{home_country}-{airline_code}{i + 1:03d}",
                    "airline_code": airline_code,
                    "aircraft_type_code": type_code,
                    "manufactured_year": 2012 + ((seq + i) % 12),
                }
            )
            seq += 1
    return rows


def build_routes(config: GeneratorConfig, rng: random.Random) -> list[dict]:
    rows: list[dict] = []
    seq = 1
    other_idents = [ident for ident, *_ in reference.AIRPORT_FIXTURE]
    for airline_code, _name, _country, hub in reference.AIRLINES:
        candidates = [ident for ident in other_idents if ident != hub]
        shuffled = candidates[:]
        rng.shuffle(shuffled)
        spokes = shuffled[: config.spokes_per_airline]
        for spoke in spokes:
            hub_row = AIRPORT_BY_IDENT[hub]
            spoke_row = AIRPORT_BY_IDENT[spoke]
            distance_km = round(haversine_km(hub_row[8], hub_row[9], spoke_row[8], spoke_row[9]), 1)
            for origin, destination in ((hub, spoke), (spoke, hub)):
                rows.append(
                    {
                        "route_id": sequential_id("RTE", seq),
                        "airline_code": airline_code,
                        "origin_ident": origin,
                        "destination_ident": destination,
                        "distance_km": distance_km,
                    }
                )
                seq += 1
    return rows


def build_flight_schedules(routes: list[dict]) -> list[dict]:
    rows: list[dict] = []
    airline_flight_seq: dict[str, int] = {}
    airline_index = {code: i for i, (code, *_rest) in enumerate(reference.AIRLINES)}
    for i, route in enumerate(routes):
        airline_code = route["airline_code"]
        airline_flight_seq[airline_code] = airline_flight_seq.get(airline_code, 100) + 1
        flight_number = f"{airline_code}{airline_flight_seq[airline_code]}"

        aircraft_type_code = _pick_aircraft_type_code(route["distance_km"], airline_index[airline_code])
        cruise_speed = next(t[5] for t in reference.AIRCRAFT_TYPES if t[0] == aircraft_type_code)
        duration_minutes = round((route["distance_km"] / cruise_speed) * 60 + 45)

        pattern_group = i % 3
        if pattern_group == 0:
            days = ("MON", "WED", "FRI")
        elif pattern_group == 1:
            days = ("TUE", "THU", "SAT")
        else:
            days = WEEKDAY_CODES

        departure_hour = 6 + ((i * 3) % 15)
        departure_minute = 0 if i % 2 == 0 else 30

        rows.append(
            {
                "schedule_id": sequential_id("SCH", i + 1),
                "route_id": route["route_id"],
                "airline_code": airline_code,
                "flight_number": flight_number,
                "origin_ident": route["origin_ident"],
                "destination_ident": route["destination_ident"],
                "aircraft_type_code": aircraft_type_code,
                "scheduled_departure_local_time": f"{departure_hour:02d}:{departure_minute:02d}",
                "scheduled_duration_minutes": duration_minutes,
                "operating_days_of_week": "|".join(days),
            }
        )
    return rows


def build_flight_instances(
    config: GeneratorConfig,
    schedules: list[dict],
    aircraft: list[dict],
    as_of_date,
) -> list[dict]:
    rows: list[dict] = []
    fleet_by_airline: dict[str, list[dict]] = {}
    for tail in aircraft:
        fleet_by_airline.setdefault(tail["airline_code"], []).append(tail)

    rotation_counter: dict[str, int] = {}
    seq = 1
    start_date = as_of_date - timedelta(days=config.flight_history_days)
    end_date = as_of_date + timedelta(days=config.flight_future_days)

    for schedule in schedules:
        operating_days = set(schedule["operating_days_of_week"].split("|"))
        origin = AIRPORT_BY_IDENT[schedule["origin_ident"]]
        origin_offset = origin[10]
        hour, minute = (int(part) for part in schedule["scheduled_departure_local_time"].split(":"))

        fleet = [
            t for t in fleet_by_airline.get(schedule["airline_code"], [])
            if t["aircraft_type_code"] == schedule["aircraft_type_code"]
        ] or fleet_by_airline.get(schedule["airline_code"], [])

        current = start_date
        while current <= end_date:
            weekday_code = WEEKDAY_CODES[current.weekday()]
            if weekday_code in operating_days:
                departure_utc = local_time_to_utc(current, hour, minute, origin_offset)
                arrival_utc = departure_utc + timedelta(minutes=schedule["scheduled_duration_minutes"])

                key = schedule["schedule_id"]
                rotation_counter[key] = rotation_counter.get(key, -1) + 1
                aircraft_registration = (
                    fleet[rotation_counter[key] % len(fleet)]["aircraft_registration"] if fleet else ""
                )

                status = "completed" if current < as_of_date else "scheduled"

                rows.append(
                    {
                        "flight_instance_id": sequential_id("FLT", seq),
                        "schedule_id": schedule["schedule_id"],
                        "flight_number": schedule["flight_number"],
                        "flight_date": current.isoformat(),
                        "origin_ident": schedule["origin_ident"],
                        "destination_ident": schedule["destination_ident"],
                        "aircraft_registration": aircraft_registration,
                        "scheduled_departure_utc": to_utc_iso(departure_utc),
                        "scheduled_arrival_utc": to_utc_iso(arrival_utc),
                        "status": status,
                    }
                )
                seq += 1
            current += timedelta(days=1)
    return rows
