-- Guards against accidentally losing the observable evidence of three Milestone 9 controlled
-- anomalies this milestone's revenue/invoice separation is specifically designed to surface. Fails
-- (returns a row) for any signature whose occurrence count has dropped to zero -- the inverse of a
-- normal singular test, since here the absence of the evidence is the failure. See
-- docs/data_models/airline_synthetic_exception_catalogue.md for the source definitions.
with signature_counts as (

    select
        'completed_segment_without_recognised_revenue_precursor' as signature,
        count(*) as occurrences
    from {{ ref('fct_revenue') }} as revenue
    where
        revenue.event_type = 'ticket_revenue'
        and revenue.gross_recognised_amount > 0
        and not exists (
            select 1
            from {{ ref('fct_invoice_lines') }} as invoice_lines
            where
                invoice_lines.ticket_id = revenue.ticket_id
                and invoice_lines.line_type = 'base_fare'
        )

    union all

    select
        'ancillary_sold_but_not_fulfilled' as signature,
        count(*) as occurrences
    from {{ ref('int_fulfilled_ancillary_services') }} as ancillary
    inner join {{ ref('int_ticket_revenue_recognition') }} as ticket_revenue
        on ancillary.ticket_id = ticket_revenue.ticket_id
    where
        ancillary.fulfilment_indicator = false
        and ticket_revenue.is_recognition_eligible = true

    union all

    select
        'ancillary_fulfilled_but_not_billed' as signature,
        count(*) as occurrences
    from {{ ref('int_fulfilled_ancillary_services') }} as ancillary
    where
        ancillary.fulfilment_indicator = true
        and not exists (
            select 1
            from {{ ref('fct_invoice_lines') }} as invoice_lines
            where
                invoice_lines.ticket_id = ancillary.ticket_id
                and invoice_lines.line_type = 'ancillary'
                and invoice_lines.reference_code = ancillary.service_code
        )

)

select
    signature,
    occurrences
from signature_counts
where occurrences = 0
