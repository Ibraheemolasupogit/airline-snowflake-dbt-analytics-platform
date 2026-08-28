-- Current-state invoice status model. Grain is one row per invoice (invoice_id). The Milestone 9
-- source captures only each invoice's current status (stg_airline__invoices.status), not a
-- status-change history table, so -- matching int_booking_current_state's precedent -- no
-- historical status events are fabricated here.
--
-- status is preserved verbatim from source (issued | paid | refunded | cancelled). Note that
-- 'paid'/'refunded' already reflect downstream payment/refund outcomes baked into the Milestone 9
-- generator at data-generation time (scripts/airline_synth/build_billing.py sets invoice status
-- from the simulated payment/refund outcome); this milestone does not derive, infer, or recompute
-- any payment-based status itself -- it only surfaces what is already staged, per the "payment-
-- derived status must not be added yet" scope boundary.
with invoices as (

    select
        invoice_id,
        status
    from {{ ref('stg_airline__invoices') }}

),

final as (

    select
        invoice_id,
        status,
        status = 'cancelled' as is_cancelled
    from invoices

)

select
    invoice_id,
    status,
    is_cancelled
from final
