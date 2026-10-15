select
    lease_id,
    overage_start_date,
    overage_end_date,
    months_frequency,
    item_id,
    sale_type,
    deleted_at
from {{ source('app', 'rent_percentages') }}
where deleted_at is null
