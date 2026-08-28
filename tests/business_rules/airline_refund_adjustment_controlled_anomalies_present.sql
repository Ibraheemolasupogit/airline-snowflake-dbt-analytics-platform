-- Guards against accidentally "fixing" or filtering out either of the two Milestone 9 controlled
-- refund/adjustment anomalies this milestone is required to preserve. Fails (returns a row) for
-- any signature whose occurrence count has dropped to zero -- the inverse of a normal singular
-- test, since here the absence of the anomaly is the failure, not its presence. See
-- docs/data_models/airline_synthetic_exception_catalogue.md for the source definitions.
with signature_counts as (

    select
        'refund_greater_than_collected_amount' as signature,
        count(*) as occurrences
    from {{ ref('int_refund_allocation') }}
    where refund_limit_variance > 0

    union all

    select
        'invalid_adjustment_invoice_mismatch' as signature,
        count(*) as occurrences
    from {{ ref('int_adjustment_allocation') }}
    where has_invoice_match = false

    union all

    select
        'invalid_adjustment_sign_mismatch' as signature,
        count(*) as occurrences
    from {{ ref('int_adjustment_allocation') }}
    where has_expected_sign_for_type = false

)

select
    signature,
    occurrences
from signature_counts
where occurrences = 0
