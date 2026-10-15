select
    id as lease_option_id,
    lease_category,
    notification_date,
    expiration_date,
    property_manager_email,
    description,
    "leaseId" as lease_id,
    property_id,
    unit_id,
    note,
    sent,
    created_at,
    deleted_at
from {{ source('app', 'lease_options') }}
where deleted_at is null
