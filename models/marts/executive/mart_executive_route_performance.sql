-- Grain is one row per (route, currency). A deliberately narrow executive consumption contract:
-- selects the top-line commercial columns from mart_route_commercial_performance directly, rather
-- than re-joining core tables. No route profitability is exposed here for the same reason it is
-- not exposed anywhere in this milestone: no cost data exists in this repository.
select
    route_id,
    origin_ident,
    destination_ident,
    currency,
    total_recognised_revenue,
    flight_count,
    total_passengers_carried,
    load_factor,
    revenue_per_passenger,
    revenue_per_flight
from {{ ref('mart_route_commercial_performance') }}
