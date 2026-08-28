-- Grain is one row per booking channel. No standalone booking-channel source table exists, so
-- this is derived from the distinct values staged in stg_airline__bookings.booking_channel.
with distinct_channels as (

    select distinct booking_channel
    from {{ ref('stg_airline__bookings') }}
    where booking_channel is not null

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['booking_channel']) }} as booking_channel_key,
        booking_channel
    from distinct_channels

)

select
    booking_channel_key,
    booking_channel
from final
