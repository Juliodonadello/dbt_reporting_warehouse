select
    property_id,
    prop_name,
    company_relation_id
from {{ ref('stg_properties') }}
where deleted_at is null

