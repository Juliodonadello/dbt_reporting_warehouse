with unit_sqft as (

    select
        du.property_id as prop_id,
        du.prop_name,
        du.company_relation_id,
        du.unit_id,
        du.unit_name,
        du.floor_plan,
        du.unit_class,
        du.unit_status_raw,
        'Total' as sq_ft_type,
        fus.unit_sq_ft,
        fus.unit_sqft_valid_from,
        fus.unit_sqft_valid_to
    from {{ ref('dim_unit') }} du
    inner join {{ ref('fct_unit_sqft') }} fus
        on du.unit_id = fus.unit_id
       and du.property_id = fus.property_id

),

property_boundaries as (

    select
        prop_id,
        unit_sqft_valid_from as boundary_date
    from unit_sqft

    union

    select
        prop_id,
        unit_sqft_valid_to as boundary_date
    from unit_sqft

),

property_periods as (

    select
        prop_id,
        boundary_date as unit_valid_from,
        lead(boundary_date) over (
            partition by prop_id
            order by boundary_date
        ) as unit_valid_to
    from property_boundaries

),

property_sqft_by_period as (

    select
        pp.prop_id,
        pp.unit_valid_from,
        pp.unit_valid_to,
        sum(us.unit_sq_ft) as property_total_sq_ft
    from property_periods pp
    inner join unit_sqft us
        on pp.prop_id = us.prop_id
       and pp.unit_valid_from < us.unit_sqft_valid_to
       and pp.unit_valid_to > us.unit_sqft_valid_from
    where pp.unit_valid_to is not null
      and pp.unit_valid_from < pp.unit_valid_to
    group by
        pp.prop_id,
        pp.unit_valid_from,
        pp.unit_valid_to

),

unit_periods as (

    select
        us.prop_id,
        us.prop_name,
        us.company_relation_id,
        us.unit_id,
        us.unit_name,
        us.floor_plan,
        us.unit_class,
        us.unit_status_raw,
        us.sq_ft_type,
        us.unit_sq_ft,
        ps.property_total_sq_ft,
        ps.unit_valid_from,
        ps.unit_valid_to
    from unit_sqft us
    inner join property_sqft_by_period ps
        on us.prop_id = ps.prop_id
       and ps.unit_valid_from < us.unit_sqft_valid_to
       and ps.unit_valid_to > us.unit_sqft_valid_from

),

lease_base as (

    select
        lease_id,
        lease_name,
        property_id,
        unit_id,
        lease_created_at,
        lease_start,
        unit_move_in,
        lease_end,
        lease_raw_status,
        lease_status,
        month_to_month_label,
        month_to_month_flag,
        lease_termination,
        lease_valid_from,
        lease_valid_to,
        deposit,
        refundable,
        tenant
    from {{ ref('dim_lease') }}
    where lease_raw_status = 'current'

),

unit_leases as (

    select
        up.*,
        lb.lease_id,
        lb.lease_name,
        lb.lease_created_at,
        lb.lease_start,
        lb.unit_move_in,
        lb.lease_end,
        lb.lease_raw_status,
        lb.lease_status,
        lb.month_to_month_label,
        lb.month_to_month_flag,
        lb.lease_termination,
        lb.lease_valid_from,
        lb.lease_valid_to,
        lb.deposit,
        lb.refundable,
        lb.tenant
    from unit_periods up
    left join lease_base lb
        on up.unit_id = lb.unit_id
       and up.prop_id = lb.property_id
       and up.unit_valid_from < lb.lease_valid_to
       and up.unit_valid_to > lb.lease_valid_from

)

select
    ul.prop_id,
    ul.prop_name,
    ul.company_relation_id,
    ul.unit_id,
    ul.unit_name,
    ul.floor_plan,
    ul.unit_class,
    ul.unit_status_raw,
    ul.sq_ft_type,
    ul.unit_sq_ft,
    ul.property_total_sq_ft,
    ul.unit_valid_from,
    ul.unit_valid_to,
    ul.lease_id,
    ul.lease_name,
    ul.lease_created_at,
    ul.lease_start,
    ul.unit_move_in,
    ul.lease_end,
    ul.lease_raw_status,
    ul.lease_status,
    ul.month_to_month_label,
    ul.month_to_month_flag,
    ul.lease_termination,
    ul.lease_valid_from,
    ul.lease_valid_to,
    ul.deposit,
    ul.refundable,
    ul.tenant,
    fc.recurring_charge_id,
    fc.frequency,
    fc.is_one_time_charge,
    fc.terminate_date as charge_terminate_date,
    fc.charge_valid_from,
    fc.charge_valid_to,
    fc.one_time_window_end,
    fc.rent_charge,
    fc.other_charge,
    fc.rent_amount,
    fc.other_amount,
    fc.annual_rent_amount,
    fc.annual_other_amount
from unit_leases ul
left join {{ ref('fct_lease_charge') }} fc
    on ul.lease_id = fc.lease_id
   and ul.unit_id = fc.unit_id
