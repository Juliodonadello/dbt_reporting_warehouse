select
    id as tenant_id,
    tenant_id as external_tenant_id,
    vendor_id,
    name as tenant_name,
    email,
    balance,
    deleted_at
from {{ source('app', 'tenants') }}
where deleted_at is null
