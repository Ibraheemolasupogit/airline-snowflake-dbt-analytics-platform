-- Controlled exception coverage test (see Milestone 18 scope section 21): rather than ingesting
-- data/synthetic/exception_manifest.csv as a new dbt source solely for this comparison, this test
-- uses the fact that every one of the fourteen exception_types implemented in
-- int_billing_exceptions maps 1:1 to a specific, deliberately injected Milestone 9 controlled
-- exception (see docs/data_models/airline_synthetic_exception_catalogue.md and
-- docs/data_models/airline_outstanding_balances_exceptions.md's coverage table). Detection is
-- entirely rule-based (see int_billing_exceptions' own model comment); this test only asserts that
-- each rule's expected occurrence count has NOT dropped to zero -- the inverse of a normal
-- singular test, since here the absence of a detected row is the failure, not its presence. No
-- record is matched by hard-coded ID anywhere in this test or in int_billing_exceptions itself.
with expected_types as (

    select column1 as exception_type
    from
        values
        ('duplicate_invoice'),
        ('failed_payment_after_ticket_issue'),
        ('unallocated_payment'),
        ('payment_without_invoice'),
        ('incorrect_fare'),
        ('currency_mismatch'),
        ('refund_greater_than_collected_amount'),
        ('invalid_adjustment'),
        ('cancelled_flight_without_refund'),
        ('completed_segment_without_recognised_revenue_precursor'),
        ('ancillary_sold_but_not_fulfilled'),
        ('ancillary_fulfilled_but_not_billed'),
        ('missing_invoice_line'),
        ('late_arriving_payment')

),

detected_counts as (

    select
        exception_type,
        count(*) as occurrences
    from {{ ref('int_billing_exceptions') }}
    group by exception_type

)

select
    expected_types.exception_type,
    coalesce(detected_counts.occurrences, 0) as occurrences
from expected_types
left join detected_counts
    on expected_types.exception_type = detected_counts.exception_type
where coalesce(detected_counts.occurrences, 0) = 0
