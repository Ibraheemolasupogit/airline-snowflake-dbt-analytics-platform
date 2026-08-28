-- Grain is one row per (service_code, currency). Reuses int_ancillary_revenue_recognition
-- (Milestone 17) directly -- fulfilment and recognition logic is not recomputed. Preserves the
-- sold-vs-fulfilled distinction that model was built to make visible: sold_count counts every
-- ancillary sale regardless of fulfilment; fulfilled_count/unfulfilled_count partition that same
-- population by fulfilment_indicator; recognised_ancillary_revenue only ever reflects the
-- fulfilled subset (recognised_amount is already 0 for unfulfilled rows upstream).
with ancillary_revenue as (

    select
        service_code,
        currency,
        is_sold,
        fulfilment_indicator,
        recognised_amount
    from {{ ref('int_ancillary_revenue_recognition') }}

),

aggregated as (

    select
        service_code,
        currency,
        sum(case when is_sold then 1 else 0 end) as sold_count,
        sum(case when fulfilment_indicator then 1 else 0 end) as fulfilled_count,
        sum(case when not fulfilment_indicator then 1 else 0 end) as unfulfilled_count,
        sum(recognised_amount) as recognised_ancillary_revenue
    from ancillary_revenue
    group by service_code, currency

)

select
    service_code,
    currency,
    sold_count,
    fulfilled_count,
    unfulfilled_count,
    cast(recognised_ancillary_revenue as decimal(18, 2)) as recognised_ancillary_revenue
from aggregated
