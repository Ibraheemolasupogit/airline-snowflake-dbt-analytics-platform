-- Grain is one row per detected billing/revenue exception. Every branch below reuses an existing
-- Milestone 14-17 evidence column directly -- nothing here recomputes pricing, invoice arithmetic,
-- payment allocation, refund logic, or revenue recognition. source_system mirrors the exact
-- "Affected entity" taxonomy already used in docs/data_models/airline_synthetic_exception_
-- catalogue.md, reusing that vocabulary rather than inventing a new one.
--
-- No exception row's ID is hard-coded: every branch is a deterministic rule over existing
-- evidence columns, so it would fire identically against any dataset the same generator produces,
-- not just the current one. Where the exception catalogue's own detection rule already exists as
-- a preserved evidence column (e.g. pricing_variance_amount, unallocated_amount, is_currency_match,
-- refund_limit_variance, has_expected_sign_for_type), that column is read directly.
--
-- detected_at is the affected record's OWN natural timestamp (invoice date, payment date, refund
-- date, etc.) -- a deterministic proxy for "when the underlying condition arose", not a fabricated
-- "when a human found this" workflow timestamp; no such timestamp exists anywhere in the source.
--
-- financial_value_at_risk_amount is always a non-negative absolute magnitude (see each branch's
-- comment for its specific source) except late_arriving_payment, which is genuinely 0: a timing
-- anomaly on money that did arrive has no monetary exposure by definition, not an unknown one.
with duplicate_invoice_exceptions as (

    -- Booking-level: more than one invoice_id shares the same booking_id (fct_invoices.booking_id
    -- is deliberately not unique-tested -- see docs/data_models/airline_invoices.md). Verified
    -- against scripts/airline_synth/exceptions.py: the duplicate invoice clones the header and
    -- lines but never a payment, so amount_collected for the duplicate is always 0 -- confirmed by
    -- this booking-level rule alone, no ID is assumed. financial_value_at_risk_amount is the total
    -- erroneous EXTRA billing for the booking: sum(source_invoice_total) - max(source_invoice_total)
    -- (i.e. every invoice beyond the one that should legitimately exist).
    select
        'duplicate_invoice' as exception_type,
        'invoices' as source_system,
        listagg(invoice_id, '|') within group (order by invoice_id) as source_record_id,
        booking_id,
        cast(null as varchar) as ticket_id,
        cast(null as varchar) as ticket_segment_id,
        cast(null as varchar) as flight_instance_id,
        listagg(invoice_id, '|') within group (order by invoice_id) as invoice_id,
        cast(null as varchar) as payment_id,
        cast(null as varchar) as refund_id,
        cast(null as varchar) as adjustment_id,
        cast(null as varchar) as route_id,
        cast(null as varchar) as airport_ident,
        max(currency) as currency,
        min(invoice_date_utc) as detected_at,
        sum(source_invoice_total) - max(source_invoice_total) as financial_value_at_risk_amount,
        'More than one invoice exists for this booking_id' as rule_description
    from {{ ref('fct_invoices') }}
    group by booking_id
    having count(*) > 1

),

failed_payment_after_ticket_issue_exceptions as (

    -- An issued invoice (tickets were issued to reach this point) with total_amount > 0, zero
    -- successful payments, but at least one failed attempt -- reusing fct_invoices.payment_count
    -- (M15) and fct_payment_attempts.attempt_classification (M15) directly.
    select
        'failed_payment_after_ticket_issue' as exception_type,
        'invoices' as source_system,
        invoices.invoice_id as source_record_id,
        invoices.booking_id,
        cast(null as varchar) as ticket_id,
        cast(null as varchar) as ticket_segment_id,
        cast(null as varchar) as flight_instance_id,
        invoices.invoice_id,
        cast(null as varchar) as payment_id,
        cast(null as varchar) as refund_id,
        cast(null as varchar) as adjustment_id,
        cast(null as varchar) as route_id,
        cast(null as varchar) as airport_ident,
        invoices.currency,
        invoices.invoice_date_utc as detected_at,
        invoices.source_invoice_total as financial_value_at_risk_amount,
        'Issued invoice with total_amount > 0, zero successful payments, at least one failed attempt'
            as rule_description
    from {{ ref('fct_invoices') }} as invoices
    where
        invoices.status = 'issued'
        and invoices.source_invoice_total > 0
        and invoices.payment_count = 0
        and exists (
            select 1
            from {{ ref('fct_payment_attempts') }} as attempts
            where
                attempts.invoice_id = invoices.invoice_id
                and attempts.attempt_classification = 'failed'
        )

),

