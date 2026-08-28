-- Grain is one row per (exception_type, severity, status, currency, route_id, corporate_account_id).
-- Reuses fct_billing_exceptions (Milestone 18) directly -- no exception is re-detected,
-- reclassified, or recomputed here. route_id/corporate_account_id are the two additional slicing
-- dimensions available per this milestone's own instruction ("route/account where available");
-- both are null for exception types that are not route- or booking-scoped, matching
-- fct_billing_exceptions' own sparse-union design.
with billing_exceptions as (

    select
        exception_type,
        severity,
        status,
        currency,
        route_id,
        booking_id,
        financial_value_at_risk_amount
    from {{ ref('fct_billing_exceptions') }}

),

bookings as (

    select
        booking_id,
        corporate_account_id
    from {{ ref('fct_bookings') }}

),

joined as (

    select
        billing_exceptions.exception_type,
        billing_exceptions.severity,
        billing_exceptions.status,
        billing_exceptions.currency,
        billing_exceptions.route_id,
        bookings.corporate_account_id,
        billing_exceptions.financial_value_at_risk_amount
    from billing_exceptions
    left join bookings
        on billing_exceptions.booking_id = bookings.booking_id

),

aggregated as (

    select
        exception_type,
        severity,
        status,
        currency,
        route_id,
        corporate_account_id,
        count(*) as exception_count,
        sum(financial_value_at_risk_amount) as financial_value_at_risk_total
    from joined
    group by exception_type, severity, status, currency, route_id, corporate_account_id

)

select
    exception_type,
    severity,
    status,
    currency,
    route_id,
    corporate_account_id,
    exception_count,
    cast(financial_value_at_risk_total as decimal(18, 2)) as financial_value_at_risk_total
from aggregated
