-- Grain is one row per (country, tax type) -- currently one row per country, since
-- scripts/airline_synth/reference.py's COUNTRY_TAX_TYPES has exactly one entry (a flat 7%
-- "Government Passenger Tax"), replicated per country by build_pricing.py::build_taxes. Natural
-- key is tax_id. percentage_rate is a fraction applied against a ticket's pre-tax fare (base +
-- distance), not a flat amount -- see int_tax_calculation for the applicability rule (booking's
-- outbound-route origin/departure country).
with taxes as (

    select
        tax_id,
        country_code,
        tax_code,
        tax_name,
        percentage_rate,
        currency_code
    from {{ ref('stg_airline__taxes') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['tax_id']) }} as tax_key,
        tax_id,
        country_code,
        tax_code,
        tax_name,
        percentage_rate,
        currency_code
    from taxes

)

select
    tax_key,
    tax_id,
    country_code,
    tax_code,
    tax_name,
    percentage_rate,
    currency_code
from final
