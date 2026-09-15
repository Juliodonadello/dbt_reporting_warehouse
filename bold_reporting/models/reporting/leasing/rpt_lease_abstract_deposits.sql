with deposits as (

    select
        lease_deposits."type" as "D_type",
        case when lease_deposits.refundable is true then 'YES' else 'NO' end as "D_refundable",
        lease_deposits.invoice_number as "D_invoice_number",
        units.name as "D_unit_name",
        lease_deposits.lease_id as "D_lease_id",
        lease_deposits.id as deposit_id,
        properties.name as prop_name,
        properties.company_relation_id
    from {{ source('app', 'lease_deposits') }} as lease_deposits
    inner join {{ source('app', 'units') }} as units
        on lease_deposits.unit_id = units.id
    inner join {{ source('app', 'properties') }} as properties
        on properties.id = units.property_id
    where lease_deposits.deleted_at is null

),

deposit_refunds as (

    select
        lease_deposit_refunds.lease_deposit_id,
        sum(lease_deposit_refunds.amount) as "REFUNDED_AMOUNT"
    from {{ source('app', 'lease_deposit_refunds') }} as lease_deposit_refunds
    inner join deposits
        on lease_deposit_refunds.lease_deposit_id = deposits.deposit_id
    where lease_deposit_refunds.deleted_at is null
    group by lease_deposit_refunds.lease_deposit_id

)

select
    deposits."D_type",
    deposits."D_refundable",
    deposits."D_invoice_number",
    deposits."D_unit_name",
    deposits."D_lease_id",
    deposits.deposit_id,
    deposit_refunds."REFUNDED_AMOUNT",
    deposits.prop_name,
    deposits.company_relation_id
from deposits
left join deposit_refunds
    on deposit_refunds.lease_deposit_id = deposits.deposit_id
