select
    id as insurance_id,
    insurance_type,
    company,
    policy_number,
    email_to,
    effective_date,
    expiration_date,
    insurance_value,
    lease_id,
    property_id,
    notification_date,
    email_cc,
    deleted_at
from {{ source('app', 'insurances') }}
where deleted_at is null
