{% snapshot snap_fare_rules %}

{{
    config(
        target_schema='snapshots',
        unique_key='fare_rule_id',
        strategy='check',
        check_cols=[
            'fare_class_code',
            'refundable',
            'change_fee_usd',
            'advance_purchase_days',
            'min_stay_nights'
        ],
        invalidate_hard_deletes=True
    )
}}

select
    fare_rule_id,
    fare_class_code,
    refundable,
    change_fee_usd,
    advance_purchase_days,
    min_stay_nights
from {{ ref('stg_airline__fare_rules') }}

{% endsnapshot %}
