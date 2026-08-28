-- Grain is one row per ancillary sale/service record (ancillary_service_id), reusing
-- int_ancillary_charge_calculation (Milestone 13) rather than re-deriving pricing or fulfilment
-- logic. is_sold is trivially true for every row here (the record's existence in
-- stg_airline__ancillary_services already means it was sold) -- included explicitly, not as
-- filler, to make the "sold != fulfilled" distinction this milestone requires visible directly in
-- the data model, not just in documentation.
--
-- fulfilment_indicator = (fulfilment_status = 'fulfilled'), taken directly from
-- stg_airline__ancillary_services.fulfilment_status -- the only fulfilment signal the source
-- provides for ancillaries (docs/data_models/airline_synthetic_source_data.md's "Determining
-- fulfilment for later revenue recognition" section). fulfilment is never inferred from payment,
-- invoicing, or purchase_date_utc alone.
with ancillary_pricing as (

    select
        ancillary_service_id,
        ticket_id,
        booking_id,
        passenger_id,
        service_code,
        service_name,
        amount,
        amount_usd,
        currency,
        booking_currency,
        fulfilment_status,
        purchase_date_utc
    from {{ ref('int_ancillary_charge_calculation') }}

),

final as (

    select
        ancillary_service_id,
        ticket_id,
        booking_id,
        passenger_id,
        service_code,
        service_name,
        amount,
        amount_usd,
        currency,
        booking_currency,
        true as is_sold,
        fulfilment_status,
        purchase_date_utc,
        fulfilment_status = 'fulfilled' as fulfilment_indicator
    from ancillary_pricing

)

select
    ancillary_service_id,
    ticket_id,
    booking_id,
    passenger_id,
    service_code,
    service_name,
    amount,
    amount_usd,
    currency,
    booking_currency,
    is_sold,
    fulfilment_status,
    fulfilment_indicator,
    purchase_date_utc
from final
