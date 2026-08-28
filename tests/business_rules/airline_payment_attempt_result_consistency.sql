-- Fails if any payment (stg_airline__payments) whose payment_attempt_id resolves to a real
-- payment_attempts row is linked to an attempt whose result was not 'success' -- a successful
-- payment transaction should only ever originate from a successful attempt. The deliberately
-- injected payment_without_invoice controlled exception has a null payment_attempt_id (staged as
-- an empty string, normalised to null) and is therefore correctly excluded from this check, not
-- accidentally passed by coincidence.
select
    payments.payment_id,
    payments.payment_attempt_id,
    attempts.result
from {{ ref('stg_airline__payments') }} as payments
inner join {{ ref('stg_airline__payment_attempts') }} as attempts
    on payments.payment_attempt_id = attempts.payment_attempt_id
where attempts.result != 'success'
