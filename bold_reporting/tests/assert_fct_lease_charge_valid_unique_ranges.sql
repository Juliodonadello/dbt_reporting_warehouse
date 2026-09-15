select
    property_id,
    unit_id,
    lease_id,
    recurring_charge_id,
    charge_valid_from,
    charge_valid_to,
    count(*) as duplicate_count
from {{ ref('fct_lease_charge') }}
where charge_valid_from is null
   or charge_valid_to is null
   or charge_valid_from >= charge_valid_to
group by
    property_id,
    unit_id,
    lease_id,
    recurring_charge_id,
    charge_valid_from,
    charge_valid_to
having count(*) > 0

union all

select
    property_id,
    unit_id,
    lease_id,
    recurring_charge_id,
    charge_valid_from,
    charge_valid_to,
    count(*) as duplicate_count
from {{ ref('fct_lease_charge') }}
group by
    property_id,
    unit_id,
    lease_id,
    recurring_charge_id,
    charge_valid_from,
    charge_valid_to
having count(*) > 1
