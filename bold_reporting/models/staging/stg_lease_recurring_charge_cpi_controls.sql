select
    lease_recurring_charge_id,
    next_adjustment_date,
    index_1,
    area_1,
    floor_percent,
    deleted_at
from {{ source('app', 'lease_recurring_charge_cpi_controls') }}
where deleted_at is null
