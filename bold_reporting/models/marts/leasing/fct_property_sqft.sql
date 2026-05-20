select
    property_id,
    valid_from as property_sqft_valid_from,
    valid_to as property_sqft_valid_to,
    MAX(property_total_sq_ft) property_total_sq_ft
from {{ ref('int_property_sqft_totals') }}
group by property_id,
    valid_from,
    valid_to
