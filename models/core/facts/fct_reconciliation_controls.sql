-- Grain is one row per reconciliation control per as-of period. Natural key is
-- (control_id, as_of_date); surrogate key is control_key. Reuses int_financial_control_summary
-- unchanged and adds only the surrogate key -- no new comparison or calculation.
--
-- Promoted to core (unlike int_billing_exception_control_summary and int_month_end_financial_
-- assurance, kept intermediate-only): int_financial_control_summary is this milestone's final,
-- portfolio-facing "did source and warehouse agree" contract -- a stable, documented, tested grain
-- meant for direct consumption, matching development_standards.md's own layer distinction
-- ("core: governed facts and dimensions with stable contracts" vs. "intermediate: reusable
-- transformations that should not be exposed directly to reporting users") and every other
-- milestone's precedent of promoting its own final governed output to a core fact (fct_pricing_
-- events, fct_billing_exceptions, and so on). The billing-exception and month-end summaries remain
-- intermediate-only because they are consumed directly as reporting/evidence exports (see
-- outputs/, reports/), not as a stable fact other models are expected to join against.
with control_summary as (

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
    from {{ ref('int_financial_control_summary') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['control_id', 'as_of_date']) }} as control_key,
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
    from control_summary

)

select
    control_key,
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
from final
