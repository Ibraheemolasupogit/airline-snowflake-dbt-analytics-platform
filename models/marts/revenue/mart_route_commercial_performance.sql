-- Grain is one row per (route, currency), identical to mart_revenue_by_route -- reused directly,
-- not re-joined, to avoid duplicating the same route/revenue/operations logic twice. This is the
-- explicit, documented substitute for a "route profitability" mart: the repository contains no
-- route or flight cost data (no fuel, crew, maintenance, or airport-charge cost basis anywhere in
-- the Milestone 9 specification), so profitability (revenue minus cost) cannot be defensibly
-- computed. Revenue-per-unit commercial metrics are exposed instead; no cost is fabricated.
select
    route_key,
    route_id,
    origin_ident,
    origin_airport_name,
    destination_ident,
    destination_airport_name,
    distance_km,
    currency,
    total_recognised_revenue,
    flight_count,
    total_passengers_carried,
    load_factor,
    revenue_per_passenger,
    revenue_per_flight
from {{ ref('mart_revenue_by_route') }}
