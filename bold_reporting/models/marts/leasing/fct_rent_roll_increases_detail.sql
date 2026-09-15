with rent_roll_detail as (

    select *
    from {{ ref('fct_summarized_rent_roll_detail') }}

),

lease_detail as (

    select
        lease_id,
        property_id,
        unit_id,
        lease_name,
        month_to_month_flag
    from {{ ref('dim_lease') }}

),

charge_detail as (

    select
        recurring_charge_id,
        lease_id,
        property_id,
        unit_id,
        charge_valid_from,
        charge_valid_to,
        rent_charge as rent_charge_raw,
        other_charge as other_charge_raw
    from {{ ref('fct_lease_charge') }}

)

select
    rrd.prop_id,
    rrd.prop_name,
    rrd.company_relation_id,
    rrd.unit_id,
    rrd.unit_name,
    du.floor_plan,
    du.unit_status_raw,
    rrd.unit_sq_ft,
    rrd.property_total_sq_ft,
    rrd.lease_id,
    ld.lease_name,
    rrd.lease_created_at,
    rrd.lease_start,
    rrd.unit_move_in,
    rrd.lease_end,
    rrd.occupancy_status,
    rrd.lease_status,
    rrd.tenant,
    rrd.deposit,
    rrd.refundable,
    rrd.month_to_month_label,
    ld.month_to_month_flag,
    rrd.lease_termination,
    rrd.recurring_charge_id,
    rrd.frequency,
    rrd.is_one_time_charge,
    rrd.one_time_window_end,
    rrd.charge_terminate_date,
    cd.charge_valid_from,
    cd.charge_valid_to,
    cd.rent_charge_raw,
    cd.other_charge_raw,
    rrd.rent_charge,
    rrd.other_charge,
    rrd.rent_amount,
    rrd.other_amount,
    rrd.annual_rent_amount,
    rrd.annual_other_amount,
    rrd.report_valid_from,
    rrd.report_valid_to
from rent_roll_detail rrd
left join {{ ref('dim_unit') }} du
    on rrd.prop_id = du.property_id
   and rrd.unit_id = du.unit_id
left join lease_detail ld
    on rrd.prop_id = ld.property_id
   and rrd.lease_id = ld.lease_id
   and rrd.unit_id = ld.unit_id
left join charge_detail cd
    on rrd.prop_id = cd.property_id
   and rrd.recurring_charge_id = cd.recurring_charge_id
   and rrd.lease_id = cd.lease_id
   and rrd.unit_id = cd.unit_id
   and rrd.report_valid_from < cd.charge_valid_to
   and rrd.report_valid_to > cd.charge_valid_from
