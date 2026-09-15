select
    property_id,
    prop_name,
    entity_id,
    company_relation_id
from {{ ref('stg_properties') }}
where deleted_at is null
