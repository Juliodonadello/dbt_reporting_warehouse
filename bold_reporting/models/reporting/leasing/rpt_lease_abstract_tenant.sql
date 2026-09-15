select
    leases.id,
    leases.name,
    leases.status,
    leases.start,
    leases."end",
    leases.move_in,
    leases.intended_move_out,
    leases.actual_move_out,
    tenants.name as tenants_name,
    tenants.email,
    tenants.balance,
    properties.name as prop_name,
    properties.company_relation_id
from {{ source('app', 'leases') }} as leases
inner join {{ source('app', 'tenants') }} as tenants
    on leases."primaryTenantId" = tenants.id
inner join {{ source('app', 'properties') }} as properties
    on leases.property_id = properties.id
