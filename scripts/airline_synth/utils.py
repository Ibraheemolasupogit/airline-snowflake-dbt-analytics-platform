"""Shared deterministic helpers: id formatting, geometry, CSV I/O, timestamps.

All timestamps produced by this package are UTC and rendered as ISO-8601 with
a trailing ``Z`` (for example ``2026-01-05T14:30:00Z``). There is no reliance
on wall-clock time anywhere in generation; every date is computed relative to
``airline_synth.config.AS_OF_DATE``.
"""

from __future__ import annotations

import csv
import math
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Iterable, Mapping, Sequence

EARTH_RADIUS_KM = 6371.0


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in kilometres between two lat/lon points."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def sequential_id(prefix: str, sequence: int, width: int = 5) -> str:
    """Zero-padded, prefixed, stable identifier, e.g. ``BKG-00042``."""
    return f"{prefix}-{sequence:0{width}d}"


def to_utc_iso(dt: datetime) -> str:
    """Render a naive UTC datetime as an ISO-8601 string with a 'Z' suffix."""
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def date_to_iso(d: date) -> str:
    return d.strftime("%Y-%m-%d")


def local_time_to_utc(on_date: date, local_hour: int, local_minute: int, utc_offset_hours: float) -> datetime:
    """Convert a local wall-clock time at a given UTC offset to a UTC datetime."""
    naive_local = datetime(on_date.year, on_date.month, on_date.day, local_hour, local_minute)
    return naive_local - timedelta(hours=utc_offset_hours)


def round2(value: float) -> float:
    return round(value + 1e-9, 2)


def convert_usd(amount_usd: float, currency_code: str, rate_to_usd: Mapping[str, float]) -> float:
    """Convert a USD amount into another currency using a rate-to-USD table."""
    return round2(amount_usd / rate_to_usd[currency_code])


def write_csv(path: Path, fieldnames: Sequence[str], rows: Iterable[Mapping[str, object]]) -> int:
    """Write rows to a CSV file with a fixed column order and LF line endings.

    Returns the number of data rows written. Creates parent directories as
    needed. Row order is preserved exactly as provided by the caller, which
    keeps output deterministic across repeated runs.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
            count += 1
    return count


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))
