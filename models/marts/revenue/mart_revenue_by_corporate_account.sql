-- Grain is one row per (corporate_account_id, currency). Reuses fct_revenue directly for
-- recognised revenue; no pricing logic is recomputed. corporate_account_id is a degenerate
-- identifier carried on fct_bookings (no dim_corporate_account exists in this repository -- see
-- fct_bookings' own documentation), resolved here via fct_revenue.booking_id. Only bookings with a
-- non-null corporate_account_id are included, matching int_corporate_outstanding_balances'
-- (Milestone 18) own scoping convention.
with bookings as (

    select
        booking_id,
        corporate_account_id
    from {{ ref('fct_bookings') }}
    where corporate_account_id is not null

),

revenue_events as (

    select
        booking_id,
        currency,
        event_type,
        gross_recognised_amount
    from {{ ref('fct_revenue') }}
    where event_type in ('ticket_revenue', 'ancillary_revenue')

),

attributed_revenue as (

    select
        bookings.corporate_account_id,
        revenue_events.currency,
        revenue_events.event_type,
        revenue_events.gross_recognised_amount
    from revenue_events
    inner join bookings
        on revenue_events.booking_id = bookings.booking_id

),

aggregated as (

    select
        corporate_account_id,
        currency,
        sum(case when event_type = 'ticket_revenue' then gross_recognised_amount else 0 end)
            as recognised_ticket_revenue,
        sum(case when event_type = 'ancillary_revenue' then gross_recognised_amount else 0 end)
            as recognised_ancillary_revenue,
        sum(gross_recognised_amount) as total_recognised_revenue
    from attributed_revenue
    group by corporate_account_id, currency

)

select
    corporate_account_id,
    currency,
    cast(recognised_ticket_revenue as decimal(18, 2)) as recognised_ticket_revenue,
    cast(recognised_ancillary_revenue as decimal(18, 2)) as recognised_ancillary_revenue,
    cast(total_recognised_revenue as decimal(18, 2)) as total_recognised_revenue
from aggregated
