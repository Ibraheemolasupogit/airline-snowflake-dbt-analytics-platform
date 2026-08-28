-- Fails if any of the twelve direct source-to-warehouse controls (booking/ticket/flight-operations/
-- invoice/payment/refund counts and monetary totals) does not show control_status = 'pass'. This
-- is the core assurance check this milestone exists to provide: invoice counts reconcile, payment
-- counts reconcile, and refund counts reconcile, all in one assertion. It deliberately excludes
-- invoice_line_arithmetic_consistency (informational, 'warning' expected) and
-- failed_attempt_count (supplementary, 'not_applicable' expected).
select
    control_id,
    control_status,
    source_measure,
    warehouse_measure,
    variance_amount,
    variance_count
from {{ ref('fct_reconciliation_controls') }}
where control_id in (
    'booking.booking_count',
    'booking.booking_confirmed_count',
    'booking.booking_cancelled_count',
    'ticket.ticket_count',
    'flight_operations.flight_instance_count',
    'flight_operations.flight_instance_completed_count',
    'flight_operations.flight_instance_cancelled_count',
    'flight_operations.flight_instance_scheduled_count',
    'invoice.invoice_count',
    'invoice.invoice_total_value',
    'payment.successful_payment_count',
    'payment.successful_payment_total_value',
    'refund.refund_count',
    'refund.refund_total_value'
)
and control_status != 'pass'
