select
    route_id,
    airline_code,
    origin_ident,
    destination_ident
from {{ ref('int_route_airport_pair') }}
where origin_ident = destination_ident
