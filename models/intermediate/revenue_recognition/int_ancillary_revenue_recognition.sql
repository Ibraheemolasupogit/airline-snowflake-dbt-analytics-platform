-- Grain is one row per ancillary service/sale (ancillary_service_id). Reuses
-- int_fulfilled_ancillary_services rather than re-deriving fulfilment logic. Recognises only
-- fulfilled ancillary services -- "sold" (is_sold, always true here) is never treated as
-- equivalent to "fulfilled" (fulfilment_indicator).
--
-- purchase_date_utc is preserved under its own honest name, not renamed to a "recognition_date":
-- it is the date the ancillary was SOLD, not a distinct fulfilment timestamp -- the Milestone 9
-- specification has no separate "ancillary delivered" event/timestamp anywhere, so no such date is
-- fabricated here. A consumer wanting an ancillary recognition date should treat purchase_date_utc
-- as the only available reference point, understanding its limitation.
with fulfilled_ancillaries as (

    select
        ancillary_service_id,
        ticket_id,
        booking_id,
        passenger_id,
        service_code,
        amount,
        currency,
        is_sold,
        fulfilment_status,
        fulfilment_indicator,
        purchase_date_utc
    from {{ ref('int_fulfilled_ancillary_services') }}

),

final as (

    select
        ancillary_service_id,
        ticket_id,
        booking_id,
        passenger_id,
        service_code,
        currency,
        amount,
        is_sold,
        fulfilment_status,
        fulfilment_indicator,
        purchase_date_utc,
        case when fulfilment_indicator then amount else 0 end as recognised_amount
    from fulfilled_ancillaries

)

select
    ancillary_service_id,
    ticket_id,
    booking_id,
    passenger_id,
    service_code,
    currency,
    amount,
    is_sold,
    fulfilment_status,
    fulfilment_indicator,
    cast(recognised_amount as decimal(18, 2)) as recognised_amount,
    purchase_date_utc
from final
