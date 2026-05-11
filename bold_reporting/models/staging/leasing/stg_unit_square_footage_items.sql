select
    unit_id,
    square_footage_type,
    value as unit_sq_ft_value,
    as_of_date,
    deleted_at
from {{ source('app', 'unit_square_footage_items') }}

