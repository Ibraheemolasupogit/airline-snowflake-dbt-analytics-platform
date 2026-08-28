with invoices as (

    select
        status,
        currency,
        source_invoice_total
    from {{ ref('fct_invoices') }}

),

aggregated as (

    select
        status,
        currency,
        count(*) as invoice_count,
        sum(source_invoice_total) as invoice_total_value
    from invoices
    group by status, currency

)

select
    status,
    currency,
    invoice_count,
    cast(invoice_total_value as decimal(18, 2)) as invoice_total_value
from aggregated
