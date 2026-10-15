select
    recurring_charge_id,
    created_at as cpi_history_created_at,
    charges_detail,
    calculation_details,
    deleted_at
from {{ source('app', 'cpi_history') }}
where deleted_at is null
