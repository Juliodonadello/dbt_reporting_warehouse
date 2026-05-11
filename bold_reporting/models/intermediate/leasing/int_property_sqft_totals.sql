with boundaries as (

    select distinct
        property_id,
        valid_from as boundary_date
    from {{ ref('int_unit_sqft_ranges') }}

    union

    select distinct
        property_id,
        valid_to as boundary_date
    from {{ ref('int_unit_sqft_ranges') }}

),

ordered_boundaries as (

    select
        property_id,
        boundary_date as valid_from,
        lead(boundary_date) over (
            partition by property_id
            order by boundary_date
        ) as valid_to
    from boundaries

),

property_ranges as (

    select
        property_id,
        valid_from,
        valid_to
    from ordered_boundaries
    where valid_to is not null
      and valid_from < valid_to

)

select
    pr.property_id,
    pr.valid_from,
    pr.valid_to,
    sum(usr.unit_sq_ft) as property_total_sq_ft
from property_ranges pr
inner join {{ ref('int_unit_sqft_ranges') }} usr
    on pr.property_id = usr.property_id
   and pr.valid_from >= usr.valid_from
   and pr.valid_from < usr.valid_to
group by
    pr.property_id,
    pr.valid_from,
    pr.valid_to

