-- Guards against accidentally "fixing" or filtering out any of the five Milestone 9 controlled
-- payment anomalies this milestone is required to preserve. Fails (returns a row) for any
-- signature whose occurrence count has dropped to zero -- the inverse of a normal singular test,
-- since here the absence of the anomaly is the failure, not its presence. See
-- docs/data_models/airline_synthetic_exception_catalogue.md for the source definitions.
with signature_counts as (

    select
        'failed_payment' as signature,
        count(*) as occurrences
    from {{ ref('stg_airline__invoices') }} as invoices
    where
        invoices.status = 'issued'
        and invoices.total_amount > 0
        and not exists (
            select 1 from {{ ref('stg_airline__payments') }} as payments
            where payments.invoice_id = invoices.invoice_id
        )
        and exists (
            select 1 from {{ ref('stg_airline__payment_attempts') }} as attempts
            where
                attempts.invoice_id = invoices.invoice_id
                and attempts.result = 'failed'
        )

    union all

    select
        'unallocated_payment' as signature,
        count(*) as occurrences
    from {{ ref('stg_airline__payments') }}
    where allocation_status = 'overpaid_unallocated'

    union all

    select
        'late_arriving_payment' as signature,
        count(*) as occurrences
    from {{ ref('int_invoice_payment_matching') }}
    where payment_delay_days > 30

    union all

    select
        'payment_without_invoice' as signature,
        count(*) as occurrences
    from {{ ref('int_invoice_payment_matching') }}
    where has_invoice_match = false

    union all

    select
        'currency_mismatch' as signature,
        count(*) as occurrences
    from {{ ref('int_invoice_payment_matching') }}
    where is_currency_match = false

)

select
    signature,
    occurrences
from signature_counts
where occurrences = 0
