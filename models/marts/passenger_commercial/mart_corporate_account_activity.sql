-- Grain is one row per (corporate_account_id, currency) -- reusing int_corporate_outstanding_
-- balances (Milestone 18), which is already currency-safe (never summing across currencies).
-- booking_count/total_passenger_count are currency-agnostic counts, joined in separately with no
-- currency-mixing risk.
with corporate_balances as (

    select
        corporate_account_id,
        company_name,
        currency,
        invoice_count,
        total_invoiced,
        total_outstanding_balance
    from {{ ref('int_corporate_outstanding_balances') }}

),

bookings as (

    select
        corporate_account_id,
        count(*) as booking_count,
        sum(passenger_count) as total_passenger_count
    from {{ ref('fct_bookings') }}
    where corporate_account_id is not null
    group by corporate_account_id

)

select
    corporate_balances.corporate_account_id,
    corporate_balances.company_name,
    corporate_balances.currency,
    corporate_balances.invoice_count,
    corporate_balances.total_invoiced,
    corporate_balances.total_outstanding_balance,
    coalesce(bookings.booking_count, 0) as booking_count,
    coalesce(bookings.total_passenger_count, 0) as total_passenger_count
from corporate_balances
left join bookings
    on corporate_balances.corporate_account_id = bookings.corporate_account_id
