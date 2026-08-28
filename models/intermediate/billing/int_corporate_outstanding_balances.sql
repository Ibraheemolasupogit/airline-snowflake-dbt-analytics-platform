-- Grain is one row per corporate account per currency -- not strictly "one row per corporate
-- account" when a single account's invoices span more than one currency (point-of-sale country
-- can vary per booking even for the same corporate account). Summing amounts across different
-- currencies into one number would silently fabricate a meaningless total; no currency conversion
-- is invented here to force a single row (per this milestone's currency scope: "do not
-- automatically convert or correct mismatches"), so this model stays currency-safe by grouping on
-- (corporate_account_id, currency) instead. In the current dataset most corporate accounts likely
-- resolve to a single currency row in practice, but the model does not assume it.
--
-- Current-state aggregate only, not a commercial customer mart (no trend/marts logic here). Only
-- implemented because the source linkage is reliable and direct: verified against
-- scripts/airline_synth/build_billing.py, an invoice's bill_to_id is set to the booking's own
-- corporate_account_id whenever bill_to_type = 'corporate' -- the same identifier
-- stg_airline__corporate_accounts.corporate_account_id uses -- so no inferred or fuzzy join is
-- required. Reuses int_outstanding_balance and fct_invoices; does not recompute anything.
with invoices as (

    select
        invoice_id,
        bill_to_type,
        bill_to_id
    from {{ ref('fct_invoices') }}
    where bill_to_type = 'corporate'

),

outstanding_balance as (

    select
        invoice_id,
        currency,
        source_invoice_total,
        outstanding_balance
    from {{ ref('int_outstanding_balance') }}

),

corporate_accounts as (

    select
        corporate_account_id,
        company_name,
        default_currency
    from {{ ref('stg_airline__corporate_accounts') }}

),

joined as (

    select
        invoices.bill_to_id as corporate_account_id,
        outstanding_balance.currency,
        outstanding_balance.source_invoice_total,
        outstanding_balance.outstanding_balance
    from invoices
    left join outstanding_balance
        on invoices.invoice_id = outstanding_balance.invoice_id

),

aggregated as (

    select
        corporate_account_id,
        currency,
        count(*) as invoice_count,
        sum(source_invoice_total) as total_invoiced,
        sum(outstanding_balance) as total_outstanding_balance
    from joined
    group by corporate_account_id, currency

),

final as (

    select
        corporate_accounts.corporate_account_id,
        corporate_accounts.company_name,
        coalesce(aggregated.currency, corporate_accounts.default_currency) as currency,
        coalesce(aggregated.invoice_count, 0) as invoice_count,
        coalesce(aggregated.total_invoiced, 0) as total_invoiced,
        coalesce(aggregated.total_outstanding_balance, 0) as total_outstanding_balance
    from corporate_accounts
    left join aggregated
        on corporate_accounts.corporate_account_id = aggregated.corporate_account_id

)

select
    corporate_account_id,
    company_name,
    currency,
    invoice_count,
    cast(total_invoiced as decimal(18, 2)) as total_invoiced,
    cast(total_outstanding_balance as decimal(18, 2)) as total_outstanding_balance
from final
