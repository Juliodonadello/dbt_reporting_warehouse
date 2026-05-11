select
    p.property_id,
    p.prop_name,
    p.company_relation_id,
    pcc.item_id,
    case when pcc.base_rent then 1 else 0 end as base_rent_flag
from {{ ref('stg_properties') }} p
inner join {{ ref('stg_property_charge_controls') }} pcc
    on p.property_id = pcc.property_id
where p.deleted_at is null
  and pcc.deleted_at is null

