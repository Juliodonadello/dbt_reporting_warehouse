with unit_base as (

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
        on du.unit_id = fus.unit_id
    inner join {{ ref('fct_property_sqft') }} fps
        on du.property_id = fps.property_id
       and fus.unit_sqft_valid_from < fps.property_sqft_valid_to
       and fus.unit_sqft_valid_to > fps.property_sqft_valid_from

),

unit_with_leases as (

    select
        ub.*,
        dl.lease_id,
        dl.lease_created_at,
        dl.lease_start,
        dl.unit_move_in,
        dl.lease_end,
        dl.lease_status,
        dl.tenant,
        dl.deposit,
        dl.refundable,
        dl.month_to_month_label,
        dl.lease_termination,
        dl.lease_valid_from,
        dl.lease_valid_to,
        greatest(ub.base_valid_from, coalesce(dl.lease_valid_from, date '1900-01-01')) as lease_stage_valid_from,
        least(ub.base_valid_to, coalesce(dl.lease_valid_to, date '9999-12-31')) as lease_stage_valid_to
    from unit_base ub
    left join {{ ref('dim_lease') }} dl
        on ub.unit_id = dl.unit_id
       and ub.base_valid_from < dl.lease_valid_to
       and ub.base_valid_to > dl.lease_valid_from

),

detail_rows as (

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
        case when uwl.lease_created_at is not null then 'OCCUPIED' else 'VACANT' end as occupancy_status,
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
        greatest(
            uwl.lease_stage_valid_from,
            coalesce(flc.charge_valid_from, date '1900-01-01')
        ) as report_valid_from,
        least(
            uwl.lease_stage_valid_to,
            coalesce(flc.charge_valid_to, date '9999-12-31')
        ) as report_valid_to
    from unit_with_leases uwl
    left join {{ ref('fct_lease_charge') }} flc
        on uwl.lease_id = flc.lease_id
       and uwl.unit_id = flc.unit_id
       and uwl.lease_stage_valid_from < flc.charge_valid_to
       and uwl.lease_stage_valid_to > flc.charge_valid_from

),

detail_filtered as (

    select *
    from detail_rows
    where report_valid_from < report_valid_to

),

leases_per_unit_range as (

    select
        unit_id,
        report_valid_from,
        report_valid_to,
        count(distinct lease_id) filter (where lease_id is not null) as leases_count
    from detail_filtered
    group by
        unit_id,
        report_valid_from,
        report_valid_to

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
    lpur.leases_count,
    case
        when coalesce(lpur.leases_count, 0) = 0 then df.unit_sq_ft
        else df.unit_sq_ft / lpur.leases_count
    end as unit_sq_ft_fix,
    case
        when coalesce(df.property_total_sq_ft, 0) = 0 then 0
        else df.unit_sq_ft / df.property_total_sq_ft * 100
    end as pct_of_property,
    case
        when coalesce(df.property_total_sq_ft, 0) = 0 then 0
        when coalesce(lpur.leases_count, 0) = 0 then df.unit_sq_ft / df.property_total_sq_ft * 100
        else (df.unit_sq_ft / lpur.leases_count) / df.property_total_sq_ft * 100
    end as pct_of_property_fix,
    case
        when coalesce(df.unit_sq_ft, 0) = 0 then 0
        else coalesce(df.annual_rent_amount, 0) / df.unit_sq_ft
    end as annual_rent_per_sq_ft,
    case
        when coalesce(df.unit_sq_ft, 0) = 0 then 0
        else coalesce(df.annual_other_amount, 0) / df.unit_sq_ft
    end as annual_other_per_sq_ft,
    df.report_valid_from,
    df.report_valid_to
from detail_filtered df
left join leases_per_unit_range lpur
    on df.unit_id = lpur.unit_id
   and df.report_valid_from = lpur.report_valid_from
   and df.report_valid_to = lpur.report_valid_to

