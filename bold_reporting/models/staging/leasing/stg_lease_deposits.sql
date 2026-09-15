select
    id as lease_deposit_id,
    lease_id,
    unit_id,
    "type" as deposit_type,
    refundable,
    invoice_number,
    deleted_at
from {{ source('app', 'lease_deposits') }}
where deleted_at is null
