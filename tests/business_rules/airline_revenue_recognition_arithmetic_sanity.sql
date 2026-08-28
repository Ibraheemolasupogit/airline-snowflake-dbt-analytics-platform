-- Recomputes recognised revenue for both ticket_revenue and ancillary_revenue events directly
-- from their raw fulfilment/pricing signals, bypassing the intermediate recognition models
-- entirely, and fails if either disagrees with fct_revenue's own output by more than a cent. This
-- is the combined regression guard for "completed transport recognition consistency",
-- "cancelled/non-flown zero-recognition logic", and "unfulfilled ancillary zero-recognition
-- logic" -- not a tautology, since it never reads int_ticket_revenue_recognition or
-- int_ancillary_revenue_recognition.
with recomputed_ticket_eligibility as (

    select
        ticket_id,
        count(*) as total_segments,
        sum(case when fulfilment_indicator then 1 else 0 end) as fulfilled_segments
    from {{ ref('int_fulfilled_flight_services') }}
    group by ticket_id

),

recomputed_ticket_pricing as (

    select
        ticket_id,
        sum(amount) as priced_fare_amount
    from {{ ref('fct_pricing_events') }}
    where component_type in ('base_fare', 'distance_fare')
    group by ticket_id

),

recomputed_ticket_revenue as (

    select
        'ticket_revenue' as event_type,
        recomputed_ticket_eligibility.ticket_id as source_event_id,
        case
            when
                recomputed_ticket_eligibility.total_segments > 0
                and recomputed_ticket_eligibility.fulfilled_segments
                = recomputed_ticket_eligibility.total_segments
                then recomputed_ticket_pricing.priced_fare_amount
            else 0
        end as recomputed_gross_recognised_amount
    from recomputed_ticket_eligibility
    left join recomputed_ticket_pricing
        on recomputed_ticket_eligibility.ticket_id = recomputed_ticket_pricing.ticket_id

),

recomputed_ancillary_revenue as (

    select
        'ancillary_revenue' as event_type,
        ancillary_service_id as source_event_id,
        case when fulfilment_status = 'fulfilled' then amount else 0 end as recomputed_gross_recognised_amount
    from {{ ref('stg_airline__ancillary_services') }}

),

recomputed as (

    select * from recomputed_ticket_revenue
    union all
    select * from recomputed_ancillary_revenue

)

select
    recomputed.event_type,
    recomputed.source_event_id,
    recomputed.recomputed_gross_recognised_amount,
    fct_revenue.gross_recognised_amount
from recomputed
inner join {{ ref('fct_revenue') }}
    on
        recomputed.event_type = fct_revenue.event_type
        and recomputed.source_event_id = fct_revenue.source_event_id
where abs(recomputed.recomputed_gross_recognised_amount - fct_revenue.gross_recognised_amount) > 0.01
