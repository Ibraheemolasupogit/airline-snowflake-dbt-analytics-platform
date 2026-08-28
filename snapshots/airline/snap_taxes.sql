{% snapshot snap_taxes %}

{{
    config(
        target_schema='snapshots',
        unique_key='tax_id',
        strategy='check',
        check_cols=[
            'country_code',
            'tax_code',
            'tax_name',
            'percentage_rate',
            'currency_code'
        ],
        invalidate_hard_deletes=True
    )
}}

select
    tax_id,
    country_code,
    tax_code,
    tax_name,
    percentage_rate,
    currency_code
from {{ ref('stg_airline__taxes') }}

{% endsnapshot %}
