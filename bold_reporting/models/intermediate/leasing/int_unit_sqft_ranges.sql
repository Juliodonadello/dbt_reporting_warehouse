with units_base as (

    select
        u.unit_id,
        u.property_id,
        u.unit_name,
        u.floor_plan,
        coalesce(u.base_unit_sq_ft, 0) as default_unit_sq_ft
    from {{ ref('stg_units') }} u
    inner join {{ ref('stg_properties') }} p
        on u.property_id = p.property_id
    where u.deleted_at is null
      and p.deleted_at is null

),

sqft_events as (

    select
        usfi.unit_id,
        usfi.as_of_date as valid_from,
        lead(usfi.as_of_date) over (
            partition by usfi.unit_id
            order by usfi.as_of_date
        ) as next_valid_from,
        usfi.unit_sq_ft_value as unit_sq_ft
    from {{ ref('stg_unit_square_footage_items') }} usfi
    where usfi.deleted_at is null
      and usfi.square_footage_type = 'Total'
      and usfi.as_of_date is not null

),

first_sqft_event as (

    select
        unit_id,
        min(valid_from) as first_valid_from
    from sqft_events
    group by unit_id

),

default_ranges as (

    select
        ub.unit_id,
        ub.property_id,
        date '1900-01-01' as valid_from,
        coalesce(fse.first_valid_from, date '9999-12-31') as valid_to,
        ub.default_unit_sq_ft as unit_sq_ft
    from units_base ub
    left join first_sqft_event fse
        on ub.unit_id = fse.unit_id

),

historical_ranges as (

    select
        ub.unit_id,
        ub.property_id,
        se.valid_from,
        coalesce(se.next_valid_from, date '9999-12-31') as valid_to,
        se.unit_sq_ft
    from sqft_events se
    inner join units_base ub
        on se.unit_id = ub.unit_id

)

select *
from default_ranges
where valid_from < valid_to

union all

select *
from historical_ranges
where valid_from < valid_to

