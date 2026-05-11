with lease_units as (

    select
        dl.lease_id,
        dl.lease_name,
        dl.lease_status,
        dl.lease_start,
        dl.lease_end,
        dl.tenant,
        dl.lease_valid_from,
        dl.lease_valid_to,
        du.unit_id,
        du.unit_name,
        du.prop_name,
        du.company_relation_id,
        fus.unit_sq_ft,
        greatest(dl.lease_valid_from, fus.unit_sqft_valid_from) as report_valid_from,
        least(dl.lease_valid_to, fus.unit_sqft_valid_to) as report_valid_to
    from {{ ref('dim_lease') }} dl
    inner join {{ ref('dim_unit') }} du
        on dl.unit_id = du.unit_id
    inner join {{ ref('fct_unit_sqft') }} fus
        on dl.unit_id = fus.unit_id
       and dl.lease_valid_from < fus.unit_sqft_valid_to
       and dl.lease_valid_to > fus.unit_sqft_valid_from

)

select
    lease_id as "LEASE_ID",
    lease_name as "LEASE_NAME",
    lease_status as "LEASE_STATUS",
    lease_start as "lease_start",
    lease_end as "lease_end",
    unit_name as "UNIT_NAME",
    unit_sq_ft as "UNIT_SQ_FT",
    tenant as "TENANT_NAME",
    prop_name as "PROP_NAME",
    cast(company_relation_id as int) as "company_relation_id",
    report_valid_from as "report_valid_from",
    report_valid_to as "report_valid_to"
from lease_units
where report_valid_from < report_valid_to

