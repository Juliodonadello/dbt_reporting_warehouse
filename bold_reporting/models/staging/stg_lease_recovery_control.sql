select
    id as lease_recovery_control_id,
    name as recovery_control_name,
    calculation_control_base_amount,
    calculation_control_base_year,
    deleted_at
from {{ source('app', 'lease_recovery_control') }}
where deleted_at is null