unallocated_payment_exceptions as (

    -- A matched (has_invoice_match) payment with a positive unallocated_amount -- reusing
    -- fct_payments.unallocated_amount/has_invoice_match (M15) directly. Excludes
    -- payment_without_invoice (has_invoice_match = false), which is its own exception type below.
    select
        'unallocated_payment' as exception_type,
        'payments' as source_system,
        payment_id as source_record_id,
        booking_id,
        cast(null as varchar) as ticket_id,
        cast(null as varchar) as ticket_segment_id,
        cast(null as varchar) as flight_instance_id,
        invoice_id,
        payment_id,
        cast(null as varchar) as refund_id,
        cast(null as varchar) as adjustment_id,
        cast(null as varchar) as route_id,
        cast(null as varchar) as airport_ident,
        currency,
        payment_datetime_utc as detected_at,
        unallocated_amount as financial_value_at_risk_amount,
        'Payment matched to an invoice but not fully allocated to it' as rule_description
    from {{ ref('fct_payments') }}
    where
        unallocated_amount > 0
        and has_invoice_match

),

payment_without_invoice_exceptions as (

    -- A payment whose invoice_id does not resolve to a real invoice -- reusing
    -- fct_payments.has_invoice_match (M15) directly.
    select
        'payment_without_invoice' as exception_type,
        'payments' as source_system,
        payment_id as source_record_id,
        booking_id,
        cast(null as varchar) as ticket_id,
        cast(null as varchar) as ticket_segment_id,
        cast(null as varchar) as flight_instance_id,
        invoice_id,
        payment_id,
        cast(null as varchar) as refund_id,
        cast(null as varchar) as adjustment_id,
        cast(null as varchar) as route_id,
        cast(null as varchar) as airport_ident,
        currency,
        payment_datetime_utc as detected_at,
        payment_amount as financial_value_at_risk_amount,
        'Payment invoice_id does not resolve to a real invoice' as rule_description
    from {{ ref('fct_payments') }}
    where not has_invoice_match

),

incorrect_fare_exceptions as (

    -- A base_fare invoice line whose pricing_variance_amount (M14, expected vs. invoiced, already
    -- computed from Milestone 13 pricing) is nonzero -- reused directly, never recalculated.
    select
        'incorrect_fare' as exception_type,
        'invoice_lines' as source_system,
        invoice_lines.invoice_line_id as source_record_id,
        invoice_lines.booking_id,
        invoice_lines.ticket_id,
        cast(null as varchar) as ticket_segment_id,
        cast(null as varchar) as flight_instance_id,
        invoice_lines.invoice_id,
        cast(null as varchar) as payment_id,
        cast(null as varchar) as refund_id,
        cast(null as varchar) as adjustment_id,
        cast(null as varchar) as route_id,
        cast(null as varchar) as airport_ident,
        invoice_lines.currency,
        invoices.invoice_date_utc as detected_at,
        abs(invoice_lines.pricing_variance_amount) as financial_value_at_risk_amount,
        'base_fare invoice line amount disagrees with expected Milestone 13 pricing' as rule_description
    from {{ ref('fct_invoice_lines') }} as invoice_lines
    left join {{ ref('fct_invoices') }} as invoices
        on invoice_lines.invoice_id = invoices.invoice_id
    where
        invoice_lines.line_type = 'base_fare'
        and invoice_lines.pricing_variance_amount is not null
        and invoice_lines.pricing_variance_amount != 0

),

