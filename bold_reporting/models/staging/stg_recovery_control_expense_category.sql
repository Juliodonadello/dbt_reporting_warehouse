select
    lease_recovery_control_id,
    manual_percent,
    deleted_at
from {{ source('app', 'recovery_control_expense_category') }}
where deleted_at is null
