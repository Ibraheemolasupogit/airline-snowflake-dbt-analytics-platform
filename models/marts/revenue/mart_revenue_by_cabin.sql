-- Grain is one row per (cabin, currency). Reuses fct_revenue directly for recognised revenue; no
-- pricing logic is recomputed. cabin/cabin_key are looked up via distinct ticket_id from
-- fct_ticket_segments -- safe because every ticket's segments share one cabin (Milestone 12's own
-- invariant), unlike route_id, which is NOT safely derivable this way for round trips.
with ticket_cabin as (

    select distinct
        ticket_id,
        cabin_key,
        cabin
    from {{ ref('fct_ticket_segments') }}

),

revenue_events as (

    select
        event_type,
        ticket_id,
        currency,
        gross_recognised_amount
    from {{ ref('fct_revenue') }}
    where event_type in ('ticket_revenue', 'ancillary_revenue')

),

attributed_revenue as (

    select
        ticket_cabin.cabin_key,
        ticket_cabin.cabin,
        revenue_events.currency,
        revenue_events.event_type,
        revenue_events.ticket_id,
        revenue_events.gross_recognised_amount
    from revenue_events
    left join ticket_cabin
        on revenue_events.ticket_id = ticket_cabin.ticket_id

),

aggregated as (

    select
        cabin_key,
        cabin,
        currency,
        sum(case when event_type = 'ticket_revenue' then gross_recognised_amount else 0 end)
            as recognised_ticket_revenue,
        sum(case when event_type = 'ancillary_revenue' then gross_recognised_amount else 0 end)
            as recognised_ancillary_revenue,
        sum(gross_recognised_amount) as total_recognised_revenue,
        count(distinct case when event_type = 'ticket_revenue' then ticket_id end) as ticket_count
    from attributed_revenue
    group by cabin_key, cabin, currency

)

select
    cabin_key,
    cabin,
    currency,
    cast(recognised_ticket_revenue as decimal(18, 2)) as recognised_ticket_revenue,
    cast(recognised_ancillary_revenue as decimal(18, 2)) as recognised_ancillary_revenue,
    cast(total_recognised_revenue as decimal(18, 2)) as total_recognised_revenue,
    ticket_count,
    case
        when ticket_count > 0
            then cast(total_recognised_revenue / ticket_count as decimal(18, 2))
    end as average_ticket_value
from aggregated
