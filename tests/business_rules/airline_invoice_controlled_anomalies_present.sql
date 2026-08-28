-- Guards against accidentally "fixing" or filtering out any of the four Milestone 9 controlled
-- billing anomalies this milestone is required to preserve. Fails (returns a row) for any
-- signature whose occurrence count has dropped to zero -- the inverse of a normal singular test,
-- since here the absence of the anomaly is the failure, not its presence. See
-- docs/data_models/airline_synthetic_exception_catalogue.md for the source definitions.
with signature_counts as (

    select
        'duplicate_invoice' as signature,
        count(*) as occurrences
    from (
        select booking_id
        from {{ ref('stg_airline__invoices') }}
        group by booking_id
        having count(*) > 1
    ) as duplicated_bookings

    union all

    select
        'missing_invoice_line_or_base_fare' as signature,
        count(*) as occurrences
    from {{ ref('int_invoice_calculation') }}
    where invoice_total_variance <> 0

    union all

    select
        'incorrect_fare' as signature,
        count(*) as occurrences
    from {{ ref('int_invoice_charge_comparison') }}
    where
        comparable_line_type = 'base_fare'
        and invoiced_amount is not null
        and variance_amount <> 0

    union all

    select
        'completed_segment_without_recognised_revenue_precursor' as signature,
        count(*) as occurrences
    from {{ ref('int_invoice_charge_comparison') }}
    where
        comparable_line_type = 'base_fare'
        and invoiced_amount is null
        and expected_amount is not null

)

select
    signature,
    occurrences
from signature_counts
where occurrences = 0
