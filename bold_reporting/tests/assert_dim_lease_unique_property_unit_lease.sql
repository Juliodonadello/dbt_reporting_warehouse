select
    property_id,
    unit_id,
    lease_id,
    count(*) as duplicate_count
from {{ ref('dim_lease') }}
group by property_id, unit_id, lease_id
having count(*) > 1
