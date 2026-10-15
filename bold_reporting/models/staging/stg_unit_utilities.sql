select
    unit_id,
    name as utility_name,
    description as utility_description,
    deleted_at
from {{ source('app', 'unit_utilities') }}
where deleted_at is null
