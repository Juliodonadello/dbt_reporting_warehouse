with properties_base as not materialized (

    select
        property_id,
        company_relation_id
    from {{ ref('stg_properties') }}
    where deleted_at is null

),

sqft_events as not materialized (

    select
        psfi.property_id,
        pb.company_relation_id,
        psfi.as_of_date as valid_from,
        lead(psfi.as_of_date) over (
            partition by pb.company_relation_id, psfi.property_id
            order by psfi.as_of_date
        ) as next_valid_from,
        psfi.property_sq_ft_value as property_total_sq_ft
    from {{ ref('stg_property_square_footage_items') }} psfi
    inner join properties_base pb
        on psfi.property_id = pb.property_id
    where psfi.deleted_at is null
      and psfi.square_footage_type = 'Total'
      and psfi.as_of_date is not null

),

first_sqft_event as not materialized (

    select
        property_id,
        company_relation_id,
        min(valid_from) as first_valid_from
    from sqft_events
    group by company_relation_id, property_id

),

default_ranges as not materialized (

    select
        pb.property_id,
        date '1900-01-01' as valid_from,
        coalesce(fse.first_valid_from, date '9999-12-31') as valid_to,
        cast(0 as numeric) as property_total_sq_ft,
        pb.company_relation_id
    from properties_base pb
    left join first_sqft_event fse
        on pb.property_id = fse.property_id
       and pb.company_relation_id = fse.company_relation_id

),

property_ranges as not materialized (

    select
        pb.property_id,
        se.valid_from,
        coalesce(se.next_valid_from, date '9999-12-31') as valid_to,
        se.property_total_sq_ft,
        pb.company_relation_id
    from sqft_events se
    inner join properties_base pb
        on se.property_id = pb.property_id
       and se.company_relation_id = pb.company_relation_id

)

select
    dr.property_id,
    dr.valid_from,
    dr.valid_to,
    dr.property_total_sq_ft,
    dr.company_relation_id
from default_ranges dr
where dr.valid_from < dr.valid_to

union all

select
    pr.property_id,
    pr.valid_from,
    pr.valid_to,
    pr.property_total_sq_ft,
    pr.company_relation_id
from property_ranges pr
where pr.valid_from < pr.valid_to
