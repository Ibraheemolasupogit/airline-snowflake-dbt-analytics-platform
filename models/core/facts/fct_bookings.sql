-- Grain is one row per booking. No fare, invoice, or revenue measures -- passenger_count and
-- ticket_count are structural counts only. See int_booking_current_state for why this is a
-- current-state model (the source has no booking-status history).
with bookings as (

    select
        booking_id,
        booking_reference,
        airline_code,
        route_id,
        return_route_id,
        trip_type,
        booking_channel,
        booking_date_utc,
        point_of_sale_country,
        currency,
        booking_status,
        corporate_account_id,
        travel_agent_id,
        discount_code,
        outbound_flight_instance_id,
        return_flight_instance_id,
        passenger_count,
        ticket_count,
        is_cancelled
    from {{ ref('int_booking_current_state') }}

),

airlines as (

    select
        airline_key,
        airline_code
    from {{ ref('dim_airline') }}

),

routes as (

    select
        route_key,
        route_id
    from {{ ref('dim_route') }}

),

booking_channels as (

    select
        booking_channel_key,
        booking_channel
    from {{ ref('dim_booking_channel') }}

),

joined as (

    select
        bookings.booking_id,
        bookings.booking_reference,
        airlines.airline_key,
        bookings.airline_code,
        routes.route_key,
        bookings.route_id,
        bookings.return_route_id,
        bookings.trip_type,
        booking_channels.booking_channel_key,
        bookings.booking_channel,
        bookings.booking_date_utc,
        bookings.point_of_sale_country,
        bookings.currency,
        bookings.booking_status,
        bookings.corporate_account_id,
        bookings.travel_agent_id,
        bookings.discount_code,
        bookings.outbound_flight_instance_id,
        bookings.return_flight_instance_id,
        bookings.passenger_count,
        bookings.ticket_count,
        bookings.is_cancelled
    from bookings
    left join airlines
        on bookings.airline_code = airlines.airline_code
    left join routes
        on bookings.route_id = routes.route_id
    left join booking_channels
        on bookings.booking_channel = booking_channels.booking_channel

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['booking_id']) }} as booking_key,
        booking_id,
        booking_reference,
        airline_key,
        airline_code,
        route_key,
        route_id,
        return_route_id,
        trip_type,
        booking_channel_key,
        booking_channel,
        booking_date_utc,
        point_of_sale_country,
        currency,
        booking_status,
        corporate_account_id,
        travel_agent_id,
        discount_code,
        outbound_flight_instance_id,
        return_flight_instance_id,
        passenger_count,
        ticket_count,
        is_cancelled
    from joined

)

select
    booking_key,
    booking_id,
    booking_reference,
    airline_key,
    airline_code,
    route_key,
    route_id,
    return_route_id,
    trip_type,
    booking_channel_key,
    booking_channel,
    booking_date_utc,
    point_of_sale_country,
    currency,
    booking_status,
    corporate_account_id,
    travel_agent_id,
    discount_code,
    outbound_flight_instance_id,
    return_flight_instance_id,
    passenger_count,
    ticket_count,
    is_cancelled
from final
