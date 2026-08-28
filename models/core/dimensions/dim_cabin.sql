-- Grain is one row per cabin category. Derived from the distinct cabin codes staged in
-- stg_airline__fare_classes (the authoritative fare-class-to-cabin catalogue;
-- stg_airline__ticket_segments.cabin mirrors these same codes by generator construction -- see
-- scripts/airline_synth/build_bookings.py). No human-readable cabin name (e.g. "Economy") is
-- added: that mapping exists only inside the Milestone 9 generator's internal Python reference
-- data (CABIN_NAMES in scripts/airline_synth/reference.py), not in any staged column, so adding
-- it here would invent a field with no source-data authority.
with distinct_cabins as (

    select distinct cabin
    from {{ ref('stg_airline__fare_classes') }}
    where cabin is not null

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['cabin']) }} as cabin_key,
        cabin
    from distinct_cabins

)

select
    cabin_key,
    cabin
from final
