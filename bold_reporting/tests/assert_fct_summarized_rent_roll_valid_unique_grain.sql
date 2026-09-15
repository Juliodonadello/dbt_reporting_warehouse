select
    prop_id,
    unit_id,
    lease_id,
    recurring_charge_id,
    report_valid_from,
    report_valid_to,
    count(*) as duplicate_count
from {{ ref('fct_summarized_rent_roll_detail') }}
where report_valid_from is null
   or report_valid_to is null
   or report_valid_from >= report_valid_to
group by
    prop_id,
    unit_id,
    lease_id,
    recurring_charge_id,
    report_valid_from,
    report_valid_to
having count(*) > 0

union all

select
    prop_id,
    unit_id,
    lease_id,
    recurring_charge_id,
    report_valid_from,
    report_valid_to,
    count(*) as duplicate_count
from {{ ref('fct_summarized_rent_roll_detail') }}
group by
    prop_id,
    unit_id,
    lease_id,
    recurring_charge_id,
    report_valid_from,
    report_valid_to
having count(*) > 1
