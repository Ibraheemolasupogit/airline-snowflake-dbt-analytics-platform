"""Generation configuration and the fixed synthetic timeline anchor.

Everything in this dataset is dated relative to ``AS_OF_DATE`` rather than the
real wall-clock date. That is deliberate: it keeps the generator byte-for-byte
deterministic no matter when it is actually executed, at the cost of the
dataset's "today" slowly drifting into the past relative to the real world.
This is documented as a known simplification.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date

DEFAULT_SEED = 20240115

# Fixed synthetic "as of" anchor date. Flight activity is generated in a
# window around this date, not around the real current date.
AS_OF_DATE = date(2026, 1, 15)

# How many days of flight activity to generate before/after the anchor date.
FLIGHT_HISTORY_DAYS = 21
FLIGHT_FUTURE_DAYS = 7

BASE_CURRENCY = "USD"


@dataclass(frozen=True)
class GeneratorConfig:
    """Row-count and behaviour knobs for one generation run."""

    seed: int = DEFAULT_SEED
    output_dir: str = "data/synthetic"

    num_passengers: int = 150
    num_bookings: int = 180
    spokes_per_airline: int = 4
    aircraft_per_airline: int = 4

    flight_history_days: int = FLIGHT_HISTORY_DAYS
    flight_future_days: int = FLIGHT_FUTURE_DAYS

    ancillary_purchase_rate: float = 0.4
    round_trip_rate: float = 0.5
    corporate_booking_rate: float = 0.15
    travel_agent_booking_rate: float = 0.2
    discount_usage_rate: float = 0.15