currency_mismatch_exceptions as (

    -- A matched payment whose currency differs from its invoice's currency -- reusing
    -- fct_payments.is_currency_match (M15) directly. is_currency_match is null (not false) when
    -- unmatched, so this condition alone already excludes payment_without_invoice rows.
    select
        'currency_mismatch' as exception_type,
        'payments' as source_system,
        payment_id as source_record_id,
        booking_id,
        cast(null as varchar) as ticket_id,
        cast(null as varchar) as ticket_segment_id,
        cast(null as varchar) as flight_instance_id,
        invoice_id,
        payment_id,
        cast(null as varchar) as refund_id,
        cast(null as varchar) as adjustment_id,
        cast(null as varchar) as route_id,
        cast(null as varchar) as airport_ident,
        currency,
        payment_datetime_utc as detected_at,
        payment_amount as financial_value_at_risk_amount,
        'Payment currency differs from its invoice currency, with no recorded conversion' as rule_description
    from {{ ref('fct_payments') }}
    where is_currency_match = false

),

refund_greater_than_collected_amount_exceptions as (

    -- A refund whose refund_limit_variance (M16, refund_amount - matched payment's amount) is
    -- positive -- reused directly.
    select
        'refund_greater_than_collected_amount' as exception_type,
        'refunds' as source_system,
        refund_id as source_record_id,
        booking_id,
        cast(null as varchar) as ticket_id,
        cast(null as varchar) as ticket_segment_id,
        cast(null as varchar) as flight_instance_id,
        invoice_id,
        payment_id,
        refund_id,
        cast(null as varchar) as adjustment_id,
        cast(null as varchar) as route_id,
        cast(null as varchar) as airport_ident,
        currency,
        refund_datetime_utc as detected_at,
        refund_limit_variance as financial_value_at_risk_amount,
        'Refund amount exceeds the amount collected on its matched payment' as rule_description
    from {{ ref('fct_refunds') }}
    where refund_limit_variance > 0

),

invalid_adjustment_exceptions as (

    -- An adjustment that either does not resolve to a real invoice, or has an amount sign
    -- inconsistent with its own adjustment_type -- reusing fct_adjustments.has_invoice_match /
    -- has_expected_sign_for_type (M16) directly. The deliberately injected invalid_adjustment
    -- controlled exception fails BOTH conditions on the same row; either alone is sufficient to
    -- flag a row here.
    select
        'invalid_adjustment' as exception_type,
        'adjustments' as source_system,
        adjustment_id as source_record_id,
        booking_id,
        cast(null as varchar) as ticket_id,
        cast(null as varchar) as ticket_segment_id,
        cast(null as varchar) as flight_instance_id,
        invoice_id,
        cast(null as varchar) as payment_id,
        cast(null as varchar) as refund_id,
        adjustment_id,
        cast(null as varchar) as route_id,
        cast(null as varchar) as airport_ident,
        currency,
        created_at_utc as detected_at,
        abs(amount) as financial_value_at_risk_amount,
        'Adjustment invoice_id does not resolve, or amount sign is inconsistent with adjustment_type'
            as rule_description
    from {{ ref('fct_adjustments') }}
    where
        not has_invoice_match
        or not has_expected_sign_for_type

),

cancelled_flight_without_refund_exceptions as (

    -- A ticket segment resolved to journey_completion_status = 'cancelled' (int_fulfilled_flight_
    -- services, M17, reused unchanged) whose BOOKING is NOT itself cancelled, and for which no
    -- refund exists at all. Verified against scripts/airline_synth/exceptions.py: in the normal
    -- flow, segment_status only becomes 'cancelled' when the booking itself was cancelled
    -- (cascading cancellation) or via this exact controlled exception (an operational
    -- flight-instance cancellation applied post-hoc, deliberately leaving the booking/invoice/
    -- payment untouched) -- so "segment cancelled but booking not cancelled" is a precise,
    -- non-hardcoded signature for this specific condition, not an inferred refund entitlement.
    --
    -- Grain here is one row per affected ticket_segment (not flight_instance, the exception
    -- catalogue's own key), a deliberate deviation: multiple passengers/segments can share one
    -- flight_instance_id, and tracking each affected passenger's own financial exposure
    -- separately is more useful than one row per flight. financial_value_at_risk_amount reuses
    -- the ticket's own priced_fare_amount (Milestone 13/17, int_ticket_revenue_recognition) --
    -- the fare that was paid for a segment that will never be flown and was never refunded.
    select
        'cancelled_flight_without_refund' as exception_type,
        'flight_instances' as source_system,
        segments.ticket_segment_id as source_record_id,
        segments.booking_id,
        segments.ticket_id,
        segments.ticket_segment_id,
        segments.flight_instance_id,
        cast(null as varchar) as invoice_id,
        cast(null as varchar) as payment_id,
        cast(null as varchar) as refund_id,
        cast(null as varchar) as adjustment_id,
        segments.route_id,
        segments.origin_ident as airport_ident,
        ticket_revenue.currency,
        cast(flight_operations.flight_date as timestamp_ntz) as detected_at,
        ticket_revenue.priced_fare_amount as financial_value_at_risk_amount,
        'Ticket segment cancelled but booking not cancelled and no refund exists' as rule_description
    from {{ ref('int_fulfilled_flight_services') }} as segments
    left join {{ ref('fct_bookings') }} as bookings
        on segments.booking_id = bookings.booking_id
    left join {{ ref('int_ticket_revenue_recognition') }} as ticket_revenue
        on segments.ticket_id = ticket_revenue.ticket_id
    left join {{ ref('fct_flight_operations') }} as flight_operations
        on segments.flight_instance_id = flight_operations.flight_instance_id
    where
        segments.is_cancelled
        and not bookings.is_cancelled
        and not exists (
            select 1
            from {{ ref('fct_refunds') }} as refunds
            where refunds.booking_id = segments.booking_id
        )

),

completed_segment_without_recognised_revenue_exceptions as (

    -- A ticket_revenue event (Milestone 17, fct_revenue) with positive gross_recognised_amount --
    -- meaning every one of its segments was fulfilled -- for which no matching base_fare invoice
    -- line exists at all. Reuses fct_revenue and fct_invoice_lines directly; creates no missing
    -- revenue and repairs nothing. Grain is one row per ticket_id, matching Milestone 17's own
    -- ticket-scoped revenue-recognition grain (not per ticket_segment).
    select
        'completed_segment_without_recognised_revenue_precursor' as exception_type,
        'ticket_segments' as source_system,
        revenue.source_event_id as source_record_id,
        revenue.booking_id,
        revenue.ticket_id,
        cast(null as varchar) as ticket_segment_id,
        cast(null as varchar) as flight_instance_id,
        cast(null as varchar) as invoice_id,
        cast(null as varchar) as payment_id,
        cast(null as varchar) as refund_id,
        cast(null as varchar) as adjustment_id,
        revenue.route_id,
        cast(null as varchar) as airport_ident,
        revenue.currency,
        revenue.event_date as detected_at,
        revenue.gross_recognised_amount as financial_value_at_risk_amount,
        'Revenue recognised for a flown ticket with no matching base_fare invoice line' as rule_description
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

),

ancillary_sold_but_not_fulfilled_exceptions as (

    -- An ancillary marked not_fulfilled (int_fulfilled_ancillary_services, M17, reused unchanged)
    -- attached to a ticket that IS recognition-eligible (int_ticket_revenue_recognition, M17) --
    -- i.e. every one of that ticket's segments actually flew. Verified against scripts/
    -- airline_synth/build_bookings.py::build_ancillary_services: a not_fulfilled ancillary can
    -- only naturally occur when none of its ticket's segments ever flew, so this combination is
    -- structurally impossible under normal generation -- a precise, non-hardcoded signature.
    select
        'ancillary_sold_but_not_fulfilled' as exception_type,
        'ancillary_services' as source_system,
        ancillary.ancillary_service_id as source_record_id,
        ancillary.booking_id,
        ancillary.ticket_id,
        cast(null as varchar) as ticket_segment_id,
        cast(null as varchar) as flight_instance_id,
        cast(null as varchar) as invoice_id,
        cast(null as varchar) as payment_id,
        cast(null as varchar) as refund_id,
        cast(null as varchar) as adjustment_id,
        cast(null as varchar) as route_id,
        cast(null as varchar) as airport_ident,
        ancillary.currency,
        ancillary.purchase_date_utc as detected_at,
        ancillary.amount as financial_value_at_risk_amount,
        'Ancillary marked not_fulfilled on a ticket whose segments all flew' as rule_description
    from {{ ref('int_fulfilled_ancillary_services') }} as ancillary
    inner join {{ ref('int_ticket_revenue_recognition') }} as ticket_revenue
        on ancillary.ticket_id = ticket_revenue.ticket_id
    where
        not ancillary.fulfilment_indicator
        and ticket_revenue.is_recognition_eligible

),

ancillary_fulfilled_but_not_billed_exceptions as (

    -- A fulfilled ancillary (int_fulfilled_ancillary_services, M17, reused unchanged) with no
    -- matching invoice line -- reuses fct_invoice_lines directly.
    select
        'ancillary_fulfilled_but_not_billed' as exception_type,
        'ancillary_services' as source_system,
        ancillary.ancillary_service_id as source_record_id,
        ancillary.booking_id,
        ancillary.ticket_id,
        cast(null as varchar) as ticket_segment_id,
        cast(null as varchar) as flight_instance_id,
        cast(null as varchar) as invoice_id,
        cast(null as varchar) as payment_id,
        cast(null as varchar) as refund_id,
        cast(null as varchar) as adjustment_id,
        cast(null as varchar) as route_id,
        cast(null as varchar) as airport_ident,
        ancillary.currency,
        ancillary.purchase_date_utc as detected_at,
        ancillary.amount as financial_value_at_risk_amount,
        'Ancillary fulfilled but no matching ancillary invoice line exists' as rule_description
    from {{ ref('int_fulfilled_ancillary_services') }} as ancillary
    where
        ancillary.fulfilment_indicator
        and not exists (
            select 1
            from {{ ref('fct_invoice_lines') }} as invoice_lines
            where
                invoice_lines.ticket_id = ancillary.ticket_id
                and invoice_lines.line_type = 'ancillary'
                and invoice_lines.reference_code = ancillary.service_code
        )

),

missing_invoice_line_exceptions as (

    -- A tax charge int_invoice_charge_comparison (M14) expected but that has no matching invoice
    -- line at all (invoiced_amount is null, expected_amount is not) -- reused directly, never
    -- recalculated. Restricting to comparable_line_type = 'tax' precisely isolates a removed tax
    -- line from the base_fare-type signatures used for incorrect_fare and completed_segment_
    -- without_recognised_revenue above, which use the same underlying comparison model at a
    -- different comparable_line_type.
    select
        'missing_invoice_line' as exception_type,
        'invoices' as source_system,
        comparison.invoice_id || ':' || coalesce(comparison.ticket_id, '') as source_record_id,
        comparison.booking_id,
        comparison.ticket_id,
        cast(null as varchar) as ticket_segment_id,
        cast(null as varchar) as flight_instance_id,
        comparison.invoice_id,
        cast(null as varchar) as payment_id,
        cast(null as varchar) as refund_id,
        cast(null as varchar) as adjustment_id,
        cast(null as varchar) as route_id,
        cast(null as varchar) as airport_ident,
        comparison.currency,
        invoices.invoice_date_utc as detected_at,
        comparison.expected_amount as financial_value_at_risk_amount,
        'Invoice missing a tax line that Milestone 13 pricing expects' as rule_description
    from {{ ref('int_invoice_charge_comparison') }} as comparison
    left join {{ ref('fct_invoices') }} as invoices
        on comparison.invoice_id = invoices.invoice_id
    where
        comparison.comparable_line_type = 'tax'
        and comparison.expected_amount is not null
        and comparison.invoiced_amount is null

),

late_arriving_payment_exceptions as (

    -- A payment whose payment_delay_days (M15, payment_datetime_utc - invoice_date_utc) exceeds
    -- 30 days. No fixed "late" threshold exists in the Milestone 9 specification (the exception
    -- catalogue only states normal turnaround is hours); 30 days is a deliberately conservative,
    -- documented business rule -- well below the actual 75-day value the one deliberately injected
    -- late_arriving_payment exception produces, so this is a real threshold rule, not a disguised
    -- match to that specific record. financial_value_at_risk_amount is genuinely 0: the money did
    -- arrive: a timing anomaly, not an amount at risk.
    select
        'late_arriving_payment' as exception_type,
        'payments' as source_system,
        payment_id as source_record_id,
        booking_id,
        cast(null as varchar) as ticket_id,
        cast(null as varchar) as ticket_segment_id,
        cast(null as varchar) as flight_instance_id,
        invoice_id,
        payment_id,
        cast(null as varchar) as refund_id,
        cast(null as varchar) as adjustment_id,
        cast(null as varchar) as route_id,
        cast(null as varchar) as airport_ident,
        currency,
        payment_datetime_utc as detected_at,
        cast(0 as decimal(18, 2)) as financial_value_at_risk_amount,
        'Payment arrived more than 30 days after invoice date' as rule_description
    from {{ ref('fct_payments') }}
    where payment_delay_days > 30

),

unioned as (

    select * from duplicate_invoice_exceptions
    union all
    select * from failed_payment_after_ticket_issue_exceptions
    union all
    select * from unallocated_payment_exceptions
    union all
    select * from payment_without_invoice_exceptions
    union all
    select * from incorrect_fare_exceptions
    union all
    select * from currency_mismatch_exceptions
    union all
    select * from refund_greater_than_collected_amount_exceptions
    union all
    select * from invalid_adjustment_exceptions
    union all
    select * from cancelled_flight_without_refund_exceptions
    union all
    select * from completed_segment_without_recognised_revenue_exceptions
    union all
    select * from ancillary_sold_but_not_fulfilled_exceptions
    union all
    select * from ancillary_fulfilled_but_not_billed_exceptions
    union all
    select * from missing_invoice_line_exceptions
    union all
    select * from late_arriving_payment_exceptions

),

with_severity as (

    -- Severity is driven by exception_type (a documented tier reflecting the type's typical
    -- business/operational significance) escalated by one tier when financial_value_at_risk_amount
    -- meets or exceeds 1000 (in the record's own transaction currency) -- a fixed, documented
    -- materiality threshold, never randomness. See docs/data_models/airline_outstanding_balances_
    -- exceptions.md for the full tier rationale per exception_type.
    select
        unioned.*,
        case unioned.exception_type
            when 'duplicate_invoice' then 'critical'
            when 'refund_greater_than_collected_amount' then 'critical'
            when 'invalid_adjustment' then 'critical'
            when 'payment_without_invoice' then 'critical'
            when 'unallocated_payment' then 'high'
            when 'incorrect_fare' then 'high'
            when 'missing_invoice_line' then 'high'
            when 'cancelled_flight_without_refund' then 'high'
            when 'currency_mismatch' then 'medium'
            when 'completed_segment_without_recognised_revenue_precursor' then 'medium'
            when 'failed_payment_after_ticket_issue' then 'medium'
            when 'ancillary_sold_but_not_fulfilled' then 'low'
            when 'ancillary_fulfilled_but_not_billed' then 'low'
            when 'late_arriving_payment' then 'low'
        end as base_severity
    from unioned

),

final as (

    select
        exception_type,
        source_system,
        source_record_id,
        booking_id,
        ticket_id,
        ticket_segment_id,
        flight_instance_id,
        invoice_id,
        payment_id,
        refund_id,
        adjustment_id,
        route_id,
        airport_ident,
        currency,
        detected_at,
        cast(financial_value_at_risk_amount as decimal(18, 2)) as financial_value_at_risk_amount,
        rule_description,
        base_severity,
        case
            when financial_value_at_risk_amount >= 1000 and base_severity = 'low' then 'medium'
            when financial_value_at_risk_amount >= 1000 and base_severity = 'medium' then 'high'
            when financial_value_at_risk_amount >= 1000 and base_severity = 'high' then 'critical'
            else base_severity
        end as severity
    from with_severity

)

select
    exception_type,
    source_system,
    source_record_id,
    booking_id,
    ticket_id,
    ticket_segment_id,
    flight_instance_id,
    invoice_id,
    payment_id,
    refund_id,
    adjustment_id,
    route_id,
    airport_ident,
    currency,
    detected_at,
    financial_value_at_risk_amount,
    rule_description,
    severity
from final
