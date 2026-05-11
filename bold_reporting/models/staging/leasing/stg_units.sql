select
    id as unit_id,
    property_id,
    name as unit_name,
    coalesce(floorplan, ' ') as floor_plan,
    total_square_footage as base_unit_sq_ft,
    status as unit_status_raw,
    deleted_at
from {{ source('app', 'units') }}

