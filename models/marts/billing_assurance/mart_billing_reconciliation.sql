-- Grain is one row per reconciliation control per as-of period, identical to
-- fct_reconciliation_controls' own grain. A thin consumption-ready re-selection of that fact --
-- no reconciliation arithmetic is re-run or duplicated here.
select
    control_id,
    control_domain,
    control_name,
    source_measure,
    warehouse_measure,
    variance_amount,
    variance_count,
    control_status,
    as_of_date
from {{ ref('fct_reconciliation_controls') }}
