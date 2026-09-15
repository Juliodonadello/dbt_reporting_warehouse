with charges_tot as (

    select
        units.property_id as prop_id,
        properties.name as prop_name,
        units.name as unit_name,
        units.total_square_footage as unit_sq_ft,
        lease_recurring_charges.unit_id,
        leases.id as lease_id,
        lease_recurring_charges.id as rcharge_id,
        lease_recurring_charges.order_entry_item_id as item_id,
        lease_recurring_charge_amounts.effective_date,
        lease_recurring_charges.terminate_date,
        lease_recurring_charge_amounts.amount,
        cast(lease_recurring_charge_amounts.frequency as text) as frequency,
        (
            lease_recurring_charge_amounts.amount
            * coalesce(dim_frequency.annual_factor, 1)
        ) / coalesce(nullif(cast(units.total_square_footage as int), 0), 1) as am_sqft,
        (
            lease_recurring_charge_amounts.amount
            * coalesce(dim_frequency.monthly_factor, 1)
        ) / coalesce(nullif(cast(units.total_square_footage as int), 0), 1) as mo_sqft,
        case
            when lower(cast(leases.month_to_month as text)) = 'false' then 'NO'
            when lower(cast(leases.month_to_month as text)) = 'true' then 'YES'
        end as m_t_m,
        case
            when leases.status = 'current' then 'Current'
            when leases.status = 'canceled' then 'Canceled'
            when leases.status = 'terminated' then 'Terminated'
            when leases.status = 'future' then 'Future'
            else 'null'
        end as lease_status,
        properties.company_relation_id,
        leases.name as lease_name
    from {{ source('app', 'leases') }} as leases
    inner join {{ source('app', 'lease_units') }} as lease_units
        on leases.id = lease_units.lease_id
    inner join {{ source('app', 'units') }} as units
        on units.id = lease_units.unit_id
    inner join {{ source('app', 'properties') }} as properties
        on properties.id = units.property_id
    left join {{ source('app', 'lease_recurring_charges') }} as lease_recurring_charges
        on leases.id = lease_recurring_charges.lease_id
       and lease_recurring_charges.unit_id = units.id
       and lease_recurring_charges.deleted_at is null
    left join {{ source('app', 'lease_recurring_charge_amounts') }} as lease_recurring_charge_amounts
        on lease_recurring_charges.id = lease_recurring_charge_amounts.recurring_charge_id
       and lease_recurring_charge_amounts.deleted_at is null
    left join {{ ref('dim_frequency') }} as dim_frequency
        on cast(lease_recurring_charge_amounts.frequency as text) = dim_frequency.frequency

),

distinct_effective_dates as (

    select distinct
        rcharge_id,
        effective_date
    from charges_tot
    where rcharge_id is not null
      and effective_date is not null

),

effective_ranges as (

    select
        rcharge_id,
        effective_date,
        lead(effective_date) over (
            partition by rcharge_id
            order by effective_date
        ) as next_effective_date
    from distinct_effective_dates

),

charges_with_ranges as (

    select
        charges_tot.*,
        effective_ranges.next_effective_date
    from charges_tot
    left join effective_ranges
        on charges_tot.rcharge_id = effective_ranges.rcharge_id
       and charges_tot.effective_date = effective_ranges.effective_date

),

status_rows as (

    select
        charges_with_ranges.*,
        'Current' as rcharge_status,
        effective_date as rcharge_status_valid_from,
        coalesce(next_effective_date, date '9999-12-31') as rcharge_status_valid_to
    from charges_with_ranges
    where effective_date is not null

    union all

    select
        charges_with_ranges.*,
        'Future' as rcharge_status,
        date '1900-01-01' as rcharge_status_valid_from,
        effective_date as rcharge_status_valid_to
    from charges_with_ranges
    where effective_date is not null

    union all

    select
        charges_with_ranges.*,
        'Historical' as rcharge_status,
        next_effective_date as rcharge_status_valid_from,
        date '9999-12-31' as rcharge_status_valid_to
    from charges_with_ranges
    where next_effective_date is not null

    union all

    select
        charges_with_ranges.*,
        cast(null as text) as rcharge_status,
        date '1900-01-01' as rcharge_status_valid_from,
        date '9999-12-31' as rcharge_status_valid_to
    from charges_with_ranges
    where effective_date is null

)

select
    prop_id as "PROP_ID",
    prop_name as "PROP_NAME",
    unit_name as "UNIT_NAME",
    unit_sq_ft as "UNIT_SQ_FT",
    unit_id as "UNIT_ID",
    lease_id as "LEASE_ID",
    rcharge_id as "RCHARGE_ID",
    item_id as "ITEM_ID",
    effective_date as "EFFECTIVE_DATE",
    terminate_date as "TERMINATE_DATE",
    amount as "AMOUNT",
    frequency as "FREQUENCY",
    am_sqft as "Am/SqFt",
    mo_sqft as "Mo/SqFt",
    m_t_m as "M_t_M",
    lease_status as "LEASE_STATUS",
    rcharge_status as "RCHARGE_STATUS",
    company_relation_id,
    lease_name,
    rcharge_status_valid_from,
    rcharge_status_valid_to
from status_rows
where rcharge_status_valid_from < rcharge_status_valid_to
