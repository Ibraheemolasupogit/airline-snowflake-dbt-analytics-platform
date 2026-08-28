-- Operationalises this milestone's central distinction: an anomalous business record can
-- reconcile PERFECTLY from source to warehouse while still being a genuine billing exception.
-- Fails if EITHER half of that statement stops holding: the refund.refund_total_value control
-- must show control_status = 'pass' (source refund_amount = warehouse refund_amount, uncapped,
-- including the refund_greater_than_collected_amount exception's full inflated value) AND
-- fct_billing_exceptions must still contain at least one refund_greater_than_collected_amount row
-- (Milestone 18's separate, correct classification of that same anomaly). Losing either signal
-- would mean this milestone's reconciliation model accidentally "fixed" the anomaly (by capping
-- it) or Milestone 18's detection silently stopped firing -- both are failures this test guards
-- against directly, not by matching a specific record ID.
with refund_control as (

    select control_status
    from {{ ref('fct_reconciliation_controls') }}
    where control_id = 'refund.refund_total_value'

),

exception_present as (

    select count(*) as occurrences
    from {{ ref('fct_billing_exceptions') }}
    where exception_type = 'refund_greater_than_collected_amount'

)

select
    refund_control.control_status,
    exception_present.occurrences
from refund_control
cross join exception_present
where
    refund_control.control_status != 'pass'
    or exception_present.occurrences = 0
