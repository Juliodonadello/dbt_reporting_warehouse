select
    id as unit_id,
    property_id,
    unit_location_id,
    name as unit_name,
    city,
    coalesce(floorplan, ' ') as floor_plan,
    unit_class,
    total_square_footage as base_unit_sq_ft,
    status as unit_status_raw,
    available,
    actual_move_in_date,
    deleted_at
from {{ source('app', 'units') }}
where deleted_at is null
