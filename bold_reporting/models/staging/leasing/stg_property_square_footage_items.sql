select
    property_id,
    square_footage_type,
    value as property_sq_ft_value,
    as_of_date,
    deleted_at
from {{ source('app', 'property_square_footage_items') }}
where deleted_at is null
