select
    property_id,
    unit_id,
    count(*) as duplicate_count
from {{ ref('dim_unit') }}
group by property_id, unit_id
having count(*) > 1
