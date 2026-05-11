select
    usr.unit_id,
    usr.property_id,
    usr.valid_from as unit_sqft_valid_from,
    usr.valid_to as unit_sqft_valid_to,
    usr.unit_sq_ft
from {{ ref('int_unit_sqft_ranges') }} usr

