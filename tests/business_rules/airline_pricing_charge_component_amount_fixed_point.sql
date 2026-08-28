-- Fails if any priced charge-component amount carries more than 2 decimal places of precision,
-- which would indicate floating-point drift from an unrounded currency conversion rather than the
-- fixed-point decimal(18, 2) arithmetic this milestone requires throughout.
select
    component_key_natural,
    amount
from {{ ref('int_booking_charge_components') }}
where
    amount is not null
    and abs(amount - round(amount, 2)) > 0.0000001
