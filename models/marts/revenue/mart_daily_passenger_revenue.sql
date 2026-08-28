-- Grain is one row per (recognition/event date, currency). Reuses fct_revenue (Milestone 17)
-- directly -- no revenue recognition logic is recomputed here. passenger_count counts distinct
-- passengers only from ticket_revenue events (the only event type with a meaningful passenger).
with revenue_events as (

    select
        cast(event_date as date) as event_date,
        currency,
        event_type,
        passenger_id,
        gross_recognised_amount,
        reversal_or_adjustment_amount,
        net_recognised_amount
    from {{ ref('fct_revenue') }}

),

aggregated as (

    select
        event_date,
        currency,
        sum(case when event_type = 'ticket_revenue' then gross_recognised_amount else 0 end)
            as recognised_ticket_revenue,
        sum(case when event_type = 'ancillary_revenue' then gross_recognised_amount else 0 end)
            as recognised_ancillary_revenue,
        sum(reversal_or_adjustment_amount) as reversal_or_adjustment_total,
        sum(net_recognised_amount) as net_recognised_revenue,
        count(distinct case when event_type = 'ticket_revenue' then passenger_id end)
            as passenger_count
    from revenue_events
    group by event_date, currency

)

select
    event_date,
    currency,
    cast(recognised_ticket_revenue as decimal(18, 2)) as recognised_ticket_revenue,
    cast(recognised_ancillary_revenue as decimal(18, 2)) as recognised_ancillary_revenue,
    cast(reversal_or_adjustment_total as decimal(18, 2)) as reversal_or_adjustment_total,
    cast(net_recognised_revenue as decimal(18, 2)) as net_recognised_revenue,
    passenger_count
from aggregated
