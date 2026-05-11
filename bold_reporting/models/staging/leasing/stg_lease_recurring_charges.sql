select
    id as recurring_charge_id,
    lease_id,
    unit_id,
    order_entry_item_id as item_id,
    terminate_date,
    deleted_at
from {{ source('app', 'lease_recurring_charges') }}

