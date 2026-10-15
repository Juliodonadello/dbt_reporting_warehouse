select
    id as lease_late_charge_id,
    description,
    minimum_lease_balance,
    suppress_charge_under,
    lease_id,
    process_by,
    created_at,
    deleted_at
from {{ source('app', 'lease_late_charges') }}
where deleted_at is null
