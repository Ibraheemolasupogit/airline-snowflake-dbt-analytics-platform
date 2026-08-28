-- Grain is one row per currency code. Natural key is currency_code. Combines
-- stg_airline__currencies (name, minor_unit_digits) with stg_airline__exchange_rates
-- (rate_to_usd, as_of_date) -- a 1:1 join, both keyed by currency_code, so no fan-out risk.
-- rate_to_usd is a single current rate, not a time series: the Milestone 9 source
-- (scripts/airline_synth/build_pricing.py::build_exchange_rates) generates exactly one
-- deterministic rate per currency as of a fixed AS_OF_DATE, so this dimension is deliberately not
-- modelled as a rate-history/SCD -- doing so would invent history the source does not provide.
-- minor_unit_digits is preserved for reference only: verified against
-- scripts/airline_synth/utils.py::round2, the generator itself always rounds monetary amounts to
-- a flat 2 decimal places regardless of currency (including JPY, whose real-world minor unit is
-- 0), so this pricing layer matches that same fixed 2-decimal-place convention throughout for
-- consistency and reconcilability, rather than applying minor_unit_digits dynamically.
with currencies as (

    select
        currency_code,
        currency_name,
        minor_unit_digits
    from {{ ref('stg_airline__currencies') }}

),

exchange_rates as (

    select
        currency_code,
        rate_to_usd,
        as_of_date
    from {{ ref('stg_airline__exchange_rates') }}

),

joined as (

    select
        currencies.currency_code,
        currencies.currency_name,
        currencies.minor_unit_digits,
        exchange_rates.rate_to_usd,
        exchange_rates.as_of_date as rate_as_of_date
    from currencies
    left join exchange_rates
        on currencies.currency_code = exchange_rates.currency_code

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['currency_code']) }} as currency_key,
        currency_code,
        currency_name,
        minor_unit_digits,
        rate_to_usd,
        rate_as_of_date
    from joined

)

select
    currency_key,
    currency_code,
    currency_name,
    minor_unit_digits,
    rate_to_usd,
    rate_as_of_date
from final
