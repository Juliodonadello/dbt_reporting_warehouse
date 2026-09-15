with late_charges as (

    select
        lease_late_charges.id,
        lease_late_charges.description,
        lease_late_charges.minimum_lease_balance,
        lease_late_charges.suppress_charge_under,
        lease_late_charges.lease_id,
        cast(lease_late_charges.process_by as text) as process_by,
        lease_late_charges.deleted_at as late_charge_deleted_at,
        properties.name as prop_name,
        properties.company_relation_id
    from {{ source('app', 'lease_late_charges') }} as lease_late_charges
    inner join {{ source('app', 'leases') }} as leases
        on lease_late_charges.lease_id = leases.id
    inner join {{ source('app', 'properties') }} as properties
        on properties.id = leases.property_id

),

late_charge_steps as (

    select
        lease_late_charge_steps.id as lease_late_charge_steps_id,
        lease_late_charge_steps.late_charge_type,
        lease_late_charge_steps.grace_days,
        cast(lease_late_charge_steps.frequency as text)
            || ': '
            || cast(lease_late_charge_steps.repeat_factor as text) as "Frecuency",
        lease_late_charge_steps.calculation_type,
        coalesce(
            lease_late_charge_steps.flat_amount,
            lease_late_charge_steps.percentage
        ) as "Amount",
        lease_late_charge_steps.lease_late_charge_id,
        lease_late_charge_steps.deleted_at as late_charge_step_deleted_at
    from {{ source('app', 'lease_late_charge_steps') }} as lease_late_charge_steps

)

select
    late_charges.id,
    late_charges.description,
    late_charges.minimum_lease_balance,
    late_charges.suppress_charge_under,
    late_charges.lease_id,
    late_charges.process_by,
    late_charge_steps.lease_late_charge_steps_id as steps_id,
    late_charge_steps.late_charge_type,
    late_charge_steps.grace_days,
    late_charge_steps."Frecuency",
    late_charge_steps.calculation_type,
    late_charge_steps."Amount",
    late_charges.prop_name,
    late_charges.company_relation_id,
    coalesce(late_charges.late_charge_deleted_at, date '9999-12-31') as late_charge_valid_to,
    coalesce(late_charge_steps.late_charge_step_deleted_at, date '9999-12-31') as late_charge_step_valid_to
from late_charges
left join late_charge_steps
    on late_charges.id = late_charge_steps.lease_late_charge_id
