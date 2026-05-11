select
    id as lease_deposit_id,
    lease_id,
    refundable,
    deleted_at
from {{ source('app', 'lease_deposits') }}

