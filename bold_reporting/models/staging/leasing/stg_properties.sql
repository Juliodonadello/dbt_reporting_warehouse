select
    id as property_id,
    name as prop_name,
    cast(company_relation_id as integer) as company_relation_id,
    deleted_at
from {{ source('app', 'properties') }}

