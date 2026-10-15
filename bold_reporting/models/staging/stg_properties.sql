select
    id as property_id,
    name as prop_name,
    entity_id,
    cast(company_relation_id as integer) as company_relation_id,
    property_location_id as location_id,
    department as department_id,
    class_id,
    status as property_status,
    property_type,
    deleted_at
from {{ source('app', 'properties') }}
where deleted_at is null
