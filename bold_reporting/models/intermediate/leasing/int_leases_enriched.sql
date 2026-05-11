with leases_base as (

    select
        l.lease_id,
        l.lease_name,
        l.property_id,
        lu.unit_id,
        l.lease_created_at,
        l.lease_start,
        coalesce(lu.move_in, l.lease_start) as unit_move_in,
        l.lease_end,
        l.lease_raw_status,
        l.month_to_month_flag,
        l.lease_termination,
        t.tenant_name,
        case when l.lease_raw_status = 'current' then 'OCCUPIED' else 'VACANT' end as lease_status,
        case
            when l.month_to_month_flag = true then coalesce(l.lease_termination, date '9999-12-31')
            else coalesce(l.lease_end, date '9999-12-31')
        end as lease_valid_to
    from {{ ref('stg_leases') }} l
    inner join {{ ref('stg_lease_units') }} lu
        on l.lease_id = lu.lease_id
    left join {{ ref('stg_tenants') }} t
        on l.primary_tenant_id = t.tenant_id
       and t.deleted_at is null
    where l.deleted_at is null
      and lu.deleted_at is null

),

deposits_agg as (

    select
        lease_id,
        case when max(case when lease_deposit_id is not null then 1 else 0 end) = 1 then 'YES' else 'NO' end as deposit,
        case
            when count(distinct refundable) > 1 then 'MANY'
            when max(case when refundable = true or cast(refundable as text) = 'true' then 1 else 0 end) = 1 then 'YES'
            else 'NO'
        end as refundable
    from {{ ref('stg_lease_deposits') }}
    where deleted_at is null
    group by lease_id

)

select
    lb.lease_id,
    lb.lease_name,
    lb.property_id,
    lb.unit_id,
    lb.lease_created_at,
    lb.lease_start,
    lb.unit_move_in,
    lb.lease_end,
    lb.lease_raw_status,
    lb.lease_status,
    case when lb.month_to_month_flag = true then 'True' else 'False' end as month_to_month_label,
    lb.month_to_month_flag,
    lb.lease_termination,
    coalesce(lb.unit_move_in, date '1900-01-01') as lease_valid_from,
    lb.lease_valid_to,
    coalesce(da.deposit, 'NO') as deposit,
    coalesce(da.refundable, 'NO') as refundable,
    lb.tenant_name as tenant
from leases_base lb
left join deposits_agg da
    on lb.lease_id = da.lease_id
