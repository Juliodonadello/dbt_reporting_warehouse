select
    property_id,
    item_id,
    base_rent,
    deleted_at
from {{ source('app', 'property_charge_controls') }}

