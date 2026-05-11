select
    id as tenant_id,
    name as tenant_name,
    deleted_at
from {{ source('app', 'tenants') }}

