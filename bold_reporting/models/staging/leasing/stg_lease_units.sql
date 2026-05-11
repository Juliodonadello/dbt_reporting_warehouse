select
    lease_id,
    unit_id,
    move_in,
    deleted_at
from {{ source('app', 'lease_units') }}

