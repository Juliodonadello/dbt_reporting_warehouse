select
    u.unit_id,
    u.property_id,
    p.prop_name,
    p.company_relation_id,
    u.unit_name,
    u.floor_plan,
    u.unit_status_raw
from {{ ref('stg_units') }} u
inner join {{ ref('dim_property') }} p
    on u.property_id = p.property_id
where u.deleted_at is null

