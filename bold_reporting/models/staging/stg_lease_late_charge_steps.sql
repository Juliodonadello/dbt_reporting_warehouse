select
    id as lease_late_charge_step_id,
    late_charge_type,
    grace_days,
    frequency,
    repeat_factor,
    calculation_type,
    flat_amount,
    percentage,
    lease_late_charge_id,
    created_at,
    deleted_at
from {{ source('app', 'lease_late_charge_steps') }}
where deleted_at is null
