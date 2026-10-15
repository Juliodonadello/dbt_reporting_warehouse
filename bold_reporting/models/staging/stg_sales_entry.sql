select
    lease_id,
    transaction_date,
    sales_volume,
    deleted_at
from {{ source('app', 'sales_entry') }}
where deleted_at is null
