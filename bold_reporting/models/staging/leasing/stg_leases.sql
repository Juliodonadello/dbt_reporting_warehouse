select
    id as lease_id,
    name as lease_name,
    property_id,
    "primaryTenantId" as primary_tenant_id,
    created_at as lease_created_at,
    start as lease_start,
    "end" as lease_end,
    status as lease_raw_status,
    month_to_month as month_to_month_flag,
    lease_termination,
    deleted_at
from {{ source('app', 'leases') }}
