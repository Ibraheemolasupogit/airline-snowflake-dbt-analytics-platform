{% snapshot snap_corporate_accounts %}

{{
    config(
        target_schema='snapshots',
        unique_key='corporate_account_id',
        strategy='check',
        check_cols=[
            'company_name',
            'country',
            'negotiated_discount_pct',
            'default_currency'
        ],
        invalidate_hard_deletes=True
    )
}}

select
    corporate_account_id,
    company_name,
    country,
    negotiated_discount_pct,
    default_currency
from {{ ref('stg_airline__corporate_accounts') }}

{% endsnapshot %}
