select
    id as lease_deposit_refund_id,
    lease_deposit_id,
    amount,
    deleted_at
from {{ source('app', 'lease_deposit_refunds') }}
where deleted_at is null
