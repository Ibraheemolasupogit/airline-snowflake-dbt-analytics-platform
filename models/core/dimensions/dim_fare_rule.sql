-- Grain is one row per fare-class rule set (fare_rule_id); fare_class_code is unique per source
-- (one rule set per fare class). Rule attributes (refundable, change_fee_usd,
-- advance_purchase_days, min_stay_nights) are reference/eligibility data only -- none is applied
-- as a priced charge component in this milestone: change_fee_usd would require an actual ticket
-- change event, and no such transaction exists anywhere in the Milestone 9 specification, so
-- charging it here would be invented. fare_class_key joins to the existing dim_fare_class
-- (Milestone 12) for convenience; this dimension does not duplicate dim_fare_class's own columns.
with fare_rules as (

    select
        fare_rule_id,
        fare_class_code,
        refundable,
        change_fee_usd,
        advance_purchase_days,
        min_stay_nights
    from {{ ref('stg_airline__fare_rules') }}

),

fare_classes as (

    select
        fare_class_key,
        fare_class_code
    from {{ ref('dim_fare_class') }}

),

joined as (

    select
        fare_rules.fare_rule_id,
        fare_classes.fare_class_key,
        fare_rules.fare_class_code,
        fare_rules.refundable,
        fare_rules.change_fee_usd,
        fare_rules.advance_purchase_days,
        fare_rules.min_stay_nights
    from fare_rules
    left join fare_classes
        on fare_rules.fare_class_code = fare_classes.fare_class_code

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['fare_rule_id']) }} as fare_rule_key,
        fare_rule_id,
        fare_class_key,
        fare_class_code,
        refundable,
        change_fee_usd,
        advance_purchase_days,
        min_stay_nights
    from joined

)

select
    fare_rule_key,
    fare_rule_id,
    fare_class_key,
    fare_class_code,
    refundable,
    change_fee_usd,
    advance_purchase_days,
    min_stay_nights
from final
