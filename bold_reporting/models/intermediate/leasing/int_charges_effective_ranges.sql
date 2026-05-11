with charges_base as (

    select
        lrc.recurring_charge_id,
        lrc.lease_id,
        lrc.unit_id,
        u.property_id,
        cc.prop_name,
        cc.company_relation_id,
        lrc.item_id,
        lrc.terminate_date,
        lrca.amount,
        lrca.frequency,
        lrca.effective_date,
        cc.base_rent_flag
    from {{ ref('stg_lease_recurring_charges') }} lrc
    inner join {{ ref('stg_lease_recurring_charge_amounts') }} lrca
        on lrc.recurring_charge_id = lrca.recurring_charge_id
    inner join {{ ref('stg_units') }} u
        on lrc.unit_id = u.unit_id
    inner join {{ ref('int_charge_control') }} cc
        on u.property_id = cc.property_id
       and lrc.item_id = cc.item_id
    where lrc.deleted_at is null
      and lrca.deleted_at is null
      and u.deleted_at is null
      and lrca.effective_date is not null

),

charges_with_ranges as (

    select
        recurring_charge_id,
        lease_id,
        unit_id,
        property_id,
        prop_name,
        company_relation_id,
        item_id,
        terminate_date,
        frequency,
        effective_date as charge_valid_from,
        coalesce(
            lead(effective_date) over (
                partition by recurring_charge_id
                order by effective_date
            ),
            date '9999-12-31'
        ) as charge_valid_to,
        case when base_rent_flag = 1 then amount else 0 end as rent_charge,
        case when base_rent_flag = 0 then amount else 0 end as other_charge
    from charges_base

)

select
    recurring_charge_id,
    lease_id,
    unit_id,
    property_id,
    prop_name,
    company_relation_id,
    item_id,
    terminate_date,
    frequency,
    charge_valid_from,
    charge_valid_to,
    case when frequency = 'One Time' then charge_valid_from + interval '31 day' else null end as one_time_window_end,
    rent_charge,
    other_charge
from charges_with_ranges

