select
    cer.recurring_charge_id,
    cer.lease_id,
    cer.unit_id,
    cer.property_id,
    cer.prop_name,
    cer.company_relation_id,
    cer.item_id,
    cer.terminate_date,
    cer.frequency,
    cer.charge_valid_from,
    cer.charge_valid_to,
    cer.one_time_window_end,
    case when cer.frequency = 'One Time' then true else false end as is_one_time_charge,
    cer.rent_charge,
    cer.other_charge,
    coalesce(cer.rent_charge, 0) * coalesce(df.monthly_factor, 0) as rent_amount,
    coalesce(cer.other_charge, 0) * coalesce(df.monthly_factor, 0) as other_amount,
    coalesce(cer.rent_charge, 0) * coalesce(df.annual_factor, 0) as annual_rent_amount,
    coalesce(cer.other_charge, 0) * coalesce(df.annual_factor, 0) as annual_other_amount
from {{ ref('int_charges_effective_ranges') }} cer
left join {{ ref('dim_frequency') }} df
    on cer.frequency = df.frequency

