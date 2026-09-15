with unit_base as not materialized (

    select
        du.property_id as prop_id,
        du.prop_name,
        du.company_relation_id,
        du.unit_id,
        du.unit_name,
        du.floor_plan,
        fus.unit_sqft_valid_from,
        fus.unit_sqft_valid_to,
        fus.unit_sq_ft,
        fps.property_sqft_valid_from,
        fps.property_sqft_valid_to,
        fps.property_total_sq_ft,
        greatest(fus.unit_sqft_valid_from, fps.property_sqft_valid_from) as base_valid_from,
        least(fus.unit_sqft_valid_to, fps.property_sqft_valid_to) as base_valid_to
    from {{ ref('dim_unit') }} du
    inner join {{ ref('fct_unit_sqft') }} fus
        on du.property_id = fus.property_id
       and du.company_relation_id = fus.company_relation_id
       and du.unit_id = fus.unit_id
    inner join {{ ref('fct_property_sqft') }} fps
        on du.property_id = fps.property_id
       and du.company_relation_id = fps.company_relation_id
       and fus.unit_sqft_valid_from < fps.property_sqft_valid_to
       and fus.unit_sqft_valid_to > fps.property_sqft_valid_from

),

unit_with_leases as not materialized (

    select
        ub.*,
        dl.lease_id,
        dl.lease_created_at,
        dl.lease_start,
        dl.unit_move_in,
        dl.lease_end,
        dl.lease_raw_status,
        dl.lease_status,
        dl.tenant,
        dl.deposit,
        dl.refundable,
        dl.month_to_month_label,
        dl.lease_termination,
        dl.lease_valid_from,
        dl.lease_valid_to,
        dl.lease_report_valid_to,
        greatest(ub.base_valid_from, coalesce(dl.lease_valid_from, date '1900-01-01')) as lease_stage_valid_from,
        least(ub.base_valid_to, coalesce(dl.lease_report_valid_to, date '9999-12-31')) as lease_stage_valid_to
    from unit_base ub
    left join {{ ref('dim_lease') }} dl
        on ub.prop_id = dl.property_id
       and ub.company_relation_id = dl.company_relation_id
       and ub.unit_id = dl.unit_id
       and ub.base_valid_from < dl.lease_report_valid_to
       and ub.base_valid_to > dl.lease_valid_from

),

detail_rows as not materialized (

    select
        uwl.prop_id,
        uwl.prop_name,
        uwl.company_relation_id,
        uwl.unit_id,
        uwl.unit_name,
        uwl.floor_plan,
        uwl.unit_sq_ft,
        uwl.property_total_sq_ft,
        uwl.lease_id,
        uwl.lease_created_at,
        uwl.lease_start,
        uwl.unit_move_in,
        uwl.lease_end,
        uwl.lease_raw_status,
        case when uwl.lease_id is not null then 'OCCUPIED' else 'VACANT' end as occupancy_status,
        uwl.lease_status,
        uwl.tenant,
        uwl.deposit,
        uwl.refundable,
        uwl.month_to_month_label,
        uwl.lease_termination,
        flc.recurring_charge_id,
        flc.frequency,
        flc.is_one_time_charge,
        flc.one_time_window_end,
        flc.terminate_date as charge_terminate_date,
        flc.rent_charge,
        flc.other_charge,
        flc.rent_amount,
        flc.other_amount,
        flc.annual_rent_amount,
        flc.annual_other_amount,
        greatest(uwl.lease_stage_valid_from, coalesce(flc.charge_valid_from, date '1900-01-01')) as report_valid_from,
        least(uwl.lease_stage_valid_to, coalesce(flc.charge_valid_to, date '9999-12-31')) as report_valid_to
    from unit_with_leases uwl
    left join {{ ref('fct_lease_charge') }} flc
        on uwl.prop_id = flc.property_id
       and uwl.company_relation_id = flc.company_relation_id
       and uwl.lease_id = flc.lease_id
       and uwl.unit_id = flc.unit_id
       and uwl.lease_stage_valid_from < flc.charge_valid_to
       and uwl.lease_stage_valid_to > flc.charge_valid_from

)

select
    df.prop_id,
    df.prop_name,
    df.company_relation_id,
    df.unit_id,
    df.unit_name,
    df.floor_plan,
    df.unit_sq_ft,
    df.property_total_sq_ft,
    df.lease_id,
    df.lease_created_at,
    df.lease_start,
    df.unit_move_in,
    df.lease_end,
    df.lease_raw_status,
    df.occupancy_status,
    df.lease_status,
    df.tenant,
    df.deposit,
    df.refundable,
    df.month_to_month_label,
    df.lease_termination,
    df.recurring_charge_id,
    df.frequency,
    df.is_one_time_charge,
    df.one_time_window_end,
    df.charge_terminate_date,
    df.rent_charge,
    df.other_charge,
    df.rent_amount,
    df.other_amount,
    df.annual_rent_amount,
    df.annual_other_amount,
    df.report_valid_from,
    df.report_valid_to
from detail_rows df
where df.report_valid_from < df.report_valid_to
