-- Grain is one row per reconciliation control. Primary key is control_id. A UNION ALL of every
-- domain reconciliation model -- the single clean analytical contract this milestone's control
-- layer produces. No new comparison or calculation is introduced here; this model only combines
-- what int_booking_reconciliation / int_invoice_reconciliation / int_payment_reconciliation /
-- int_refund_reconciliation / int_revenue_reconciliation already computed.
with unioned as (

    select * from {{ ref('int_booking_reconciliation') }}
    union all
    select * from {{ ref('int_invoice_reconciliation') }}
    union all
    select * from {{ ref('int_payment_reconciliation') }}
    union all
    select * from {{ ref('int_refund_reconciliation') }}
    union all
    select * from {{ ref('int_revenue_reconciliation') }}

)

select
    control_id,
    control_domain,
    control_name,
    source_measure,
    warehouse_measure,
    variance_amount,
    variance_count,
    control_status,
    materiality_threshold,
    as_of_date,
    notes
from unioned
