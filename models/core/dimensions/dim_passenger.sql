-- Grain is one row per synthetic passenger. Every attribute here is synthetic Milestone 9
-- generator output (see docs/data_models/airline_synthetic_source_data.md's Privacy Statement)
-- -- no real individuals are represented. Future recruiter-facing marts should avoid exposing
-- name/email/date_of_birth directly; this core dimension retains them because core models
-- preserve full source lineage per docs/architecture/development_standards.md.
with passengers as (

    select
        passenger_id,
        first_name,
        last_name,
        date_of_birth,
        nationality,
        email,
        loyalty_tier
    from {{ ref('stg_airline__passengers') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['passenger_id']) }} as passenger_key,
        passenger_id,
        first_name,
        last_name,
        date_of_birth,
        nationality,
        email,
        loyalty_tier
    from passengers

)

select
    passenger_key,
    passenger_id,
    first_name,
    last_name,
    date_of_birth,
    nationality,
    email,
    loyalty_tier
from final
