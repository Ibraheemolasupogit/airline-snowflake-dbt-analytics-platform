-- Preserves fulfilment_status exactly as generated, including the two deliberately injected
-- controlled exceptions (ancillary_sold_but_not_fulfilled, ancillary_fulfilled_but_not_billed).
with source as (

    select *
    from {{ source('airline_pricing', 'ancillary_services') }}

),

renamed as (

    select
        nullif(trim(cast(ancillary_service_id as varchar)), '') as ancillary_service_id,
        nullif(trim(cast(ticket_id as varchar)), '') as ticket_id,
        nullif(trim(cast(service_code as varchar)), '') as service_code,
        try_to_number(nullif(trim(cast(quantity as varchar)), ''), 38, 0) as quantity,
        try_to_decimal(nullif(trim(cast(unit_price as varchar)), ''), 18, 2) as unit_price,
        nullif(trim(cast(currency as varchar)), '') as currency,
        nullif(trim(cast(fulfilment_status as varchar)), '') as fulfilment_status,
        try_to_timestamp_ntz(nullif(trim(cast(purchase_date_utc as varchar)), '')) as purchase_date_utc
    from source

)

select
    ancillary_service_id,
    ticket_id,
    service_code,
    quantity,
    unit_price,
    currency,
    fulfilment_status,
    purchase_date_utc
from renamed
