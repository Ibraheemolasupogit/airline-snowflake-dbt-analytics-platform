{% snapshot snap_airport_fees %}

{{
    config(
        target_schema='snapshots',
        unique_key='airport_fee_id',
        strategy='check',
        check_cols=[
            'airport_ident',
            'fee_code',
            'fee_name',
            'currency_code',
            'amount'
        ],
        invalidate_hard_deletes=True
    )
}}

select
    airport_fee_id,
    airport_ident,
    fee_code,
    fee_name,
    currency_code,
    amount
from {{ ref('stg_airline__airport_fees') }}

{% endsnapshot %}
