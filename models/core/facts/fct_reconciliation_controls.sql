-- Grain is one row per reconciliation control per as-of period. Natural key is
-- (control_id, as_of_date); surrogate key is control_key. Reuses int_financial_control_summary
-- unchanged and adds only the surrogate key -- no new comparison or calculation.
--
-- Promoted to core because int_financial_control_summary is the stable "did source and warehouse
-- agree" contract for direct consumption. Billing-exception and month-end summaries remain
-- intermediate-only because they are report-shaped outputs, not stable facts other models are
-- expected to join against.
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
