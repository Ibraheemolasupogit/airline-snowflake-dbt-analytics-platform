-- Verifies exact pass/fail semantics hold as an invariant, not just per-row by construction:
-- for every control with a numeric variance (count or amount), control_status must be 'pass' when
-- the variance is within materiality_threshold and 'fail' otherwise. Excludes 'warning' and
-- 'not_applicable' rows, which are deliberately not exact-match controls (see
-- docs/data_models/airline_reconciliation_controls.md).
select
    control_id,
    control_status,
    variance_amount,
    variance_count,
    materiality_threshold
from {{ ref('fct_reconciliation_controls') }}
where
    control_status in ('pass', 'fail')
    and (
        (variance_count is not null and (
            (abs(variance_count) <= materiality_threshold) != (control_status = 'pass')
        ))
        or (variance_amount is not null and (
            (abs(variance_amount) <= materiality_threshold) != (control_status = 'pass')
        ))
    )
