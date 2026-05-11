select
    property_id,
    valid_from as property_sqft_valid_from,
    valid_to as property_sqft_valid_to,
    property_total_sq_ft
from {{ ref('int_property_sqft_totals') }}

