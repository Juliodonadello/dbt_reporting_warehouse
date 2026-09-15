{{ config(severity='warn') }}

select
    recurring_charge_id,
    effective_date,
    count(*) as duplicate_count
from {{ ref('stg_lease_recurring_charge_amounts') }}
group by recurring_charge_id, effective_date
having count(*) > 1
