select
    ident,
    runway_count,
    open_runway_count,
    closed_runway_count,
    lighted_runway_count
from {{ ref('int_airport_runway_profile') }}
where
    open_runway_count + closed_runway_count > runway_count
    or lighted_runway_count > runway_count
