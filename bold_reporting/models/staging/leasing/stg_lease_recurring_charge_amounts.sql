select
    recurring_charge_id,
    amount,
    cast(frequency as text) as frequency,
    effective_date,
    deleted_at
from {{ source('app', 'lease_recurring_charge_amounts') }}

