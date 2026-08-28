select
    geography.ident,
    geography.region_code,
    geography.region_source_id,
    geography.country_code,
    geography.country_source_id
from {{ ref('int_airport_geography') }} as geography
where
    (
        geography.region_code is not null
        and geography.region_source_id is null
    )
    or (
        geography.country_code is not null
        and geography.country_source_id is null
    )
