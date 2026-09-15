select
    lease_options.lease_category,
    lease_options.notification_date,
    lease_options.expiration_date,
    lease_options.property_manager_email,
    lease_options.description,
    lease_options."leaseId" as "D_lease_id",
    lease_options.property_id,
    units.name as unit_name,
    lease_options.note,
    properties.name as prop_name,
    properties.company_relation_id,
    coalesce(lease_options.deleted_at, date '9999-12-31') as lease_option_valid_to
from {{ source('app', 'lease_options') }} as lease_options
inner join {{ source('app', 'units') }} as units
    on lease_options.unit_id = units.id
inner join {{ source('app', 'properties') }} as properties
    on properties.id = units.property_id
