-- Grain is one row per currency. Reuses mart_daily_passenger_revenue (already-aggregated,
-- already currency-safe) rather than re-aggregating fct_revenue. Never collapses across currency
-- -- a single "total revenue" row across currencies would not be a meaningful figure.
with daily_revenue as (

    select
        currency,
        recognised_ticket_revenue,
        recognised_ancillary_revenue,
        reversal_or_adjustment_total,
        net_recognised_revenue,
        passenger_count
    from {{ ref('mart_daily_passenger_revenue') }}

),

aggregated as (

    select
        currency,
        sum(recognised_ticket_revenue) as recognised_ticket_revenue,
        sum(recognised_ancillary_revenue) as recognised_ancillary_revenue,
        sum(reversal_or_adjustment_total) as reversal_or_adjustment_total,
        sum(net_recognised_revenue) as net_recognised_revenue,
        sum(passenger_count) as passenger_count
    from daily_revenue
    group by currency

)

select
    currency,
    cast(recognised_ticket_revenue as decimal(18, 2)) as recognised_ticket_revenue,
    cast(recognised_ancillary_revenue as decimal(18, 2)) as recognised_ancillary_revenue,
    cast(reversal_or_adjustment_total as decimal(18, 2)) as reversal_or_adjustment_total,
    cast(net_recognised_revenue as decimal(18, 2)) as net_recognised_revenue,
    passenger_count,
    case
        when passenger_count > 0
            then cast(net_recognised_revenue / passenger_count as decimal(18, 2))
    end as revenue_per_passenger
from aggregated
